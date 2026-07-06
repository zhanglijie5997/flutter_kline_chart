// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'common/action.dart';
import 'common/bar_space.dart';
import 'common/coordinate.dart';
import 'common/crosshair.dart';
import 'common/data.dart';
import 'common/period.dart';
import 'common/styles.dart' as kstyles;
import 'common/symbol_info.dart';
import 'common/task_scheduler.dart';
import 'common/utils/format.dart';
import 'common/utils/number.dart';
import 'common/utils/type_checks.dart';
import 'common/visible_range.dart';
import 'component/indicator.dart';
import 'extension/indicator/index.dart';

/// Formatter callbacks bound to the store configuration.
class InnerFormatter {
  final String Function(int timestamp, String template, String type) formatDate;
  final String Function(Object value) formatBigNumber;
  final String Function(String type, KLineData data, int index)
      formatExtendText;
  const InnerFormatter({
    required this.formatDate,
    required this.formatBigNumber,
    required this.formatExtendText,
  });
}

class _Separator {
  String sign;
  _Separator(this.sign);
  String format(Object value) => formatThousands(value, sign);
}

class _DecimalFold {
  int threshold;
  _DecimalFold(this.threshold);
  String format(Object value) => formatFoldDecimal(value, threshold);
}

const double _barSpaceLimitMin = 1;
const double _barSpaceLimitMax = 50;
const double _defaultBarSpace = 10;
const double _defaultOffsetRightDistance = 80;
const double _barGapRatio = 0.2;
const double scaleMultiplier = 10;

/// Port of `Store.ts` — the chart's central state + coordinate engine.
///
/// The upstream `chart.layout()`/`updatePane()` calls are replaced with
/// [invalidate], which notifies listeners so the widget repaints.
class ChartStore extends ChangeNotifier {
  ChartStore({
    Map<String, dynamic>? styles,
    String? locale,
    String? timezone,
    Map<String, double>? zoomAnchor,
  }) {
    _styles = kstyles.getDefaultStyles();
    _calcOptimalBarSpace();
    _lastBarRightSideDiffBarCount = _offsetRightDistance / _barSpace;
    if (styles != null) {
      setStyles(styles);
    }
    if (locale != null) {
      _locale = locale;
    }
    setTimezone(timezone ?? '');
    _taskScheduler = TaskScheduler(() {
      invalidate();
    });
  }

  // ---- config ----------------------------------------------------------------

  late Map<String, dynamic> _styles;
  String _locale = 'en-US';
  final _Separator _thousandsSeparator = _Separator(',');
  final _DecimalFold _decimalFold = _DecimalFold(3);
  SymbolInfo? _symbol;
  Period? _period;
  DateTimeFormat _dateTimeFormat = const DateTimeFormat();

  String Function(int timestamp, String template, String type)? _customFormatDate;
  String Function(Object value)? _customFormatBigNumber;
  String Function(String type, KLineData data, int index)? _customFormatExtendText;

  // ---- data ------------------------------------------------------------------

  List<KLineData> _dataList = <KLineData>[];

  // ---- viewport --------------------------------------------------------------

  bool _zoomEnabled = true;
  final Map<String, String> _zoomAnchor = <String, String>{
    'main': 'cursor',
    'xAxis': 'cursor',
  };
  bool _scrollEnabled = true;
  double _totalBarSpace = 0;
  double _barSpace = _defaultBarSpace;
  double _gapBarSpace = 1;
  double _offsetRightDistance = _defaultOffsetRightDistance;
  double _lastBarRightSideDiffBarCount = 0;
  double _startLastBarRightSideDiffBarCount = 0;
  String _scrollLimitRole = 'bar_count';
  final Map<String, double> _minVisibleBarCount = <String, double>{
    'left': 2,
    'right': 2,
  };
  final Map<String, double> _maxOffsetDistance = <String, double>{
    'left': 50,
    'right': 50,
  };

