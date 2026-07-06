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

import '../common/crosshair.dart';
import '../common/ctx.dart';
import '../common/marker.dart';
import '../common/period.dart';
import '../common/symbol_info.dart';
import '../common/utils/canvas.dart';
import '../common/utils/format.dart';
import '../common/utils/style.dart';
import '../component/indicator.dart';
import '../extension/figure/text.dart';
import 'render_context.dart';

class _LegendItem {
  final String text;
  final String color;
  const _LegendItem(this.text, this.color);
}

/// Draws a wrapping row of legend items and returns the y for the next row.
double _drawLegendRow(
  Ctx ctx,
  List<_LegendItem> items,
  double left,
  double startY,
  double maxWidth,
  Map<String, dynamic> legendStyles,
) {
  final size = asDouble(legendStyles['size'], 12);
  final family = legendStyles['family'] as String?;
  final weight = legendStyles['weight'];
  final marginLeft = asDouble(legendStyles['marginLeft'], 8);
  final marginTop = asDouble(legendStyles['marginTop'], 4);
  final marginRight = asDouble(legendStyles['marginRight'], 8);
  final marginBottom = asDouble(legendStyles['marginBottom'], 4);
  final rowHeight = size + marginTop + marginBottom;

  var x = left;
  var y = startY;
  for (final item in items) {
    final w = calcTextWidth(item.text, size, weight, family);
    if (x + marginLeft + w + marginRight > maxWidth && x > left) {
      x = left;
      y += rowHeight;
    }
    drawText(
        ctx,
        TextAttrs(
            x: x + marginLeft, y: y + marginTop, text: item.text, baseline: 'top'),
        <String, dynamic>{
          'color': item.color,
          'size': size,
          'family': family,
          'weight': weight,
        });
    x += marginLeft + w + marginRight;
  }
  return y + rowHeight;
}

/// Simplified port of `view/CandleTooltipView.ts` — OHLCV legend.
double drawCandleTooltip(Ctx ctx, PaneRenderContext c, Crosshair crosshair) {
  final data = crosshair.kLineData;
  final tooltip = asMap(asMap(c.styles['candle'])['tooltip']);
  if (data == null || asString(tooltip['showRule'], 'always') == 'none') {
    return asDouble(tooltip['offsetTop'], 6);
  }
  final offsetLeft = asDouble(tooltip['offsetLeft'], 4);
  final offsetTop = asDouble(tooltip['offsetTop'], 6);
  final offsetRight = asDouble(tooltip['offsetRight'], 4);
  final maxWidth = c.content.width - offsetRight;

  final symbol = c.store.getSymbol();
  final pricePrecision = symbol?.pricePrecision ?? SymbolDefaultPrecisionConstants.price;
  final volumePrecision = symbol?.volumePrecision ?? SymbolDefaultPrecisionConstants.volume;
  final period = c.store.getPeriod();
  final template =
      periodTypeCrosshairTooltipFormat[period?.type ?? 'day'] ?? 'YYYY-MM-DD';
  final timeText = c.store.getInnerFormatter().formatDate(data.timestamp, template, 'tooltip');

  final params = <String, Object?>{
    'time': timeText,
    'open': formatPrecision(data.open, pricePrecision),
    'high': formatPrecision(data.high, pricePrecision),
    'low': formatPrecision(data.low, pricePrecision),
    'close': formatPrecision(data.close, pricePrecision),
    'volume': formatPrecision(data.volume ?? 0, volumePrecision),
    'turnover': formatPrecision(data.turnover ?? 0, 2),
  };

  final legendStyles = asMap(tooltip['legend']);
  final legendColor = asString(legendStyles['color'], '#76808F');
  final legendTemplate = asList<Map<String, dynamic>>(legendStyles['template']);

  final items = <_LegendItem>[];
  for (final t in legendTemplate) {
    final title = asString(t['title']);
    final valueTemplate = asString(t['value']);
    final value = formatTemplateString(valueTemplate, params);
    items.add(_LegendItem('$title$value', legendColor));
  }

  // If the focused bar carries buy/sell markers, add them to the legend.
  for (final m in c.markers) {
    if (crosshair.dataIndex != null &&
        c.store.timestampToDataIndex(m.timestamp) == crosshair.dataIndex) {
      final label = (m.text != null && m.text!.isNotEmpty)
          ? m.text!
          : (m.side == TradeSide.buy ? 'Buy' : 'Sell');
      items.add(_LegendItem(label, _markerColor(m)));
    }
  }

  if (items.isEmpty) {
    return offsetTop;
  }
  return _drawLegendRow(ctx, items, offsetLeft, offsetTop, maxWidth, legendStyles);
}

String _markerColor(TradeMarker m) {
  final cc = m.color;
  if (cc != null) {
    return 'rgba(${(cc.r * 255).round()},${(cc.g * 255).round()},${(cc.b * 255).round()},${cc.a})';
  }
  return m.side == TradeSide.buy ? '#2DC08E' : '#F92855';
}

/// Simplified port of `view/IndicatorTooltipView.ts` — one legend row per
/// indicator, showing figure titles + values at the crosshair.
void drawIndicatorTooltip(
    Ctx ctx, PaneRenderContext c, Crosshair crosshair, double startY) {
  final data = crosshair.kLineData;
  if (data == null) return;
  final dataIndex = crosshair.dataIndex ?? (c.store.getDataList().length - 1);
  final tooltip = asMap(asMap(c.styles['indicator'])['tooltip']);
  final globalShowRule = asString(tooltip['showRule'], 'always');
  final offsetLeft = asDouble(tooltip['offsetLeft'], 4);
  final offsetRight = asDouble(tooltip['offsetRight'], 4);
  final maxWidth = c.content.width - offsetRight;
  final titleStyles = asMap(tooltip['title']);
  final legendStyles = asMap(tooltip['legend']);
  final titleColor = asString(titleStyles['color'], '#76808F');
  final defaultValue = asString(legendStyles['defaultValue'], 'n/a');
  final defaultStyles = asMap(c.styles['indicator']);
  final barSpace = c.store.getBarSpace();

  var y = startY;
  for (final indicator in c.store.getIndicatorsByPaneId(c.paneId)) {
    if (!indicator.visible) continue;
    // Per-indicator tooltip visibility (override of the global showRule), so a
    // sub-pane indicator can hide its legend while others keep theirs.
    final showRule = asString(
        formatValue(indicator.styles, 'tooltip.showRule', globalShowRule),
        globalShowRule);
    if (showRule == 'none') continue;
    final items = <_LegendItem>[];
    // name (+ params)
    var name = indicator.shortName;
    if (asBool(titleStyles['showParams'], true) && indicator.calcParams.isNotEmpty) {
      name = '$name(${indicator.calcParams.join(',')})';
    }
    if (asBool(titleStyles['showName'], true)) {
      items.add(_LegendItem(name, titleColor));
    }
    // figure values with their colours
    eachFigures(indicator, dataIndex, barSpace, defaultStyles,
        (figure, figureStyles, index) {
      if (figure.type == null) return;
      final result = dataIndex >= 0 && dataIndex < indicator.result.length
          ? indicator.result[dataIndex]
          : const <String, dynamic>{};
      final value = result[figure.key];
      final valueText = value is num
          ? formatPrecision(value, indicator.precision)
          : defaultValue;
      final color = asString(figureStyles['color'], titleColor);
      items.add(_LegendItem('${figure.title ?? ''}$valueText', color));
    });
    if (items.isNotEmpty) {
      y = _drawLegendRow(ctx, items, offsetLeft, y, maxWidth, legendStyles);
    }
  }
}
