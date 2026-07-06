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

import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'common/action.dart';
import 'common/coordinate.dart';
import 'common/crosshair.dart';
import 'common/data.dart';
import 'common/marker.dart';
import 'common/period.dart';
import 'common/symbol_info.dart';
import 'common/utils/id.dart';
import 'component/axis.dart';
import 'component/indicator.dart';
import 'extension/indicator/index.dart' as indicator_registry;
import 'pane/types.dart';
import 'store.dart';

/// Layout rectangle for one pane, published by the painter for hit-testing.
class PaneRect {
  final String id;
  final double top;
  final double height;
  final bool isCandle;
  const PaneRect(this.id, this.top, this.height, this.isCandle);
}

/// High-level controller wrapping [ChartStore] and the axis components, and
/// exposing the public chart API (the Flutter analogue of the `Chart` object
/// returned by `init` in the original library).
class KLineChartController {
  final ChartStore store;
  late final XAxisImp xAxis;
  final Map<String, YAxisImp> _yAxes = <String, YAxisImp>{};

  /// Heights (in logical pixels) for indicator panes, keyed by pane id.
  final Map<String, double> paneHeights = <String, double>{};

  /// Cached y-axis gutter width used to keep layout stable between frames.
  double lastYAxisWidth = 60;

  // Layout published by the painter each frame, for gesture hit-testing.
  double layoutContentWidth = 0;
  double layoutBodyHeight = 0;
  List<PaneRect> layoutPanes = <PaneRect>[];

  /// Bumped by the painter (post-frame) after publishing a new layout, so
  /// widget overlays (e.g. [markerBuilder]) reposition against fresh geometry.
  final ValueNotifier<int> layoutVersion = ValueNotifier<int>(0);
  bool _disposed = false;

  void bumpLayoutVersion() {
    if (!_disposed) {
      layoutVersion.value++;
    }
  }

  /// Buy/sell markers drawn on the candle pane.
  List<TradeMarker> markers = <TradeMarker>[];

  int _indicatorPaneCounter = 0;

  KLineChartController({
    Map<String, dynamic>? styles,
    String? locale,
    String? timezone,
  }) : store = ChartStore(styles: styles, locale: locale, timezone: timezone) {
    store.candlePaneId = PaneIdConstants.candle;
    xAxis = XAxisImp(store, PaneIdConstants.xAxis);
  }

  YAxisImp yAxisFor(String paneId, bool isCandle) =>
      _yAxes.putIfAbsent(paneId, () => YAxisImp(store, paneId, isCandlePane: isCandle));

  void _pruneAxes(Iterable<String> livePaneIds) {
    final live = livePaneIds.toSet();
    _yAxes.removeWhere((id, _) => !live.contains(id));
  }

  // ---- data / symbol / period ------------------------------------------------

  void applyNewData(List<KLineData> data, {bool more = false}) =>
      store.applyNewData(data, more: more);

  void updateData(KLineData data) => store.updateData(data);

  void prependData(List<KLineData> data) => store.prependData(data);

  List<KLineData> getDataList() => store.getDataList();

  void setSymbol(SymbolInfo symbol) => store.setSymbol(symbol);
  SymbolInfo? getSymbol() => store.getSymbol();

  void setPeriod(Period period) => store.setPeriod(period);
  Period? getPeriod() => store.getPeriod();

  // ---- styles ----------------------------------------------------------------

  void setStyles(dynamic value) => store.setStyles(value);
  Map<String, dynamic> getStyles() => store.getStyles();

  void setTimezone(String timezone) {
    store.setTimezone(timezone);
    store.invalidate();
  }

  String getTimezone() => store.getTimezone();

  // ---- indicators ------------------------------------------------------------

  /// Create an indicator. Returns the pane id it was placed on, or `null` if
  /// the indicator name is unknown.
  ///
  /// If [paneId] is omitted, a new indicator pane is created; pass the candle
  /// pane id (see [candlePaneId]) to overlay on the main chart.
  String? createIndicator(
    String name, {
    bool isStack = false,
    String? paneId,
    List<dynamic>? calcParams,
    Map<String, dynamic>? styles,
  }) {
    final pid = paneId ?? 'indicator_pane_${_indicatorPaneCounter++}';
    final create = IndicatorCreate(
      name: name,
      id: createId('indicator_'),
      paneId: pid,
      calcParams: calcParams,
      styles: styles,
    );
    final ok = store.addIndicator(create, isStack);
    if (!ok) {
      return null;
    }
    return pid;
  }

  bool overrideIndicator(IndicatorCreate override) =>
      store.overrideIndicator(override);

  bool removeIndicator({String? paneId, String? name, String? id}) {
    final removed =
        store.removeIndicator(IndicatorFilter(paneId: paneId, name: name, id: id));
    _pruneAxes(<String>[PaneIdConstants.candle, ...store.getIndicatorPaneIds()]);
    return removed;
  }