  VisibleRange _visibleRange = getDefaultVisibleRange();
  List<VisibleRangeData> _visibleRangeDataList = <VisibleRangeData>[];
  List<Map<String, double>> _visibleRangeHighLowPrice = <Map<String, double>>[
    <String, double>{'x': 0, 'price': -9007199254740991.0},
    <String, double>{'x': 0, 'price': 9007199254740991.0},
  ];

  Crosshair _crosshair = Crosshair();

  final Map<String, Action> _actions = <String, Action>{};
  final Map<String, List<IndicatorImp>> _indicators =
      <String, List<IndicatorImp>>{};
  late final TaskScheduler _taskScheduler;

  /// Called to request a repaint (replaces upstream `chart.layout`).
  VoidCallback? onInvalidate;

  void invalidate() {
    onInvalidate?.call();
    notifyListeners();
  }

  // ---- styles / formatters ---------------------------------------------------

  void setStyles(dynamic value) {
    Map<String, dynamic>? styles;
    if (value is String) {
      styles = kstyles.getStyles(value);
    } else if (value is Map) {
      styles = value.cast<String, dynamic>();
    }
    if (styles != null) {
      merge(_styles, styles);
    }
    invalidate();
  }

  Map<String, dynamic> getStyles() => _styles;

  String getLocale() => _locale;
  void setLocale(String locale) {
    _locale = locale;
    invalidate();
  }

  void setTimezone(String timezone) {
    _dateTimeFormat = DateTimeFormat(timezone: timezone.isEmpty ? null : timezone);
  }

  String getTimezone() => _dateTimeFormat.timezone ?? '';
  DateTimeFormat getDateTimeFormat() => _dateTimeFormat;

  _Separator getThousandsSeparator() => _thousandsSeparator;
  void setThousandsSeparator(String sign) {
    _thousandsSeparator.sign = sign;
  }

  _DecimalFold getDecimalFold() => _decimalFold;
  void setDecimalFold(int threshold) {
    _decimalFold.threshold = threshold;
  }

  void setFormatter({
    String Function(int timestamp, String template, String type)? formatDate,
    String Function(Object value)? formatBigNumber,
    String Function(String type, KLineData data, int index)? formatExtendText,
  }) {
    if (formatDate != null) _customFormatDate = formatDate;
    if (formatBigNumber != null) _customFormatBigNumber = formatBigNumber;
    if (formatExtendText != null) _customFormatExtendText = formatExtendText;
  }

  InnerFormatter getInnerFormatter() => InnerFormatter(
        formatDate: (timestamp, template, type) {
          if (_customFormatDate != null) {
            return _customFormatDate!(timestamp, template, type);
          }
          return formatTimestampByTemplate(_dateTimeFormat, timestamp, template);
        },
        formatBigNumber: (value) =>
            (_customFormatBigNumber ?? formatBigNumber)(value),
        formatExtendText: (type, data, index) =>
            _customFormatExtendText?.call(type, data, index) ?? '',
      );

  // ---- symbol / period -------------------------------------------------------

  void setSymbol(SymbolInfo symbol) {
    symbol.pricePrecision ??= SymbolDefaultPrecisionConstants.price;
    symbol.volumePrecision ??= SymbolDefaultPrecisionConstants.volume;
    _symbol = symbol;
    _synchronizeIndicatorSeriesPrecision();
    invalidate();
  }

  SymbolInfo? getSymbol() => _symbol;

  void setPeriod(Period period) {
    _period = period;
    invalidate();
  }

  Period? getPeriod() => _period;

  // ---- data ------------------------------------------------------------------

  List<KLineData> getDataList() => _dataList;
  List<VisibleRangeData> getVisibleRangeDataList() => _visibleRangeDataList;
  List<Map<String, double>> getVisibleRangeHighLowPrice() =>
      _visibleRangeHighLowPrice;

