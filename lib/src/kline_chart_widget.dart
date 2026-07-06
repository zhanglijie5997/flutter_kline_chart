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

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'common/action.dart';
import 'common/coordinate.dart';
import 'common/data.dart';
import 'common/marker.dart';
import 'kline_chart_controller.dart';
import 'kline_chart_painter.dart';

/// A financial K-line (candlestick) chart widget.
///
/// Drive it through a [KLineChartController]:
///
/// ```dart
/// final controller = KLineChartController();
/// controller.setSymbol(SymbolInfo(ticker: 'BTC'));
/// controller.setPeriod(const Period(type: 'day', span: 1));
/// controller.applyNewData(bars);
/// controller.createIndicator('MA', paneId: KLineChartController.candlePaneId);
/// controller.createIndicator('VOL');
/// // ...
/// KLineChartWidget(controller: controller)
/// ```
class KLineChartWidget extends StatefulWidget {
  final KLineChartController controller;
  final Color backgroundColor;

  /// Called when a single candle is tapped/clicked. [data] is the tapped bar
  /// and [localPosition] is the tap position relative to this widget (handy for
  /// positioning your own floating popup / info window).
  final void Function(KLineData data, Offset localPosition)? onCandleTap;

  /// Called continuously as the focused (crosshair) candle changes — on hover
  /// (desktop), long-press-drag (mobile) and tap. [data] is the focused bar
  /// (or `null` when the crosshair leaves the chart) and [localPosition] is the
  /// pointer position relative to this widget (use its `dx` vs the chart width
  /// to decide which corner to show an info panel in).
  final void Function(KLineData? data, Offset? localPosition)? onCrosshairChange;

  /// Render buy/sell markers as custom Flutter widgets instead of the built-in
  /// canvas triangles. The builder receives each [TradeMarker] (its side,
  /// price, text and timestamp — i.e. the bar's buy/sell info) and returns a
  /// widget, which is positioned on the candle pane and tracks scroll/zoom.
  ///
  /// A buy widget is anchored top-centre at the point (hangs below it); a sell
  /// widget is anchored bottom-centre (sits above it). Returned widgets are
  /// interactive (not wrapped in `IgnorePointer`).
  final Widget Function(BuildContext context, TradeMarker marker)? markerBuilder;

  const KLineChartWidget({
    super.key,
    required this.controller,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.onCandleTap,
    this.onCrosshairChange,
    this.markerBuilder,
  });

  @override
  State<KLineChartWidget> createState() => _KLineChartWidgetState();
}

class _KLineChartWidgetState extends State<KLineChartWidget> {
  double _startFocalX = 0;
  double _baseScale = 1;

  KLineChartController get _c => widget.controller;

  void _onScaleStart(ScaleStartDetails d) {
    _startFocalX = d.localFocalPoint.dx;
    _baseScale = 1;
    _c.store.startScroll();
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount >= 2) {
      final ratio = d.scale / _baseScale;
      if ((ratio - 1).abs() > 0.001) {
        _c.store.zoom((ratio - 1) * 5,
            Coordinate(x: _c.contentX(d.localFocalPoint.dx)), 'main');
        _baseScale = d.scale;
      }
    } else {
      _c.store.scroll(d.localFocalPoint.dx - _startFocalX);
    }
  }

  void _setCrosshair(Offset local) {
    _c.store.setCrosshair(_c.crosshairAt(local.dx, local.dy));
    widget.onCrosshairChange?.call(_c.crosshairData, local);
  }

  void _clearCrosshair() {
    _c.store.setCrosshair(null);
    widget.onCrosshairChange?.call(null, null);
  }

  void _onTapUp(TapUpDetails d) {
    _setCrosshair(d.localPosition);
    final data = _c.store.getCrosshair().kLineData;
    if (data != null) {
      // Fires the ported `onCandleBarClick` action for subscribers,
      _c.store.executeAction(ActionTypes.onCandleBarClick, data);
      // and the convenience widget callback for building a Flutter popup.
      widget.onCandleTap?.call(data, d.localPosition);
    }
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      final scale = -e.scrollDelta.dy / 60.0;
      _c.store.zoom(scale, Coordinate(x: _c.contentX(e.localPosition.dx)), 'main');
      _setCrosshair(e.localPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chart = RepaintBoundary(
      child: Listener(
        onPointerHover: (e) => _setCrosshair(e.localPosition),
        onPointerSignal: _onPointerSignal,
        child: MouseRegion(
          onExit: (_) => _clearCrosshair(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onTapUp,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            onLongPressStart: (d) => _setCrosshair(d.localPosition),
            onLongPressMoveUpdate: (d) => _setCrosshair(d.localPosition),
            onLongPressEnd: (_) => _clearCrosshair(),
            child: CustomPaint(
              painter: KLineChartPainter(_c,
                  backgroundColor: widget.backgroundColor,
                  drawCanvasMarkers: widget.markerBuilder == null),
              size: Size.infinite,
              isComplex: true,
              willChange: true,
            ),
          ),
        ),
      ),
    );
    if (widget.markerBuilder == null) {
      return chart;
    }
    // Overlay custom marker widgets, repositioned whenever the store notifies
    // (scroll / zoom / data change).
    return Stack(
      children: [
        chart,
        Positioned.fill(
          child: ListenableBuilder(
            listenable: _c.layoutVersion,
            builder: (context, _) => _buildMarkerOverlay(context),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkerOverlay(BuildContext context) {
    final builder = widget.markerBuilder!;
    final width = _c.layoutContentWidth;
    final children = <Widget>[];
    for (final marker in _c.markers) {
      final p = _c.markerToPixel(marker);
      if (p == null || p.dx < 0 || p.dx > width) {
        continue;
      }
      final align = marker.side == TradeSide.buy
          ? const Offset(-0.5, 0) // top-centre at the point (hangs below)
          : const Offset(-0.5, -1); // bottom-centre at the point (sits above)
      children.add(Positioned(
        left: p.dx,
        top: p.dy,
        child: FractionalTranslation(
          translation: align,
          child: builder(context, marker),
        ),
      ));
    }
    return Stack(clipBehavior: Clip.hardEdge, children: children);
  }
}
