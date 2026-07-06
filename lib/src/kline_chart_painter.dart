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

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'common/bounding.dart';
import 'common/ctx.dart';
import 'common/utils/color.dart';
import 'common/utils/style.dart';
import 'kline_chart_controller.dart';
import 'pane/types.dart';
import 'view/axis_view.dart';
import 'view/candle_view.dart';
import 'view/crosshair_view.dart';
import 'view/grid_view.dart';
import 'view/indicator_view.dart';
import 'view/marker_view.dart';
import 'view/render_context.dart';
import 'view/tooltip_view.dart';

class _PaneLayout {
  final String id;
  final double height;
  final bool isCandle;
  final double top;
  const _PaneLayout(this.id, this.height, this.isCandle, this.top);
}

/// Lays the panes out and draws every view. Repaints whenever the store
/// notifies its listeners.
class KLineChartPainter extends CustomPainter {
  final KLineChartController controller;
  final Color backgroundColor;

  /// When false, buy/sell markers are not drawn on the canvas (the widget
  /// renders them as Flutter widgets via `markerBuilder` instead).
  final bool drawCanvasMarkers;

  KLineChartPainter(
    this.controller, {
    required this.backgroundColor,
    this.drawCanvasMarkers = true,
  }) : super(repaint: controller.store);

  @override
  void paint(Canvas canvas, Size size) {
    final store = controller.store;
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h), Paint()..color = backgroundColor);

    final styles = store.getStyles();
    final xAxis = controller.xAxis;

    // x-axis pane height
    xAxis.bounding = Bounding(width: w, height: 1);
    final xAxisHeight = xAxis.getAutoSize();
    final bodyHeight = math.max(0.0, h - xAxisHeight);

    // pane heights
    final indicatorPaneIds = store.getIndicatorPaneIds();
    final indHeights = <String, double>{};
    var indicatorTotal = 0.0;
    for (final id in indicatorPaneIds) {
      final ph = controller.paneHeights[id] ?? paneDefaultHeight;
      indHeights[id] = ph;
      indicatorTotal += ph;
    }
    var candleHeight = math.max(paneMinHeight, bodyHeight - indicatorTotal);

    // If indicator panes overflow, cap candle at min and let panes clip.
    if (candleHeight + indicatorTotal > bodyHeight) {
      candleHeight = math.max(0.0, bodyHeight - indicatorTotal);
    }

    // y-axis width, two-pass for stability
    var yAxisWidth = controller.lastYAxisWidth;
    var contentWidth = math.max(1.0, w - yAxisWidth);

    final panes = <_PaneLayout>[];
    void buildPaneList() {
      panes.clear();
      var top = 0.0;
      panes.add(_PaneLayout(PaneIdConstants.candle, candleHeight, true, top));
      top += candleHeight;
      for (final id in indicatorPaneIds) {
        panes.add(_PaneLayout(id, indHeights[id]!, false, top));
        top += indHeights[id]!;
      }
    }

    double layoutAndMeasure() {
      store.setTotalBarSpace(contentWidth);
      buildPaneList();
      var maxW = 0.0;
      for (final p in panes) {
        final ya = controller.yAxisFor(p.id, p.isCandle);
        ya.bounding = Bounding(width: yAxisWidth, height: p.height);
        ya.buildTicks(true);
        maxW = math.max(maxW, ya.getAutoSize());
      }
      return maxW;
    }

    final measured = layoutAndMeasure().clamp(20.0, w * 0.5);
    if ((measured - yAxisWidth).abs() > 0.5) {
      yAxisWidth = measured;
      contentWidth = math.max(1.0, w - yAxisWidth);
      layoutAndMeasure();
    }
    controller.lastYAxisWidth = yAxisWidth;

    // x-axis ticks
    xAxis.bounding = Bounding(width: contentWidth, height: xAxisHeight);
    xAxis.buildTicks(true);

    // publish layout for gesture hit-testing
    controller.layoutContentWidth = contentWidth;
    controller.layoutBodyHeight = bodyHeight;
    controller.layoutPanes = panes
        .map((p) => PaneRect(p.id, p.top, p.height, p.isCandle))
        .toList();
    // Refresh widget overlays (marker widgets) against the fresh layout, after
    // this frame commits (can't mark widgets dirty during paint).
    SchedulerBinding.instance
        .addPostFrameCallback((_) => controller.bumpLayoutVersion());

    final gutterLeft = contentWidth;
    final crosshair = store.getCrosshair();
    final separatorColor =
        asString(asMap(styles['separator'])['color'], '#DDDDDD');

    for (final p in panes) {
      final ya = controller.yAxisFor(p.id, p.isCandle);
      final content = Bounding(width: contentWidth, height: p.height);
      final gutter = Bounding(width: yAxisWidth, height: p.height);
      final rc = PaneRenderContext(
        store: store,
        paneId: p.id,
        isCandle: p.isCandle,
        content: content,
        yAxisBounding: gutter,
        yAxis: ya,
        xAxis: xAxis,
        markers: p.isCandle ? controller.markers : const [],
      );

      // content area
      canvas.save();
      canvas.translate(0, p.top);
      canvas.clipRect(Rect.fromLTWH(0, 0, contentWidth, p.height));
      final ctx = Ctx(canvas, Size(contentWidth, p.height));
      drawGrid(ctx, rc);
      if (p.isCandle) {
        drawCandleArea(ctx, rc);
        drawCandleBar(ctx, rc);
        drawIndicators(ctx, rc);
        drawCandleHighLow(ctx, rc);
        drawCandleLastPriceLine(ctx, rc);
        if (drawCanvasMarkers) {
          drawMarkers(ctx, rc, controller.markers);
        }
      } else {
        drawIndicators(ctx, rc);
      }
      drawCrosshairLines(ctx, rc, crosshair);
      // tooltips (legend) on top
      if (p.isCandle) {
        final nextY = drawCandleTooltip(ctx, rc, crosshair);
        drawIndicatorTooltip(ctx, rc, crosshair, nextY);
      } else {
        drawIndicatorTooltip(ctx, rc, crosshair, 0);
      }
      canvas.restore();

      // y-axis gutter
      canvas.save();
      canvas.translate(gutterLeft, p.top);
      canvas.clipRect(Rect.fromLTWH(0, 0, yAxisWidth, p.height));
      final gctx = Ctx(canvas, Size(yAxisWidth, p.height));
      drawYAxis(gctx, ya, gutter, styles);
      if (p.isCandle) {
        drawCandleLastPriceLabel(gctx, rc);
      }
      drawCrosshairHorizontalLabel(gctx, rc, crosshair);
      canvas.restore();

      // separator between panes
      if (p.top > 0) {
        canvas.drawLine(Offset(0, p.top), Offset(w, p.top),
            Paint()..color = parseColor(separatorColor));
      }
    }

    // x-axis pane
    canvas.save();
    canvas.translate(0, bodyHeight);
    canvas.clipRect(Rect.fromLTWH(0, 0, w, xAxisHeight));
    final xctx = Ctx(canvas, Size(w, xAxisHeight));
    final xBounding = Bounding(width: contentWidth, height: xAxisHeight);
    drawXAxis(xctx, xAxis, xBounding, styles);
    drawCrosshairVerticalLabel(xctx, store, xBounding, crosshair);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KLineChartPainter oldDelegate) =>
      oldDelegate.controller != controller ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.drawCanvasMarkers != drawCanvasMarkers;
}