  /// Apply the full data set (upstream `_addData` with type 'init').
  void applyNewData(List<KLineData> data, {bool more = false}) {
    _dataList = List<KLineData>.from(data);
    setOffsetRightDistance(_offsetRightDistance);
    _adjustVisibleRange();
    setCrosshair(_crosshair, notInvalidate: true);
    _calcAllIndicators();
    invalidate();
  }

  /// Append a single new bar or update the last bar (upstream 'update').
  void updateData(KLineData data) {
    final dataCount = _dataList.length;
    final lastTimestamp =
        dataCount > 0 ? _dataList[dataCount - 1].timestamp : 0;
    var adjustFlag = false;
    if (data.timestamp > lastTimestamp) {
      _dataList.add(data);
      var diff = getLastBarRightSideDiffBarCount();
      if (diff < 0) {
        setLastBarRightSideDiffBarCount(--diff);
      }
      adjustFlag = true;
    } else if (data.timestamp == lastTimestamp) {
      _dataList[dataCount - 1] = data;
      adjustFlag = true;
    }
    if (adjustFlag) {
      _adjustVisibleRange();
      setCrosshair(_crosshair, notInvalidate: true);
      _calcAllIndicators();
      invalidate();
    }
  }

  /// Prepend older data (upstream 'forward').
  void prependData(List<KLineData> data) {
    if (data.isEmpty) return;
    _dataList = <KLineData>[...data, ..._dataList];
    _adjustVisibleRange();
    _calcAllIndicators();
    invalidate();
  }

  // ---- bar space -------------------------------------------------------------

  void _calcOptimalBarSpace() {
    const specialBarSpace = 4.0;
    final ratio = 1 -
        _barGapRatio *
            math.atan(math.max(specialBarSpace, _barSpace) - specialBarSpace) /
            (math.pi * 0.5);
    var gapBarSpace =
        math.min((_barSpace * ratio).floor(), _barSpace.floor());
    if (gapBarSpace % 2 == 0 && gapBarSpace + 2 >= _barSpace) {
      --gapBarSpace;
    }
    _gapBarSpace = math.max(1, gapBarSpace).toDouble();
  }

  BarSpace getBarSpace() => BarSpace(
        bar: _barSpace,
        halfBar: _barSpace / 2,
        gapBar: _gapBarSpace,
        halfGapBar: (_gapBarSpace / 2).floorToDouble(),
      );

  void setBarSpace(double barSpace, [void Function()? adjustBeforeFunc]) {
    if (barSpace < _barSpaceLimitMin ||
        barSpace > _barSpaceLimitMax ||
        _barSpace == barSpace) {
      return;
    }
    _barSpace = barSpace;
    _calcOptimalBarSpace();
    adjustBeforeFunc?.call();
    _adjustVisibleRange();
    setCrosshair(_crosshair, notInvalidate: true);
    invalidate();
  }

  void setTotalBarSpace(double totalSpace) {
    if (_totalBarSpace != totalSpace) {
      _totalBarSpace = totalSpace;
      _adjustVisibleRange();
      setCrosshair(_crosshair, notInvalidate: true);
    }
  }

  double getTotalBarSpace() => _totalBarSpace;

  ChartStore setOffsetRightDistance(double distance, [bool isUpdate = false]) {
    _offsetRightDistance = _scrollLimitRole == 'distance'
        ? math.min(_maxOffsetDistance['right']!, distance)
        : distance;
    _lastBarRightSideDiffBarCount = _offsetRightDistance / _barSpace;
    if (isUpdate) {
      _adjustVisibleRange();
      setCrosshair(_crosshair, notInvalidate: true);
      invalidate();
    }
    return this;
  }

  double getInitialOffsetRightDistance() => _offsetRightDistance;
  double getOffsetRightDistance() =>
      math.max(0.0, _lastBarRightSideDiffBarCount * _barSpace);
  double getLastBarRightSideDiffBarCount() => _lastBarRightSideDiffBarCount;
  void setLastBarRightSideDiffBarCount(double barCount) {
    _lastBarRightSideDiffBarCount = barCount;
  }

