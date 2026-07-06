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

import '../common/bounding.dart';
import '../common/period.dart';
import '../common/symbol_info.dart';
import '../common/utils/canvas.dart';
import '../common/utils/format.dart';
import '../common/utils/number.dart';
import '../common/utils/style.dart';
import '../store.dart';

/// Port of `component/Axis.ts`, `component/YAxis.ts`, `component/XAxis.ts`.
///
/// Adapted so each axis holds a reference to the [ChartStore] and a mutable
/// [bounding] that the owning pane updates during layout.

const int tickCount = 8;
const String defaultAxisId = 'default';

class AxisTick {
  final double coord;
  final Object value;
  final String text;
  const AxisTick({required this.coord, required this.value, required this.text});
}

class AxisRange {
  final double from;
  final double to;
  final double range;
  final double realFrom;
  final double realTo;
  final double realRange;
  final double displayFrom;
  final double displayTo;
  final double displayRange;
  const AxisRange({
    this.from = 0,
    this.to = 0,
    this.range = 0,
    this.realFrom = 0,
    this.realTo = 0,
    this.realRange = 0,
    this.displayFrom = 0,
    this.displayTo = 0,
    this.displayRange = 0,
  });
}

typedef AxisCreateTicksCallback = List<AxisTick> Function(
    AxisRange range, Bounding bounding, List<AxisTick> defaultTicks);

abstract class AxisImp {
  final ChartStore store;
  final String paneId;
  Bounding bounding = Bounding();
  String name = '';
  bool scrollZoomEnabled = true;
  AxisCreateTicksCallback? createTicks;

  AxisRange _range = const AxisRange();
  AxisRange _prevRange = const AxisRange();
  List<AxisTick> _ticks = <AxisTick>[];
  bool _autoCalcTickFlag = true;

  AxisImp(this.store, this.paneId);

  Bounding getBounding() => bounding;

  bool buildTicks(bool force) {
    if (_autoCalcTickFlag) {
      _range = createRangeImp();
    }
    if (_prevRange.from != _range.from || _prevRange.to != _range.to || force) {
      _prevRange = _range;
      _ticks = createTicksImp();
      return true;
    }
    return false;
  }

  List<AxisTick> getTicks() => _ticks;

  void setRange(AxisRange range) {
    _autoCalcTickFlag = false;
    _range = range;
  }

  AxisRange getRange() => _range;

  void setAutoCalcTickFlag(bool flag) => _autoCalcTickFlag = flag;
  bool getAutoCalcTickFlag() => _autoCalcTickFlag;

  AxisRange createRangeImp();
  List<AxisTick> createTicksImp();
  double getAutoSize();
  double convertToPixel(double value);
  double convertFromPixel(double px);
}

/// Y axis (value axis).
class YAxisImp extends AxisImp {
  String id = defaultAxisId;
  bool reverse = false;
  bool inside = false;
  String position = 'right';
  final Map<String, double> gap = <String, double>{'top': 0.2, 'bottom': 0.1};
  final bool isCandlePane;

  YAxisImp(super.store, super.paneId, {this.isCandlePane = false});

  bool isInCandle() => isCandlePane;

  bool isFromZero() {
    return (position == 'left' && inside) || (position == 'right' && !inside);
  }

