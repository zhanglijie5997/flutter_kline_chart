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

import 'dart:async';

import '../common/bar_space.dart';
import '../common/bounding.dart';
import '../common/data.dart';
import '../common/utils/format.dart';
import '../common/utils/style.dart';
import '../common/utils/type_checks.dart';
import 'axis.dart';

/// Port of `component/Indicator.ts`.
///
/// Indicator result records are `Map<String, dynamic>` keyed by figure `key`.

typedef IndicatorSeries = String; // 'normal' | 'price' | 'volume'

class IndicatorFigureAttrsCallbackParams {
  final NeighborData<Map<String, dynamic>?> data;
  final NeighborData<Map<String, dynamic>> coordinate;
  final Bounding bounding;
  final BarSpace barSpace;
  final AxisImp xAxis;
  final AxisImp yAxis;
  const IndicatorFigureAttrsCallbackParams({
    required this.data,
    required this.coordinate,
    required this.bounding,
    required this.barSpace,
    required this.xAxis,
    required this.yAxis,
  });
}

class IndicatorFigureStylesCallbackParams {
  final NeighborData<Map<String, dynamic>?> data;
  final IndicatorImp indicator;
  final BarSpace barSpace;
  final Map<String, dynamic> defaultStyles;
  const IndicatorFigureStylesCallbackParams({
    required this.data,
    required this.indicator,
    required this.barSpace,
    required this.defaultStyles,
  });
}

typedef IndicatorFigureAttrsCallback = Map<String, dynamic>? Function(
    IndicatorFigureAttrsCallbackParams params);
typedef IndicatorFigureStylesCallback = Map<String, dynamic>? Function(
    IndicatorFigureStylesCallbackParams params);

class IndicatorFigure {
  final String key;
  final String? title;
  final String? type; // 'line' | 'bar' | 'circle' | 'text'
  final num? baseValue;
  final IndicatorFigureAttrsCallback? attrs;
  final IndicatorFigureStylesCallback? styles;
  const IndicatorFigure({
    required this.key,
    this.title,
    this.type,
    this.baseValue,
    this.attrs,
    this.styles,
  });
}

typedef IndicatorCalcCallback = FutureOr<List<Map<String, dynamic>>> Function(
    List<KLineData> dataList, IndicatorImp indicator);
typedef IndicatorRegenerateFiguresCallback = List<IndicatorFigure> Function(
    List<dynamic> calcParams);

/// Declarative template describing an indicator.
class IndicatorTemplate {
  final String name;
  final String? shortName;
  final int? precision;
  final List<dynamic> calcParams;
  final bool shouldOhlc;
  final bool shouldFormatBigNumber;
  final bool visible;
  final int zLevel;
  final dynamic extendData;
  final IndicatorSeries series;
  final List<IndicatorFigure> figures;
  final num? minValue;
  final num? maxValue;
  final Map<String, dynamic>? styles;
  final IndicatorCalcCallback calc;
  final IndicatorRegenerateFiguresCallback? regenerateFigures;

  const IndicatorTemplate({
    required this.name,
    this.shortName,
    this.precision,
    this.calcParams = const <dynamic>[],
    this.shouldOhlc = false,
    this.shouldFormatBigNumber = false,
    this.visible = true,
    this.zLevel = 0,
    this.extendData,
    this.series = 'normal',
    this.figures = const <IndicatorFigure>[],
    this.minValue,
    this.maxValue,
    this.styles,
    required this.calc,
    this.regenerateFigures,
  });
}

/// Partial override applied via [IndicatorImp.override].
class IndicatorCreate {
  final String name;
  String? id;
  String? paneId;
  String? shortName;
  int? precision;
  List<dynamic>? calcParams;
  bool? shouldOhlc;
  bool? shouldFormatBigNumber;
  bool? visible;
  int? zLevel;
  dynamic extendData;
  IndicatorSeries? series;
  List<IndicatorFigure>? figures;
  num? minValue;
  num? maxValue;
  Map<String, dynamic>? styles;
  IndicatorCalcCallback? calc;

  IndicatorCreate({
    required this.name,
    this.id,
    this.paneId,
    this.shortName,
    this.precision,
    this.calcParams,
    this.shouldOhlc,
    this.shouldFormatBigNumber,
    this.visible,
    this.zLevel,
    this.extendData,
    this.series,
    this.figures,
    this.minValue,
    this.maxValue,
    this.styles,
    this.calc,
  });
}

class IndicatorFilter {
  final String? id;
  final String? paneId;
  final String? name;
  const IndicatorFilter({this.id, this.paneId, this.name});
}