  void setMaxOffsetLeftDistance(double distance) {
    _scrollLimitRole = 'distance';
    _maxOffsetDistance['left'] = distance;
  }

  void setMaxOffsetRightDistance(double distance) {
    _scrollLimitRole = 'distance';
    _maxOffsetDistance['right'] = distance;
  }

  void setLeftMinVisibleBarCount(double barCount) {
    _scrollLimitRole = 'bar_count';
    _minVisibleBarCount['left'] = barCount;
  }

  void setRightMinVisibleBarCount(double barCount) {
    _scrollLimitRole = 'bar_count';
    _minVisibleBarCount['right'] = barCount;
  }

  VisibleRange getVisibleRange() => _visibleRange;

  // ---- visible range ---------------------------------------------------------

  void _adjustVisibleRange() {
    final totalBarCount = _dataList.length;
    final visibleBarCount = _totalBarSpace / _barSpace;

    var leftMinVisibleBarCount = 0.0;
    var rightMinVisibleBarCount = 0.0;
    if (_scrollLimitRole == 'distance') {
      leftMinVisibleBarCount =
          (_totalBarSpace - _maxOffsetDistance['right']!) / _barSpace;
      rightMinVisibleBarCount =
          (_totalBarSpace - _maxOffsetDistance['left']!) / _barSpace;
    } else {
      leftMinVisibleBarCount = _minVisibleBarCount['left']!;
      rightMinVisibleBarCount = _minVisibleBarCount['right']!;
    }
    leftMinVisibleBarCount = math.max(0.0, leftMinVisibleBarCount);
    rightMinVisibleBarCount = math.max(0.0, rightMinVisibleBarCount);

    final maxRightOffsetBarCount = visibleBarCount -
        math.min(leftMinVisibleBarCount, totalBarCount.toDouble());
    if (_lastBarRightSideDiffBarCount > maxRightOffsetBarCount) {
      _lastBarRightSideDiffBarCount = maxRightOffsetBarCount;
    }
    final double minRightOffsetBarCount = -totalBarCount.toDouble() +
        math.min(rightMinVisibleBarCount, totalBarCount.toDouble());
    if (_lastBarRightSideDiffBarCount < minRightOffsetBarCount) {
      _lastBarRightSideDiffBarCount = minRightOffsetBarCount;
    }
    var to = (_lastBarRightSideDiffBarCount + totalBarCount + 0.5).round();
    final realTo = to;
    if (to > totalBarCount) {
      to = totalBarCount;
    }
    var from = (to - visibleBarCount).round() - 1;
    if (from < 0) {
      from = 0;
    }
    final realFrom = _lastBarRightSideDiffBarCount > 0
        ? (totalBarCount + _lastBarRightSideDiffBarCount - visibleBarCount)
                .round() -
            1
        : from;
    _visibleRange = VisibleRange(
      from: from,
      to: to,
      realFrom: realFrom,
      realTo: realTo,
    );
    executeAction(ActionTypes.onVisibleRangeChange, _visibleRange);
    _visibleRangeDataList = <VisibleRangeData>[];
    _visibleRangeHighLowPrice = <Map<String, double>>[
      <String, double>{'x': 0, 'price': -9007199254740991.0},
      <String, double>{'x': 0, 'price': 9007199254740991.0},
    ];
    for (var i = realFrom; i < realTo; i++) {
      final kLineData = i >= 0 && i < _dataList.length ? _dataList[i] : null;
      final x = dataIndexToCoordinate(i);
      _visibleRangeDataList.add(VisibleRangeData(
        dataIndex: i,
        x: x,
        data: NeighborData<KLineData?>(
          prev: (i - 1 >= 0 && i - 1 < _dataList.length)
              ? _dataList[i - 1]
              : kLineData,
          current: kLineData,
          next: (i + 1 >= 0 && i + 1 < _dataList.length)
              ? _dataList[i + 1]
              : kLineData,
        ),
      ));
      if (kLineData != null) {
        if (_visibleRangeHighLowPrice[0]['price']! < kLineData.high) {
          _visibleRangeHighLowPrice[0]['price'] = kLineData.high;
          _visibleRangeHighLowPrice[0]['x'] = x;
        }
        if (_visibleRangeHighLowPrice[1]['price']! > kLineData.low) {
          _visibleRangeHighLowPrice[1]['price'] = kLineData.low;
          _visibleRangeHighLowPrice[1]['x'] = x;
        }
      }
    }
  }