  @override
  AxisRange createRangeImp() {
    final chartStore = store;
    var min = 9007199254740991.0;
    var max = -9007199254740991.0;
    var shouldOhlc = false;
    var specifyMin = 9007199254740991.0;
    var specifyMax = -9007199254740991.0;
    var indicatorPrecision = 9007199254740991.0;
    final indicators = chartStore
        .getIndicatorsByPaneId(paneId)
        .where((indicator) => indicator.yAxisId == id)
        .toList();
    for (final indicator in indicators) {
      shouldOhlc = shouldOhlc || indicator.shouldOhlc;
      indicatorPrecision =
          math.min(indicatorPrecision, indicator.precision.toDouble());
      if (indicator.minValue != null) {
        specifyMin = math.min(specifyMin, indicator.minValue!.toDouble());
      }
      if (indicator.maxValue != null) {
        specifyMax = math.max(specifyMax, indicator.maxValue!.toDouble());
      }
    }

    var precision = 4;
    final inCandle = isInCandle();
    final isDefaultYAxis = id == defaultAxisId;
    if (inCandle) {
      final pricePrecision = chartStore.getSymbol()?.pricePrecision ??
          SymbolDefaultPrecisionConstants.price;
      if (indicatorPrecision != 9007199254740991.0) {
        precision = math.min(indicatorPrecision, pricePrecision.toDouble()).toInt();
      } else {
        precision = pricePrecision;
      }
    } else {
      if (indicatorPrecision != 9007199254740991.0) {
        precision = indicatorPrecision.toInt();
      }
    }
    final visibleRangeDataList = chartStore.getVisibleRangeDataList();
    final candleStyles = asMap(chartStore.getStyles()['candle']);
    final isArea = candleStyles['type'] == 'area';
    final areaValueKey = asString(asMap(candleStyles['area'])['value'], 'close');
    final shouldCompareHighLow =
        (inCandle && isDefaultYAxis && !isArea) || (!inCandle && shouldOhlc);
    for (final visibleData in visibleRangeDataList) {
      final dataIndex = visibleData.dataIndex;
      final data = visibleData.data.current;
      if (data != null) {
        if (shouldCompareHighLow) {
          min = math.min(min, data.low);
          max = math.max(max, data.high);
        }
        if (inCandle && isDefaultYAxis && isArea) {
          final value = data[areaValueKey];
          if (value is num && value.isFinite) {
            min = math.min(min, value.toDouble());
            max = math.max(max, value.toDouble());
          }
        }
      }
      for (final indicator in indicators) {
        final r = dataIndex >= 0 && dataIndex < indicator.result.length
            ? indicator.result[dataIndex]
            : const <String, dynamic>{};
        for (final figure in indicator.figures) {
          final value = r[figure.key];
          if (value is num && value.isFinite) {
            min = math.min(min, value.toDouble());
            max = math.max(max, value.toDouble());
          }
        }
      }
    }

    if (min != 9007199254740991.0 && max != -9007199254740991.0) {
      min = math.min(specifyMin, min);
      max = math.max(specifyMax, max);
    } else {
      min = 0;
      max = 10;
    }
    final defaultDiff = max - min;
    var realFrom = min;
    var realTo = max;
    var realRange = defaultDiff;
    final minSpanValue = minSpan(precision);
    if (realFrom == realTo || realRange < minSpanValue) {
      final minCheck = specifyMin == realFrom;
      final maxCheck = specifyMax == realTo;
      const halfTickCount = tickCount / 2;
      realFrom = minCheck
          ? realFrom
          : (maxCheck
              ? realFrom - tickCount * minSpanValue
              : realFrom - halfTickCount * minSpanValue);
      realTo = maxCheck
          ? realTo
          : (minCheck
              ? realTo + tickCount * minSpanValue
              : realTo + halfTickCount * minSpanValue);
    }

    final height = getBounding().height;
    var topRate = gap['top']!;
    if (topRate >= 1) {
      topRate = topRate / height;
    }
    var bottomRate = gap['bottom']!;
    if (bottomRate >= 1) {
      bottomRate = bottomRate / height;
    }
    realRange = realTo - realFrom;
    realFrom = realFrom - realRange * bottomRate;
    realTo = realTo + realRange * topRate;

    final from = realFrom;
    final to = realTo;
    final displayFrom = realFrom;
    final displayTo = realTo;
    return AxisRange(
      from: from,
      to: to,
      range: to - from,
      realFrom: realFrom,
      realTo: realTo,
      realRange: realTo - realFrom,
      displayFrom: displayFrom,
      displayTo: displayTo,
      displayRange: displayTo - displayFrom,
    );
  }

  double minSpan(int precision) => index10(-precision.toDouble());