/// Iterate the figures of [indicator] at [dataIndex], resolving default styles
/// by cycling through the per-type style arrays. Port of `eachFigures`.
void eachFigures(
  IndicatorImp indicator,
  int dataIndex,
  BarSpace barSpace,
  Map<String, dynamic> defaultStyles,
  void Function(IndicatorFigure figure, Map<String, dynamic> figureStyles,
          int index)
      eachFigureCallback,
) {
  final result = indicator.result;
  final figures = indicator.figures;
  final styles = indicator.styles;

  final textStyles = asList<Map<String, dynamic>>(
      formatValue(styles, 'texts', defaultStyles['texts']));
  final circleStyles = asList<Map<String, dynamic>>(
      formatValue(styles, 'circles', defaultStyles['circles']));
  final barStyles = asList<Map<String, dynamic>>(
      formatValue(styles, 'bars', defaultStyles['bars']));
  final lineStyles = asList<Map<String, dynamic>>(
      formatValue(styles, 'lines', defaultStyles['lines']));

  var textCount = 0;
  var circleCount = 0;
  var barCount = 0;
  var lineCount = 0;

  var figureIndex = 0;
  for (final figure in figures) {
    Map<String, dynamic> defaultFigureStyles = <String, dynamic>{};
    switch (figure.type) {
      case 'text':
        figureIndex = textCount;
        if (textStyles.isNotEmpty) {
          defaultFigureStyles = textStyles[textCount % textStyles.length];
        }
        textCount++;
        break;
      case 'circle':
        figureIndex = circleCount;
        if (circleStyles.isNotEmpty) {
          final s = circleStyles[circleCount % circleStyles.length];
          defaultFigureStyles = <String, dynamic>{
            ...s,
            'color': s['noChangeColor'],
          };
        }
        circleCount++;
        break;
      case 'bar':
        figureIndex = barCount;
        if (barStyles.isNotEmpty) {
          final s = barStyles[barCount % barStyles.length];
          defaultFigureStyles = <String, dynamic>{
            ...s,
            'color': s['noChangeColor'],
          };
        }
        barCount++;
        break;
      case 'line':
        figureIndex = lineCount;
        if (lineStyles.isNotEmpty) {
          defaultFigureStyles = lineStyles[lineCount % lineStyles.length];
        }
        lineCount++;
        break;
      default:
        break;
    }
    if (isValid(figure.type)) {
      Map<String, dynamic>? ss;
      if (figure.styles != null) {
        ss = figure.styles!(IndicatorFigureStylesCallbackParams(
          data: NeighborData<Map<String, dynamic>?>(
            prev: dataIndex - 1 >= 0 && dataIndex - 1 < result.length
                ? result[dataIndex - 1]
                : null,
            current: dataIndex >= 0 && dataIndex < result.length
                ? result[dataIndex]
                : null,
            next: dataIndex + 1 >= 0 && dataIndex + 1 < result.length
                ? result[dataIndex + 1]
                : null,
          ),
          indicator: indicator,
          barSpace: barSpace,
          defaultStyles: defaultStyles,
        ));
      }
      eachFigureCallback(
        figure,
        <String, dynamic>{...defaultFigureStyles, ...?ss},
        figureIndex,
      );
    }
  }
}

typedef IndicatorConstructor = IndicatorImp Function();

class IndicatorImp {
  String id = '';
  String paneId = '';
  String yAxisId = defaultAxisId;
  String name = '';
  String shortName = '';
  int precision = 4;
  List<dynamic> calcParams = <dynamic>[];
  bool shouldOhlc = false;
  bool shouldFormatBigNumber = false;
  bool visible = true;
  int zLevel = 0;
  dynamic extendData;
  IndicatorSeries series = 'normal';
  List<IndicatorFigure> figures = <IndicatorFigure>[];
  num? minValue;
  num? maxValue;
  Map<String, dynamic>? styles;
  IndicatorCalcCallback calc = (dataList, indicator) => <Map<String, dynamic>>[];
  IndicatorRegenerateFiguresCallback? regenerateFigures;

  List<Map<String, dynamic>> result = <Map<String, dynamic>>[];

  bool _lockSeriesPrecision = false;

  final IndicatorTemplate _template;

  IndicatorImp(this._template) {
    name = _template.name;
    shortName = _template.shortName ?? _template.name;
    if (_template.precision != null) {
      precision = _template.precision!;
    }
    calcParams = List<dynamic>.from(_template.calcParams);
    shouldOhlc = _template.shouldOhlc;
    shouldFormatBigNumber = _template.shouldFormatBigNumber;
    visible = _template.visible;
    zLevel = _template.zLevel;
    extendData = _template.extendData;
    series = _template.series;
    figures = List<IndicatorFigure>.from(_template.figures);
    minValue = _template.minValue;
    maxValue = _template.maxValue;
    if (_template.styles != null) {
      styles = clone(_template.styles!);
    }
    calc = _template.calc;
    regenerateFigures = _template.regenerateFigures;
    if (regenerateFigures != null) {
      figures = regenerateFigures!(calcParams);
    }
  }

  void override(IndicatorCreate create) {
    if (id.isEmpty && create.id != null) {
      id = create.id!;
    }
    if (create.paneId != null) {
      paneId = create.paneId!;
    }
    if (create.shortName != null) {
      shortName = create.shortName!;
    }
    if (create.precision != null) {
      precision = create.precision!;
      _lockSeriesPrecision = true;
    }
    if (create.styles != null) {
      styles ??= <String, dynamic>{};
      merge(styles, create.styles);
    }
    if (create.shouldOhlc != null) shouldOhlc = create.shouldOhlc!;
    if (create.shouldFormatBigNumber != null) {
      shouldFormatBigNumber = create.shouldFormatBigNumber!;
    }
    if (create.visible != null) visible = create.visible!;
    if (create.zLevel != null) zLevel = create.zLevel!;
    if (create.extendData != null) extendData = create.extendData;
    if (create.series != null) series = create.series!;
    if (create.minValue != null) minValue = create.minValue;
    if (create.maxValue != null) maxValue = create.maxValue;
    if (create.calc != null) calc = create.calc!;
    if (create.calcParams != null) {
      calcParams = create.calcParams!;
      if (regenerateFigures != null) {
        figures = regenerateFigures!(calcParams);
      }
    }
    if (create.figures != null) {
      figures = create.figures!;
    }
  }

  void setSeriesPrecision(int p) {
    if (!_lockSeriesPrecision) {
      precision = p;
    }
  }

  Future<bool> calcImp(List<KLineData> dataList) async {
    try {
      final r = await calc(dataList, this);
      result = r;
      return true;
    } catch (e) {
      return false;
    }
  }
}