  // ---- scroll / zoom ---------------------------------------------------------

  void startScroll() {
    _startLastBarRightSideDiffBarCount = _lastBarRightSideDiffBarCount;
  }

  void scroll(double distance) {
    if (!_scrollEnabled) {
      return;
    }
    final distanceBarCount = distance / _barSpace;
    final prevLastBarRightSideDistance =
        _lastBarRightSideDiffBarCount * _barSpace;
    _lastBarRightSideDiffBarCount =
        _startLastBarRightSideDiffBarCount - distanceBarCount;
    _adjustVisibleRange();
    setCrosshair(_crosshair, notInvalidate: true);
    invalidate();
    final realDistance = (prevLastBarRightSideDistance -
            _lastBarRightSideDiffBarCount * _barSpace)
        .round();
    if (realDistance != 0) {
      executeAction(ActionTypes.onScroll, <String, int>{'distance': realDistance});
    }
  }

  KLineData? getDataByDataIndex(int dataIndex) =>
      (dataIndex >= 0 && dataIndex < _dataList.length)
          ? _dataList[dataIndex]
          : null;

  double coordinateToFloatIndex(double x) {
    final dataCount = _dataList.length;
    final deltaFromRight = (_totalBarSpace - x) / _barSpace;
    final index = dataCount + _lastBarRightSideDiffBarCount - deltaFromRight;
    return (index * 1000000).round() / 1000000;
  }

  int dataIndexToTimestampNullable(int dataIndex) =>
      dataIndexToTimestamp(dataIndex) ?? 0;

  int? dataIndexToTimestamp(int dataIndex) {
    final length = _dataList.length;
    if (length == 0) {
      return null;
    }
    final data = getDataByDataIndex(dataIndex);
    if (data != null) {
      return data.timestamp;
    }
    final period = _period;
    if (period != null) {
      final lastIndex = length - 1;
      int? referenceTimestamp;
      var diff = 0;
      if (dataIndex > lastIndex) {
        referenceTimestamp = _dataList[lastIndex].timestamp;
        diff = dataIndex - lastIndex;
      } else if (dataIndex < 0) {
        referenceTimestamp = _dataList[0].timestamp;
        diff = dataIndex;
      }
      if (referenceTimestamp != null) {
        final type = period.type;
        final span = period.span;
        switch (type) {
          case 'second':
            return referenceTimestamp + span * 1000 * diff;
          case 'minute':
            return referenceTimestamp + span * 60 * 1000 * diff;
          case 'hour':
            return referenceTimestamp + span * 60 * 60 * 1000 * diff;
          case 'day':
            return referenceTimestamp + span * 24 * 60 * 60 * 1000 * diff;
          case 'week':
            return referenceTimestamp + span * 7 * 24 * 60 * 60 * 1000 * diff;
          case 'month':
            final date = DateTime.fromMillisecondsSinceEpoch(referenceTimestamp);
            final referenceDay = date.day;
            final base = DateTime(date.year, date.month + span * diff, 1);
            final lastDay = DateTime(base.year, base.month + 1, 0).day;
            return DateTime(base.year, base.month,
                    math.min(referenceDay, lastDay))
                .millisecondsSinceEpoch;
          case 'year':
            final date = DateTime.fromMillisecondsSinceEpoch(referenceTimestamp);
            return DateTime(date.year + span * diff, date.month, date.day)
                .millisecondsSinceEpoch;
        }
      }
    }
    return null;
  }