  @override
  List<AxisTick> createTicksImp() {
    final range = getRange();
    final displayFrom = range.displayFrom;
    final displayTo = range.displayTo;
    final displayRange = range.displayRange;
    final ticks = <AxisTick>[];

    if (displayRange >= 0) {
      final interval = nice(displayRange / tickCount);
      final precision = getPrecision(interval);
      final first = round((displayFrom / interval).ceil() * interval, precision);
      final last = round((displayTo / interval).floor() * interval, precision);
      var f = first;
      if (interval != 0) {
        var guard = 0;
        while (f <= last && guard < 1000) {
          final v = f.toStringAsFixed(precision);
          ticks.add(AxisTick(text: v, coord: 0, value: v));
          f += interval;
          guard++;
        }
      }
    }

    final chartStore = store;
    final height = getBounding().height;
    final optimalTicks = <AxisTick>[];
    final indicators = chartStore
        .getIndicatorsByPaneId(paneId)
        .where((indicator) => indicator.yAxisId == id)
        .toList();
    final styles = chartStore.getStyles();
    var precision = 0;
    var shouldFormatBigNumber = false;
    if (isInCandle() && id == defaultAxisId) {
      precision = chartStore.getSymbol()?.pricePrecision ??
          SymbolDefaultPrecisionConstants.price;
    } else {
      for (final indicator in indicators) {
        precision = math.max(precision, indicator.precision);
        shouldFormatBigNumber =
            shouldFormatBigNumber || indicator.shouldFormatBigNumber;
      }
    }
    final formatter = chartStore.getInnerFormatter();
    final thousandsSeparator = chartStore.getThousandsSeparator();
    final decimalFold = chartStore.getDecimalFold();
    final textHeight = asDouble(asMap(asMap(styles['xAxis'])['tickText'])['size'], 12);
    double? validY;
    for (final tick in ticks) {
      var v = displayValueToText(double.parse('${tick.value}'), precision);
      final y = convertToPixel(double.parse('${tick.value}'));
      if (shouldFormatBigNumber) {
        v = formatter.formatBigNumber(tick.value);
      }
      v = decimalFold.format(thousandsSeparator.format(v));
      if (y > textHeight &&
          y < height - textHeight &&
          ((validY != null && (validY - y).abs() > textHeight * 2) ||
              validY == null)) {
        optimalTicks.add(AxisTick(text: v, coord: y, value: tick.value));
        validY = y;
      }
    }
    if (createTicks != null) {
      return createTicks!(getRange(), getBounding(), optimalTicks);
    }
    return optimalTicks;
  }

  String displayValueToText(double value, int precision) =>
      formatPrecision(value, precision);

  @override
  double getAutoSize() {
    final chartStore = store;
    final styles = chartStore.getStyles();
    final yAxisStyles = asMap(styles['yAxis']);
    final width = yAxisStyles['size'];
    if (width is num) {
      return width.toDouble();
    }
    var yAxisWidth = 0.0;
    if (asBool(yAxisStyles['show'], true)) {
      final axisLine = asMap(yAxisStyles['axisLine']);
      if (asBool(axisLine['show'], true)) {
        yAxisWidth += asDouble(axisLine['size'], 1);
      }
      final tickLine = asMap(yAxisStyles['tickLine']);
      if (asBool(tickLine['show'], true)) {
        yAxisWidth += asDouble(tickLine['length'], 3);
      }
      final tickText = asMap(yAxisStyles['tickText']);
      if (asBool(tickText['show'], true)) {
        var textWidth = 0.0;
        for (final tick in getTicks()) {
          textWidth = math.max(
              textWidth,
              calcTextWidth(tick.text, asDouble(tickText['size'], 12),
                  tickText['weight'], tickText['family'] as String?));
        }
        yAxisWidth += asDouble(tickText['marginStart'], 4) +
            asDouble(tickText['marginEnd'], 6) +
            textWidth;
      }
    }

    final priceMark = asMap(asMap(styles['candle'])['priceMark']);
    final last = asMap(priceMark['last']);
    final lastText = asMap(last['text']);
    final lastPriceMarkTextVisible = asBool(priceMark['show'], true) &&
        asBool(last['show'], true) &&
        asBool(lastText['show'], true);
    var lastPriceTextWidth = 0.0;
    if (lastPriceMarkTextVisible) {
      final dataList = chartStore.getDataList();
      if (dataList.isNotEmpty) {
        final data = dataList.last;
        final pricePrecision = chartStore.getSymbol()?.pricePrecision ??
            SymbolDefaultPrecisionConstants.price;
        lastPriceTextWidth = asDouble(lastText['paddingLeft'], 4) +
            calcTextWidth(formatPrecision(data.close, pricePrecision),
                asDouble(lastText['size'], 12), lastText['weight'],
                lastText['family'] as String?) +
            asDouble(lastText['paddingRight'], 4);
      }
    }
    return math.max(yAxisWidth, lastPriceTextWidth);
  }

  @override
  double convertFromPixel(double pixel) {
    final height = getBounding().height;
    final range = getRange();
    final realFrom = range.realFrom;
    final realRange = range.realRange;
    final rate = reverse ? pixel / height : 1 - pixel / height;
    return rate * realRange + realFrom;
  }

  @override
  double convertToPixel(double value) {
    final range = getRange();
    final height = getBounding().height;
    final realFrom = range.realFrom;
    final realRange = range.realRange;
    final rate = (value - realFrom) / realRange;
    return reverse
        ? (rate * height).roundToDouble()
        : ((1 - rate) * height).roundToDouble();
  }

  double convertToNicePixel(double value) {
    final height = getBounding().height;
    final pixel = convertToPixel(value);
    return math.max(height * 0.05, math.min(pixel, height * 0.98)).roundToDouble();
  }
}

