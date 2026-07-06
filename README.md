# kline_chart

English | [简体中文](README.zh-CN.md)

A lightweight, high-performance financial **K-line (candlestick) chart** for Flutter — a faithful Dart port of [klinecharts / KLineChart](https://github.com/klinecharts/KLineChart) (v10.0.0-beta3).

The original library renders to an HTML5 canvas and is driven by the DOM. This port keeps the drawing/indicator logic faithful to the source while re-architecting the shell for Flutter:

- HTML5 `Canvas` / `CanvasRenderingContext2D` → a `CustomPainter` drawing to `dart:ui.Canvas` through a thin **`Ctx` adapter** that mirrors the Canvas 2D API.
- DOM container + mouse/touch events → a **`KLineChartWidget`** with `GestureDetector` / `Listener`.
- `Store` state + coordinate engine → a **`ChartStore` (`ChangeNotifier`)**, ported method-for-method.

---

## Contents

- [Features](#features)
- [Install](#install)
- [Quick start](#quick-start)
- [Core concepts](#core-concepts)
- [Data](#data)
- [Indicators](#indicators)
- [Interaction: tap, crosshair, zoom, scroll](#interaction)
- [Buy / sell markers](#buy--sell-markers)
- [Styling](#styling)
- [Recipes](#recipes)
  - [Live data from Binance (REST + WebSocket)](#live-data-from-binance)
  - [Fullscreen chart in landscape](#fullscreen-chart-in-landscape)
  - [Floating info panel that follows the crosshair](#floating-info-panel)
  - [Load older history on scroll (pagination)](#load-older-history-on-scroll-pagination)
  - [Volume-only sub-pane](#volume-only-sub-pane)
- [API reference](#api-reference)
- [Architecture](#architecture)
- [Limitations](#limitations)
- [License](#license)

---

## Features

- Chart types: **candlestick**, **bar/hollow**, **OHLC**, **area**
- Smooth **scroll** and **zoom** — mouse wheel, trackpad/touch pinch, drag — plus programmatic `zoomIn/zoomOut/scrollBy`
- **Crosshair** with value + time labels (hover on desktop, long-press-drag / tap on mobile) and a continuous `onCrosshairChange` callback
- Auto-scaling **Y axis** (nice ticks) and period-aware **X axis** (labels format per timeframe)
- High / low price marks, last-price line + label
- **27 built-in technical indicators**, overlaid on the candle pane or shown in their own stacked sub-panes; add / remove / override / register your own
- **Top legend** (per-indicator, colour-matched) with per-indicator show/hide
- **Buy / sell markers** — built-in canvas markers *or* fully custom, interactive Flutter widgets via `markerBuilder`
- Light / dark themes; every style is an overridable nested `Map`
- Register custom **indicators** and **figures**

### Built-in indicators

`MA` `EMA` `SMA` `BBI` `VOL` `MACD` `BOLL` `KDJ` `RSI` `BIAS` `BRAR` `CCI` `DMI`
`CR` `PSY` `DMA` `TRIX` `OBV` `VR` `WR` `MTM` `EMV` `SAR` `AO` `ROC` `PVT` `AVP`

---

## Install

Add the package to your app's `pubspec.yaml`. Use a path or git dependency:

```yaml
dependencies:
  kline_chart:
    path: ../kline_chart          # local path
    # git: https://github.com/klinecharts/KLineChart
```

```dart
import 'package:kline_chart/kline_chart.dart';
```

> **Network note:** if you fetch data over the network (see the Binance recipe), the usual platform permissions apply — Android's `INTERNET` permission (present by default in debug), and macOS needs the `com.apple.security.network.client` entitlement.

---

## Quick start

Everything is driven by a `KLineChartController`; the `KLineChartWidget` renders it.

```dart
import 'package:flutter/material.dart';
import 'package:kline_chart/kline_chart.dart';

class ChartPage extends StatefulWidget {
  const ChartPage({super.key});
  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final KLineChartController controller;

  @override
  void initState() {
    super.initState();
    controller = KLineChartController(styles: darkStyleOverrides())
      ..setSymbol(SymbolInfo(ticker: 'BTCUSDT', pricePrecision: 2, volumePrecision: 3))
      ..setPeriod(const Period(type: 'day', span: 1))
      ..applyNewData(myBars); // List<KLineData>

    // MA overlaid on the main pane; VOL + MACD in their own sub-panes.
    controller.createIndicator('MA', paneId: KLineChartController.candlePaneId);
    controller.createIndicator('VOL');
    controller.createIndicator('MACD');
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1F),
      body: SafeArea(
        child: KLineChartWidget(
          controller: controller,
          backgroundColor: const Color(0xFF1B1B1F),
        ),
      ),
    );
  }
}
```

A complete, runnable demo — Binance live BTC/USDT data, timeframe switching, indicators, markers, zoom buttons, landscape fullscreen — is in [`example/`](example/lib/main.dart).

---

## Core concepts

| Concept | What it is |
|---|---|
| `KLineChartController` | The public API + state holder. Create one, feed it data, add indicators, read/drive the viewport. Call `dispose()` when done. |
| `KLineChartWidget` | The render surface. Takes a controller + optional callbacks (`onCandleTap`, `onCrosshairChange`, `markerBuilder`). Repaints automatically as the controller changes. |
| `KLineData` | One bar: `timestamp` (ms, `int`), `open/high/low/close` (`double`), optional `volume`/`turnover`. |
| **Panes** | The candle pane (id `KLineChartController.candlePaneId`) plus one sub-pane per indicator pane id. The X axis sits at the bottom. |
| **Styles** | Deeply-nested `Map<String, dynamic>` (matching the original library), deep-merged over the defaults. No codegen — just maps. |
| **Numbers** | Coordinates/prices are `double`; indices, timestamps and counts are `int`. |

The controller is a thin facade over a `ChartStore` (a `ChangeNotifier`); the widget listens to it and repaints. State (data, indicators, markers, zoom/scroll position) lives on the controller, so it survives widget rebuilds and orientation changes.

---

## Data

```dart
// Full reset (initial load or symbol/timeframe change):
controller.applyNewData(bars); // List<KLineData>

// Append the newest bar or update the still-forming one (e.g. a websocket tick):
controller.updateData(KLineData(
  timestamp: ts, open: o, high: h, low: l, close: c, volume: v,
));

// Prepend older history (pagination / infinite scroll to the left):
controller.prependData(olderBars);

// Read back:
final bars = controller.getDataList();
```

Build a `KLineData` from JSON with `KLineData.fromMap(map)` (reads `timestamp/open/high/low/close/volume/turnover`, keeps any extra keys).

`updateData` decides automatically: a newer `timestamp` appends a bar; an equal `timestamp` replaces the last bar (the "forming candle" case).

---

## Indicators

```dart
// Add to a new sub-pane; returns the created pane id:
final paneId = controller.createIndicator('RSI');

// Overlay on the candle pane instead of a sub-pane:
controller.createIndicator('BOLL', paneId: KLineChartController.candlePaneId);

// Stack multiple indicators in one pane:
controller.createIndicator('EMA', paneId: paneId, isStack: true);

// Custom calc parameters:
controller.createIndicator('MA', calcParams: [7, 25, 99]);

// Per-indicator styles — e.g. hide *this* indicator's legend text
// (other indicators keep theirs):
controller.createIndicator('VOL', styles: {'tooltip': {'showRule': 'none'}});

// Update an existing indicator:
controller.overrideIndicator(IndicatorCreate(name: 'MA', calcParams: [10, 20]));

// Remove (by pane / name / id):
controller.removeIndicator(name: 'RSI');

// List everything available:
controller.supportedIndicators(); // ['MA', 'EMA', 'VOL', 'MACD', ...]
```

**Register a custom indicator** (available process-wide via `registerIndicator`):

```dart
registerIndicator(IndicatorTemplate(
  name: 'MY',
  shortName: 'MY',
  precision: 2,
  figures: const [
    IndicatorFigure(key: 'v', title: 'MY: ', type: 'line'),
  ],
  // Return one Map per bar, keyed by figure `key`.
  calc: (dataList, indicator) => [
    for (final d in dataList) <String, dynamic>{'v': d.close},
  ],
));
controller.createIndicator('MY');
```

Figure `type` is one of `'line'`, `'bar'`, `'circle'`, `'text'`. A figure's `styles` callback can colour each point (e.g. up/down colouring for `VOL`).

---

## Interaction

### Tap & crosshair callbacks

```dart
KLineChartWidget(
  controller: controller,
  // Discrete tap/click on a candle:
  onCandleTap: (KLineData data, Offset localPos) {
    // e.g. open a details popup
  },
  // Continuous — as the focused candle changes (hover / long-press-drag / tap);
  // data is null when the crosshair leaves the chart:
  onCrosshairChange: (KLineData? data, Offset? localPos) {
    setState(() => _focused = data);
  },
)
```

Or subscribe to the ported actions / read the focused bar directly:

```dart
controller.subscribeAction(ActionTypes.onCandleBarClick, ([data]) {
  final bar = data as KLineData;
});
final focused = controller.crosshairData; // KLineData?
```

Available action types: `ActionTypes.onZoom`, `onScroll`, `onVisibleRangeChange`,
`onCrosshairChange`, `onCandleBarClick`, and more.

### Programmatic zoom / scroll

Built-in gestures (drag to scroll, wheel/pinch to zoom) always work. In addition:

```dart
controller.zoomIn();               // zoom in, centred on the chart
controller.zoomOut();
controller.zoomBy(step);           // step > 0 zooms in (~10% per unit)

controller.startScroll();
controller.scrollByDistance(120);  // scroll horizontally by pixels

controller.setZoomEnabled(false);  // disable gestures if you want
controller.setScrollEnabled(false);
```

---

## Buy / sell markers

Anchor trade-signal markers to a bar `(timestamp, price)`; they render on the candle pane and scroll/zoom with it.

```dart
controller.setMarkers([
  TradeMarker(timestamp: bar.timestamp, price: bar.low,  side: TradeSide.buy,  text: 'Buy'),
  TradeMarker(timestamp: bar.timestamp, price: bar.high, side: TradeSide.sell, text: 'Sell'),
]);
controller.addMarker(marker);   // append one
controller.clearMarkers();
```

By default markers draw as canvas triangles + labels (buy points up below the bar; sell points down above it).

### Custom widget markers

Pass `markerBuilder` to render markers as **interactive Flutter widgets** instead — the builder receives each marker (that bar's buy/sell info) and returns any widget, positioned on the candle pane and kept in sync with scroll/zoom:

```dart
KLineChartWidget(
  controller: controller,
  markerBuilder: (context, m) {
    final buy = m.side == TradeSide.buy;
    return GestureDetector(
      onTap: () => showDetails(m),
      child: Image.network(buy ? buyIcon : sellIcon, width: 32, height: 32),
      // ...or any Chip / Container / bubble you like
    );
  },
)
```

When `markerBuilder` is set, the canvas triangles are skipped. A buy widget is anchored top-centre at the point (hangs below); a sell widget is anchored bottom-centre (sits above).

Need a pixel position for your own overlay? `controller.pointToPixel(timestamp, price)` (or `markerToPixel(marker)`) returns the `Offset` within the chart.

---

## Styling

Styles are nested `Map<String, dynamic>` objects, deep-merged over the defaults. Set them at construction (`KLineChartController(styles: ...)`) or any time with `setStyles`:

```dart
controller.setStyles(<String, dynamic>{
  'candle': {
    'type': CandleTypes.area, // candle_solid | candle_stroke | ohlc | area | ...
    'bar': {'upColor': '#26A69A', 'downColor': '#EF5350'},
  },
  'grid': {'show': false},
});

// Themes (override maps):
controller.setStyles(darkStyleOverrides());
controller.setStyles(lightStyleOverrides());
```

Handy style recipes:

```dart
// Hide the top OHLCV legend (keep indicator legends):
controller.setStyles({'candle': {'tooltip': {'showRule': 'none'}}});

// Hide a single indicator's legend:
controller.createIndicator('VOL', styles: {'tooltip': {'showRule': 'none'}});
```

`showRule` is `'always'` | `'follow_cross'` | `'none'`. The full default style tree is `getDefaultStyles()`; browse it to discover every key (`candle`, `indicator`, `xAxis`, `yAxis`, `grid`, `crosshair`, `separator`, `overlay`).

---

## Recipes

### Live data from Binance

The example ships a small [`BinanceSource`](example/lib/binance.dart) using the public, key-free, non-geo-blocked `*.binance.vision` endpoints:

```dart
// REST history:
final bars = await binance.fetchHistory(period, limit: 1000);
controller..setPeriod(period)..applyNewData(bars);

// Live WebSocket kline updates (forming bar + closed bar):
binance.subscribe(period, controller.updateData);
```

`fetchHistory` maps a `Period` to a Binance interval (`1m`, `1h`, `1d`, `1w`, `1M`, …; it aggregates monthly bars for a yearly view). See the example for the full class + a timeframe switcher (`1m … 1Y`).

### Fullscreen chart in landscape

```dart
@override
Widget build(BuildContext context) {
  final landscape = MediaQuery.of(context).orientation == Orientation.landscape;
  if (landscape) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    return Scaffold(body: KLineChartWidget(controller: controller));
  }
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  return Scaffold(appBar: AppBar(...), body: Column(children: [
    _timeframeBar(),
    // e.g. half the screen in portrait:
    SizedBox(height: MediaQuery.of(context).size.height / 2, child: chart),
  ]));
}
```

The controller isn't rebuilt across rotation, so switching is seamless.

### Floating info panel

Drive a corner panel from `onCrosshairChange`, flipping it to the opposite side so it never hides the focused candle:

```dart
final onLeftHalf = (_focusLocal?.dx ?? 0) < width / 2;
Positioned(
  top: 8,
  left:  onLeftHalf ? null : 8,
  right: onLeftHalf ? 8 : null,
  child: IgnorePointer(child: _infoCard(_focused!)),
);
```

### Load older history on scroll (pagination)

Prepend older bars when the user scrolls near the left edge. `controller.oldestBarX`
is the content x of the oldest loaded bar; trigger when it comes within, say, 50px
of the left edge:

```dart
controller.store.addListener(() {
  if (_loadingMore || _noMore) return;
  final x0 = controller.oldestBarX;
  if (x0 != null && x0 >= -50) _loadOlder(); // within 50px of the left edge
});

Future<void> _loadOlder() async {
  _loadingMore = true;
  final oldest = controller.getDataList().first.timestamp;
  final older = await api.fetchBefore(oldest);   // fetch bars ending before `oldest`
  if (older.isEmpty) { _noMore = true; }
  else { controller.prependData(older); }         // right-anchored; view doesn't jump
  _loadingMore = false;
}
```

`prependData` keeps the right side anchored, so the visible bars stay put while older
history appears to the left. (Binance's `klines` endpoint takes an `endTime` param for
this — see `example/lib/binance.dart`.)

### Volume-only sub-pane

`VOL` shows volume bars plus volume-MA lines by default. Pass empty `calcParams` to drop the MA lines and show only the bars:

```dart
controller.createIndicator('VOL', calcParams: <dynamic>[], styles: {'tooltip': {'showRule': 'none'}});
```

---

## API reference

### `KLineChartController`

```dart
KLineChartController({Map<String, dynamic>? styles, String? locale, String? timezone});
```

| Group | Members |
|---|---|
| Data | `applyNewData(List<KLineData>, {bool more})` · `updateData(KLineData)` · `prependData(List<KLineData>)` · `getDataList()` |
| Symbol / period | `setSymbol(SymbolInfo)` · `getSymbol()` · `setPeriod(Period)` · `getPeriod()` · `setTimezone(String)` · `getTimezone()` |
| Styles | `setStyles(dynamic)` · `getStyles()` |
| Indicators | `createIndicator(name, {isStack, paneId, calcParams, styles}) → String?` · `overrideIndicator(IndicatorCreate)` · `removeIndicator({paneId, name, id})` · `supportedIndicators()` · static `candlePaneId` |
| Markers | `markers` · `setMarkers(List<TradeMarker>)` · `addMarker(TradeMarker)` · `clearMarkers()` · `markerToPixel(m)` · `pointToPixel(ts, price)` |
| Zoom / scroll | `zoomIn([step])` · `zoomOut([step])` · `zoomBy(step)` · `zoomAtCoordinate(scale, x)` · `startScroll()` · `scrollByDistance(px)` · `setZoomEnabled(bool)` · `setScrollEnabled(bool)` |
| Actions | `subscribeAction(type, cb)` · `unsubscribeAction(type, [cb])` · `crosshairData` |
| Lifecycle | `dispose()` |

### `KLineChartWidget`

| Param | Type | Notes |
|---|---|---|
| `controller` | `KLineChartController` | required |
| `backgroundColor` | `Color` | default white |
| `onCandleTap` | `void Function(KLineData, Offset)?` | tap/click a candle |
| `onCrosshairChange` | `void Function(KLineData?, Offset?)?` | continuous focus updates |
| `markerBuilder` | `Widget Function(BuildContext, TradeMarker)?` | custom widget markers |

### Key exported types

`KLineData` · `SymbolInfo` · `Period` (`type`: `'second'…'year'`, `span`) · `Crosshair` ·
`Coordinate` · `Bounding` · `TradeMarker` / `TradeSide` · `IndicatorTemplate` / `IndicatorFigure` /
`IndicatorCreate` · `ActionTypes` · `CandleTypes` / `LineTypes` / `PolygonTypes` (enum string constants) ·
`getDefaultStyles()` / `lightStyleOverrides()` / `darkStyleOverrides()` / `registerStyles` ·
`registerIndicator` / `getSupportedIndicators` · `registerFigure` / `getSupportedFigures` ·
utils: `parseColor`, `calcTextWidth`, `formatBigNumber`, `clone`, `merge`, `isValid`, …

---

## Architecture

| Original (TypeScript) | This port (Dart) |
|---|---|
| HTML5 Canvas / `CanvasRenderingContext2D` | `CustomPainter` + `dart:ui.Canvas` via the `Ctx` adapter (`lib/src/common/ctx.dart`) |
| DOM container + layered canvases | `KLineChartWidget` (`StatefulWidget`) + `CustomPaint` |
| DOM mouse / touch events | `GestureDetector` / `Listener` |
| `Store` state + coordinate engine | `ChartStore` (`ChangeNotifier`) — ported faithfully |
| `Indicator` / `Figure` / `View` | ported 1:1 (indicators, figures, drawing views) |
| CSS colour strings | `parseColor()` → `dart:ui.Color` |

Package layout mirrors the source: `lib/src/{common, component, view, pane, extension/{figure,indicator}}` plus `store.dart`, `kline_chart_controller.dart`, `kline_chart_painter.dart`, `kline_chart_widget.dart`.

---

## Limitations

Ported and working: the data engine, coordinate/scroll/zoom system, candle & indicator rendering, axes, crosshair, top legend, tooltips, all 27 built-in indicators, and buy/sell markers (canvas + custom widgets).

Not yet ported from upstream: the full interactive **drawing overlays** (trend lines / shapes), the streaming `DataLoader` pagination hooks, i18n locales, tooltip feature buttons, and hotkeys. The architecture mirrors the source, so these can be added following the same patterns.

---

## License

Apache-2.0, same as the upstream [klinecharts](https://github.com/klinecharts/KLineChart) project.