  int timestampToDataIndex(int timestamp) {
    final length = _dataList.length;
    if (length == 0) {
      return 0;
    }
    final period = _period;
    if (period != null) {
      int? referenceTimestamp;
      var baseDataIndex = 0;
      final lastIndex = length - 1;
      final lastTimestamp = _dataList[lastIndex].timestamp;
      if (timestamp > lastTimestamp) {
        referenceTimestamp = lastTimestamp;
        baseDataIndex = lastIndex;
      }
      final firstTimestamp = _dataList[0].timestamp;
      if (timestamp < firstTimestamp) {
        referenceTimestamp = firstTimestamp;
        baseDataIndex = 0;
      }
      if (referenceTimestamp != null) {
        final type = period.type;
        final span = period.span;
        switch (type) {
          case 'second':
            return baseDataIndex +
                ((timestamp - referenceTimestamp) / (span * 1000)).floor();
          case 'minute':
            return baseDataIndex +
                ((timestamp - referenceTimestamp) / (span * 60 * 1000)).floor();
          case 'hour':
            return baseDataIndex +
                ((timestamp - referenceTimestamp) / (span * 60 * 60 * 1000))
                    .floor();
          case 'day':
            return baseDataIndex +
                ((timestamp - referenceTimestamp) / (span * 24 * 60 * 60 * 1000))
                    .floor();
          case 'week':
            return baseDataIndex +
                ((timestamp - referenceTimestamp) /
                        (span * 7 * 24 * 60 * 60 * 1000))
                    .floor();
          case 'month':
            final referenceDate =
                DateTime.fromMillisecondsSinceEpoch(referenceTimestamp);
            final currentDate =
                DateTime.fromMillisecondsSinceEpoch(timestamp);
            return baseDataIndex +
                (((currentDate.year - referenceDate.year) * 12 +
                            (currentDate.month - referenceDate.month)) /
                        span)
                    .floor();
          case 'year':
            final referenceYear =
                DateTime.fromMillisecondsSinceEpoch(referenceTimestamp).year;
            final currentYear =
                DateTime.fromMillisecondsSinceEpoch(timestamp).year;
            return baseDataIndex + ((currentYear - referenceYear) / span).floor();
        }
      }
    }
    return binarySearchNearest<KLineData>(
        _dataList, (d) => d.timestamp, timestamp);
  }

  double dataIndexToCoordinate(int dataIndex) {
    final dataCount = _dataList.length;
    final deltaFromRight =
        dataCount + _lastBarRightSideDiffBarCount - dataIndex;
    return (_totalBarSpace - (deltaFromRight - 0.5) * _barSpace + 0.5)
        .floorToDouble();
  }

  int coordinateToDataIndex(double x) => coordinateToFloatIndex(x).ceil() - 1;

  void zoom(double scale, Coordinate? coordinate, String position) {
    if (!_zoomEnabled) {
      return;
    }
    var zoomX = coordinate?.x ?? (_crosshair.x ?? _totalBarSpace / 2);
    if (position == 'xAxis') {
      if (_zoomAnchor['xAxis'] == 'last_bar') {
        zoomX = dataIndexToCoordinate(_dataList.length - 1);
      }
    } else {
      if (_zoomAnchor['main'] == 'last_bar') {
        zoomX = dataIndexToCoordinate(_dataList.length - 1);
      }
    }
    final floatIndex = coordinateToFloatIndex(zoomX);
    final prevBarSpace = _barSpace;
    final barSpace = _barSpace + scale * (_barSpace / scaleMultiplier);
    setBarSpace(barSpace, () {
      _lastBarRightSideDiffBarCount +=
          floatIndex - coordinateToFloatIndex(zoomX);
    });
    final realScale = _barSpace / prevBarSpace;
    if (realScale != 1) {
      executeAction(ActionTypes.onZoom, <String, double>{'scale': realScale});
    }
  }

  void setZoomEnabled(bool enabled) => _zoomEnabled = enabled;
  bool isZoomEnabled() => _zoomEnabled;
  void setScrollEnabled(bool enabled) => _scrollEnabled = enabled;
  bool isScrollEnabled() => _scrollEnabled;

