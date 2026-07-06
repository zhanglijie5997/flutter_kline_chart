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

/// kline_chart — a lightweight, high-performance financial K-line
/// (candlestick) chart for Flutter. A faithful Dart port of klinecharts
/// (https://github.com/klinecharts/KLineChart).
library kline_chart;

export 'src/version.dart';

// Widget + controller (the public entry points).
export 'src/kline_chart_widget.dart';
export 'src/kline_chart_controller.dart' show KLineChartController, PaneRect;

// Data types.
export 'src/common/data.dart' show KLineData, NeighborData, VisibleRangeData;
export 'src/common/symbol_info.dart'
    show SymbolInfo, SymbolDefaultPrecisionConstants;
export 'src/common/period.dart'
    show Period, PeriodType, periodTypeXAxisFormat, periodTypeCrosshairTooltipFormat;
export 'src/common/crosshair.dart' show Crosshair;
export 'src/common/coordinate.dart' show Coordinate, getDistance;
export 'src/common/marker.dart' show TradeMarker, TradeSide;
export 'src/common/bounding.dart' show Bounding;

// Actions.
export 'src/common/action.dart' show ActionType, ActionTypes, ActionCallback;

// Styles (represented as nested Map<String, dynamic>).
export 'src/common/styles.dart'
    show
        getDefaultStyles,
        getStyles,
        registerStyles,
        lightStyleOverrides,
        darkStyleOverrides,
        KColor,
        LineType,
        LineTypes,
        PolygonType,
        PolygonTypes,
        PathType,
        PathTypes,
        CandleType,
        CandleTypes,
        TooltipShowRule,
        TooltipShowRules,
        TooltipShowType,
        TooltipShowTypes,
        FeatureType,
        FeatureTypes;

// Indicators.
export 'src/component/indicator.dart'
    show
        IndicatorTemplate,
        IndicatorFigure,
        IndicatorCreate,
        IndicatorFilter,
        IndicatorImp,
        IndicatorSeries,
        IndicatorFigureAttrsCallbackParams,
        IndicatorFigureStylesCallbackParams,
        eachFigures;
export 'src/extension/indicator/index.dart'
    show registerIndicator, getSupportedIndicators, getIndicatorTemplate;

// Figures.
export 'src/component/figure.dart' show FigureTemplate, FigureImp;
export 'src/extension/figure/index.dart'
    show registerFigure, getSupportedFigures, getFigureClass;

// Utilities mirrored from the original `utils` export.
export 'src/common/utils/type_checks.dart'
    show clone, merge, isString, isNumber, isValid, isObject, isArray, isFunction, isBoolean;
export 'src/common/utils/format.dart'
    show
        formatValue,
        formatPrecision,
        formatBigNumber,
        formatThousands,
        formatFoldDecimal;
export 'src/common/utils/color.dart' show parseColor;
export 'src/common/utils/canvas.dart' show calcTextWidth;