/// X axis (time axis).
class XAxisImp extends AxisImp {
  XAxisImp(super.store, super.paneId);

  @override
  AxisRange createRangeImp() {
    final visibleDataRange = store.getVisibleRange();
    final af = visibleDataRange.realFrom.toDouble();
    final at = visibleDataRange.realTo.toDouble();
    final diff = at - af + 1;
    return AxisRange(
      from: af,
      to: at,
      range: diff,
      realFrom: af,
      realTo: at,
      realRange: diff,
      displayFrom: af,
      displayTo: at,
      displayRange: diff,
    );
  }

  @override
  List<AxisTick> createTicksImp() {
    final range = getRange();
    final realFrom = range.realFrom;
    final realTo = range.realTo;
    final from = range.from;
    final chartStore = store;
    final formatDate = chartStore.getInnerFormatter().formatDate;
    final period = chartStore.getPeriod();
    final ticks = <AxisTick>[];

    final barSpace = chartStore.getBarSpace().bar;
    final textStyles = asMap(asMap(chartStore.getStyles()['xAxis'])['tickText']);
    final tickTextWidth = math.max(
        calcTextWidth('YYYY-MM-DD HH:mm:ss', asDouble(textStyles['size'], 12),
            textStyles['weight'], textStyles['family'] as String?),
        getBounding().width / tickCount);
    var tickBetweenBarCount = (tickTextWidth / barSpace).ceil();
    if (tickBetweenBarCount % 2 != 0) {
      tickBetweenBarCount += 1;
    }
    final startDataIndex =
        math.max(0, (realFrom / tickBetweenBarCount).floor() * tickBetweenBarCount);

    for (var i = startDataIndex; i < realTo; i += tickBetweenBarCount) {
      if (i >= from) {
        final timestamp = chartStore.dataIndexToTimestamp(i);
        if (timestamp != null) {
          ticks.add(AxisTick(
            coord: convertToPixel(i.toDouble()),
            value: timestamp,
            text: formatDate(timestamp,
                periodTypeXAxisFormat[period?.type ?? 'day'] ?? 'YYYY-MM-DD',
                'xAxis'),
          ));
        }
      }
    }

    if (createTicks != null) {
      return createTicks!(getRange(), getBounding(), ticks);
    }
    return ticks;
  }

  @override
  double getAutoSize() {
    final styles = store.getStyles();
    final xAxisStyles = asMap(styles['xAxis']);
    final height = xAxisStyles['size'];
    if (height is num) {
      return height.toDouble();
    }
    final crosshairStyles = asMap(styles['crosshair']);
    var xAxisHeight = 0.0;
    if (asBool(xAxisStyles['show'], true)) {
      final axisLine = asMap(xAxisStyles['axisLine']);
      if (asBool(axisLine['show'], true)) {
        xAxisHeight += asDouble(axisLine['size'], 1);
      }
      final tickLine = asMap(xAxisStyles['tickLine']);
      if (asBool(tickLine['show'], true)) {
        xAxisHeight += asDouble(tickLine['length'], 3);
      }
      final tickText = asMap(xAxisStyles['tickText']);
      if (asBool(tickText['show'], true)) {
        xAxisHeight += asDouble(tickText['marginStart'], 4) +
            asDouble(tickText['marginEnd'], 6) +
            asDouble(tickText['size'], 12);
      }
    }
    var crosshairVerticalTextHeight = 0.0;
    final vertical = asMap(crosshairStyles['vertical']);
    final verticalText = asMap(vertical['text']);
    if (asBool(crosshairStyles['show'], true) &&
        asBool(vertical['show'], true) &&
        asBool(verticalText['show'], true)) {
      crosshairVerticalTextHeight += asDouble(verticalText['paddingTop'], 4) +
          asDouble(verticalText['paddingBottom'], 4) +
          asDouble(verticalText['borderSize'], 1) * 2 +
          asDouble(verticalText['size'], 12);
    }
    return math.max(xAxisHeight, crosshairVerticalTextHeight);
  }

  int? convertTimestampFromPixel(double pixel) {
    final dataIndex = store.coordinateToDataIndex(pixel);
    return store.dataIndexToTimestamp(dataIndex);
  }

  double convertTimestampToPixel(int timestamp) {
    final dataIndex = store.timestampToDataIndex(timestamp);
    return store.dataIndexToCoordinate(dataIndex);
  }

  @override
  double convertFromPixel(double pixel) {
    return store.coordinateToDataIndex(pixel).toDouble();
  }

  @override
  double convertToPixel(double value) {
    return store.dataIndexToCoordinate(value.toInt());
  }
}