  void setZoomAnchor(dynamic anchor) {
    if (anchor is String) {
      _zoomAnchor['main'] = anchor;
      _zoomAnchor['xAxis'] = anchor;
    } else if (anchor is Map) {
      if (anchor['main'] is String) _zoomAnchor['main'] = anchor['main'] as String;
      if (anchor['xAxis'] is String) {
        _zoomAnchor['xAxis'] = anchor['xAxis'] as String;
      }
    }
  }

  // ---- crosshair -------------------------------------------------------------

  void setCrosshair(Crosshair? crosshair,
      {bool notInvalidate = false,
      bool notExecuteAction = false,
      bool forceInvalidate = false}) {
    final cr = crosshair ?? Crosshair();
    var realDataIndex = 0;
    var dataIndex = 0;
    if (cr.x != null) {
      realDataIndex = coordinateToDataIndex(cr.x!);
      if (realDataIndex < 0) {
        dataIndex = 0;
      } else if (realDataIndex > _dataList.length - 1) {
        dataIndex = _dataList.length - 1;
      } else {
        dataIndex = realDataIndex;
      }
    } else {
      realDataIndex = _dataList.length - 1;
      dataIndex = realDataIndex;
    }
    final kLineData =
        (dataIndex >= 0 && dataIndex < _dataList.length) ? _dataList[dataIndex] : null;
    final realX = dataIndexToCoordinate(realDataIndex);
    final prevX = _crosshair.x;
    final prevY = _crosshair.y;
    final prevPaneId = _crosshair.paneId;
    _crosshair = Crosshair(
      x: cr.x,
      y: cr.y,
      paneId: cr.paneId,
      realX: realX,
      kLineData: kLineData,
      realDataIndex: realDataIndex,
      dataIndex: dataIndex,
      timestamp: dataIndexToTimestamp(realDataIndex),
    );
    if (prevX != cr.x || prevY != cr.y || prevPaneId != cr.paneId || forceInvalidate) {
      if (kLineData != null &&
          !notExecuteAction &&
          hasAction(ActionTypes.onCrosshairChange) &&
          cr.paneId != null) {
        executeAction(ActionTypes.onCrosshairChange, crosshair);
      }
      if (!notInvalidate) {
        invalidate();
      }
    }
  }

  Crosshair getCrosshair() => _crosshair;

  // ---- actions ---------------------------------------------------------------

  void executeAction(ActionType type, [Object? data]) {
    _actions[type]?.execute(data);
  }

  void subscribeAction(ActionType type, ActionCallback callback) {
    _actions.putIfAbsent(type, Action.new).subscribe(callback);
  }

  void unsubscribeAction(ActionType type, [ActionCallback? callback]) {
    final action = _actions[type];
    if (action != null) {
      action.unsubscribe(callback);
      if (action.isEmpty()) {
        _actions.remove(type);
      }
    }
  }

  bool hasAction(ActionType type) {
    final action = _actions[type];
    return action != null && !action.isEmpty();
  }

  // ---- indicators ------------------------------------------------------------

  void _sortIndicators([String? paneId]) {
    if (paneId != null) {
      _indicators[paneId]?.sort((a, b) => a.zLevel.compareTo(b.zLevel));
    } else {
      _indicators.forEach((_, list) {
        list.sort((a, b) => a.zLevel.compareTo(b.zLevel));
      });
    }
  }

  void _calcIndicator(List<IndicatorImp> indicators) {
    if (indicators.isNotEmpty) {
      final tasks = <String, Future<Object?>>{};
      for (final indicator in indicators) {
        tasks[indicator.id] = indicator.calcImp(_dataList);
      }
      _taskScheduler.add(tasks);
    }
  }

  void _calcAllIndicators() {
    final all = getIndicatorsByFilter(const IndicatorFilter());
    if (all.isNotEmpty) {
      _calcIndicator(all);
    }
  }

