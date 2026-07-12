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

import '../common/bounding.dart';
import '../common/coordinate.dart';
import '../common/crosshair.dart';
import '../common/ctx.dart';
import '../common/period.dart';
import '../common/symbol_info.dart';
import '../common/utils/style.dart';
import '../component/axis.dart';
import '../extension/figure/line.dart';
import '../extension/figure/text.dart';
import '../store.dart';
import 'render_context.dart';

/// Port of `view/CrosshairLineView.ts` — draws the crosshair lines for a pane.
void drawCrosshairLines(Ctx ctx, PaneRenderContext c, Crosshair crosshair) {
  final styles = asMap(c.styles['crosshair']);
  if (crosshair.paneId == null || !asBool(styles['show'], true)) {
    return;
  }
  final horizontal = asMap(styles['horizontal']);
  if (crosshair.paneId == c.paneId && crosshair.y != null) {
    if (asBool(horizontal['show'], true)) {
      final line = asMap(horizontal['line']);
      if (asBool(line['show'], true)) {
        drawLine(
            ctx,
            LineAttrs(<Coordinate>[
              Coordinate(x: 0, y: crosshair.y!),
              Coordinate(x: c.content.width, y: crosshair.y!),
            ]),
            line);
      }
    }
  }
  final vertical = asMap(styles['vertical']);
  if (asBool(vertical['show'], true) && crosshair.realX != null) {
    final line = asMap(vertical['line']);
    if (asBool(line['show'], true)) {
      drawLine(
          ctx,
          LineAttrs(<Coordinate>[
            Coordinate(x: crosshair.realX!, y: 0),
            Coordinate(x: crosshair.realX!, y: c.content.height),
          ]),
          line);
    }
  }
}

/// The signed percentage distance of [value] (the price under the crosshair)
/// from [currentPrice] (the latest close), or null when there is no usable
/// reference price.
double? crosshairComparePercent(double value, double? currentPrice) {
  if (currentPrice == null || currentPrice == 0) return null;
  return (value - currentPrice) / currentPrice * 100;
}

/// Formats a change percentage as a signed, 2-decimal label, e.g. "+2.34%".
String formatComparePercent(double pct) =>
    '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(2)}%';

/// Value label in the y-axis gutter (port of CrosshairHorizontalLabelView).
void drawCrosshairHorizontalLabel(
    Ctx ctx, PaneRenderContext c, Crosshair crosshair) {
  final styles = asMap(c.styles['crosshair']);
  final horizontal = asMap(styles['horizontal']);
  final textStyles = asMap(horizontal['text']);
  if (crosshair.paneId != c.paneId ||
      crosshair.y == null ||
      !asBool(styles['show'], true) ||
      !asBool(horizontal['show'], true) ||
      !asBool(textStyles['show'], true)) {
    return;
  }
  final yAxis = c.yAxis;
  final value = yAxis.convertFromPixel(crosshair.y!);
  var precision = 2;
  if (c.isCandle && yAxis.id == defaultAxisId) {
    precision = c.store.getSymbol()?.pricePrecision ??
        SymbolDefaultPrecisionConstants.price;
  } else {
    for (final ind in c.store.getIndicatorsByPaneId(c.paneId)) {
      if (ind.precision > precision) precision = ind.precision;
    }
  }
  var text = yAxis.displayValueToText(value, precision);
  text = c.store.getDecimalFold().format(c.store.getThousandsSeparator().format(text));
  final x = yAxis.isFromZero() ? 0.0 : c.yAxisBounding.width;
  final align = yAxis.isFromZero() ? 'left' : 'right';
  drawText(
      ctx,
      TextAttrs(x: x, y: crosshair.y!, text: text, align: align, baseline: 'middle'),
      textStyles);

  // On the price pane, stack a colored 涨跌幅 badge directly ABOVE the crosshair
  // price label, showing how far that price sits from the latest close. Only
  // meaningful on the candle default axis, where [value] is a real price.
  if (c.isCandle && yAxis.id == defaultAxisId) {
    final dataList = c.store.getDataList();
    final currentPrice = dataList.isEmpty ? null : dataList.last.close;
    final pct = crosshairComparePercent(value, currentPrice);
    if (pct != null) {
      final last = asMap(asMap(asMap(c.styles['candle'])['priceMark'])['last']);
      final color = pct > 0
          ? asString(last['upColor'], '#2DC08E')
          : pct < 0
              ? asString(last['downColor'], '#F92855')
              : asString(last['noChangeColor'], '#888888');
      // Same box height as the price label (padding + text), stacked just above
      // it with a 2px gap via a 'bottom' baseline.
      final labelHeight = asDouble(textStyles['paddingTop'], 4) +
          asDouble(textStyles['size'], 12) +
          asDouble(textStyles['paddingBottom'], 4);
      final badgeStyles = <String, dynamic>{
        ...textStyles,
        'backgroundColor': color,
        'borderColor': color,
      };
      drawText(
          ctx,
          TextAttrs(
              x: x,
              y: crosshair.y! - labelHeight / 2 - 2,
              text: formatComparePercent(pct),
              align: align,
              baseline: 'bottom'),
          badgeStyles);
    }
  }
}

/// Time label in the x-axis pane (port of CrosshairVerticalLabelView).
void drawCrosshairVerticalLabel(
    Ctx ctx, ChartStore store, Bounding bounding, Crosshair crosshair) {
  final styles = asMap(store.getStyles()['crosshair']);
  final vertical = asMap(styles['vertical']);
  final textStyles = asMap(vertical['text']);
  if (crosshair.paneId == null ||
      crosshair.realX == null ||
      crosshair.timestamp == null ||
      !asBool(styles['show'], true) ||
      !asBool(vertical['show'], true) ||
      !asBool(textStyles['show'], true)) {
    return;
  }
  final period = store.getPeriod();
  final template =
      periodTypeCrosshairTooltipFormat[period?.type ?? 'day'] ?? 'YYYY-MM-DD HH:mm';
  final text = store
      .getInnerFormatter()
      .formatDate(crosshair.timestamp!, template, 'crosshair');
  drawText(
      ctx,
      TextAttrs(
          x: crosshair.realX!, y: 0, text: text, align: 'center', baseline: 'top'),
      textStyles);
}