  List<String> supportedIndicators() =>
      indicator_registry.getSupportedIndicators();

  static String get candlePaneId => PaneIdConstants.candle;

  // ---- viewport --------------------------------------------------------------

  void zoomAtCoordinate(double scale, double x) {
    store.zoom(scale, Coordinate(x: x), 'main');
  }

  /// Zoom the chart, anchored at its horizontal centre. [step] > 0 zooms in
  /// (bars widen), [step] < 0 zooms out. Each unit is ~10%.
  void zoomBy(double step) {
    final width = layoutContentWidth > 0
        ? layoutContentWidth
        : store.getTotalBarSpace();
    store.zoom(step, Coordinate(x: width / 2), 'main');
  }

  void zoomIn([double step = 3]) => zoomBy(step);

  void zoomOut([double step = 3]) => zoomBy(-step);

  /// Replace all buy/sell markers and repaint.
  void setMarkers(List<TradeMarker> value) {
    markers = value;
    store.invalidate();
  }

  /// Append a single buy/sell marker and repaint.
  void addMarker(TradeMarker marker) {
    markers = <TradeMarker>[...markers, marker];
    store.invalidate();
  }

  void clearMarkers() {
    markers = <TradeMarker>[];
    store.invalidate();
  }

  void startScroll() => store.startScroll();

  void scrollByDistance(double distance) => store.scroll(distance);

  void setScrollEnabled(bool enabled) => store.setScrollEnabled(enabled);
  void setZoomEnabled(bool enabled) => store.setZoomEnabled(enabled);

  /// Build a [Crosshair] for a pointer at ([dx], [dy]) in widget coordinates,
  /// or `null` if the point is outside the panes.
  Crosshair? crosshairAt(double dx, double dy) {
    if (layoutPanes.isEmpty || layoutContentWidth <= 0) {
      return null;
    }
    final x = dx.clamp(0.0, layoutContentWidth);
    if (dy < 0 || dy > layoutBodyHeight) {
      // In the x-axis region: keep only the vertical crosshair.
      return Crosshair(x: x, paneId: PaneIdConstants.candle);
    }
    for (final p in layoutPanes) {
      if (dy >= p.top && dy < p.top + p.height) {
        return Crosshair(x: x, y: dy - p.top, paneId: p.id);
      }
    }
    return Crosshair(x: x, paneId: layoutPanes.last.id);
  }

  double contentX(double dx) => dx.clamp(0.0, layoutContentWidth);

  /// Content x-coordinate of the oldest loaded bar (data index 0), or `null`
  /// if there is no data. Useful for "load older history when scrolled near
  /// the left edge": trigger when this value is `>= -threshold`.
  double? get oldestBarX =>
      store.getDataList().isEmpty ? null : store.dataIndexToCoordinate(0);

  /// Convert a `(timestamp, price)` point to a pixel [Offset] within the chart
  /// widget (candle pane), or `null` if the layout isn't ready yet. `x` is in
  /// content coordinates; `y` includes the candle pane's top offset.
  ///
  /// Uses the range/layout published by the most recent paint, so overlays
  /// built from it track scroll/zoom (with at most one frame of lag).
  Offset? pointToPixel(int timestamp, double price) {
    if (layoutPanes.isEmpty) return null;
    PaneRect? candle;
    for (final p in layoutPanes) {
      if (p.isCandle) {
        candle = p;
        break;
      }
    }
    if (candle == null) return null;
    final yAxis = yAxisFor(PaneIdConstants.candle, true);
    final x = store.dataIndexToCoordinate(store.timestampToDataIndex(timestamp));
    final y = candle.top + yAxis.convertToPixel(price);
    return Offset(x, y);
  }

  /// Pixel [Offset] a [TradeMarker] points at (see [pointToPixel]).
  Offset? markerToPixel(TradeMarker marker) =>
      pointToPixel(marker.timestamp, marker.price);

  // ---- actions ---------------------------------------------------------------

  /// Subscribe to a chart action (see [ActionTypes]), e.g.
  /// `subscribeAction(ActionTypes.onCandleBarClick, (data) { ... })` where the
  /// payload for `onCandleBarClick`/`onCrosshairChange` is a [KLineData].
  void subscribeAction(ActionType type, ActionCallback callback) =>
      store.subscribeAction(type, callback);

  void unsubscribeAction(ActionType type, [ActionCallback? callback]) =>
      store.unsubscribeAction(type, callback);

  /// The [KLineData] currently under the crosshair, if any.
  KLineData? get crosshairData => store.getCrosshair().kLineData;

  void dispose() {
    _disposed = true;
    layoutVersion.dispose();
    store.dispose();
  }
}