  bool addIndicator(IndicatorCreate create, bool isStack) {
    final name = create.name;
    final existing = getIndicatorsByFilter(
        IndicatorFilter(paneId: create.paneId, name: name, id: create.id));
    if (existing.isNotEmpty) {
      return false;
    }
    final paneId = create.paneId ?? '';
    var paneIndicators = getIndicatorsByPaneId(paneId);
    final ctor = getIndicatorClass(name);
    if (ctor == null) {
      return false;
    }
    final indicator = ctor();
    _synchronizeIndicatorSeriesPrecisionOne(indicator);
    create.paneId = paneId;
    indicator.override(create);
    if (!isStack) {
      removeIndicator(IndicatorFilter(paneId: paneId));
      paneIndicators = <IndicatorImp>[];
    }
    paneIndicators.add(indicator);
    _indicators[paneId] = paneIndicators;
    _sortIndicators(paneId);
    _calcIndicator(<IndicatorImp>[indicator]);
    return true;
  }

  List<IndicatorImp> getIndicatorsByPaneId(String paneId) =>
      _indicators[paneId] ?? <IndicatorImp>[];

  List<IndicatorImp> getIndicatorsByFilter(IndicatorFilter filter) {
    bool match(IndicatorImp indicator) {
      if (filter.id != null) {
        return indicator.id == filter.id;
      }
      return filter.name == null || indicator.name == filter.name;
    }

    final indicators = <IndicatorImp>[];
    if (filter.paneId != null) {
      indicators.addAll(getIndicatorsByPaneId(filter.paneId!).where(match));
    } else {
      _indicators.forEach((_, list) {
        indicators.addAll(list.where(match));
      });
    }
    return indicators;
  }

  bool removeIndicator(IndicatorFilter filter) {
    var removed = false;
    final filterIndicators = getIndicatorsByFilter(filter);
    for (final indicator in filterIndicators) {
      final paneIndicators = getIndicatorsByPaneId(indicator.paneId);
      final index = paneIndicators.indexWhere((ins) => ins.id == indicator.id);
      if (index > -1) {
        paneIndicators.removeAt(index);
        removed = true;
      }
      if (paneIndicators.isEmpty) {
        _indicators.remove(indicator.paneId);
      }
    }
    if (removed) invalidate();
    return removed;
  }

  bool hasIndicators(String paneId) => _indicators.containsKey(paneId);

  /// Pane ids that hold indicators (excluding the candle pane).
  List<String> getIndicatorPaneIds() =>
      _indicators.keys.where((id) => id != _candlePaneId).toList();

  String _candlePaneId = 'candle_pane';
  set candlePaneId(String id) => _candlePaneId = id;

  bool overrideIndicator(IndicatorCreate override) {
    var updateFlag = false;
    final filterIndicators = getIndicatorsByFilter(
        IndicatorFilter(id: override.id, paneId: override.paneId, name: override.name));
    for (final indicator in filterIndicators) {
      indicator.override(override);
      _calcIndicator(<IndicatorImp>[indicator]);
      updateFlag = true;
    }
    if (updateFlag) invalidate();
    return updateFlag;
  }

  void _synchronizeIndicatorSeriesPrecisionOne(IndicatorImp indicator) {
    final symbol = _symbol;
    if (symbol != null) {
      final pricePrecision =
          symbol.pricePrecision ?? SymbolDefaultPrecisionConstants.price;
      final volumePrecision =
          symbol.volumePrecision ?? SymbolDefaultPrecisionConstants.volume;
      switch (indicator.series) {
        case 'price':
          indicator.setSeriesPrecision(pricePrecision);
          break;
        case 'volume':
          indicator.setSeriesPrecision(volumePrecision);
          break;
      }
    }
  }

  void _synchronizeIndicatorSeriesPrecision() {
    _indicators.forEach((_, list) {
      for (final indicator in list) {
        _synchronizeIndicatorSeriesPrecisionOne(indicator);
      }
    });
  }
}
