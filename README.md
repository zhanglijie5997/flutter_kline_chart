# kline_chart

A lightweight, high-performance financial **K-line (candlestick) chart** for Flutter — a faithful Dart port of [klinecharts / KLineChart](https://github.com/klinecharts/KLineChart) (v10.0.0-beta3).

The original library renders to an HTML5 canvas; this port renders with Flutter's `CustomPainter` on top of `dart:ui.Canvas` via a thin `Ctx` adapter that mirrors the `CanvasRenderingContext2D` API, so the drawing logic stays faithful to the source.

## Features

- Candlestick / bar / OHLC / area chart types
- Smooth **scroll** and **zoom** (mouse wheel, trackpad pinch, touch drag/pinch)
- **Crosshair** with value + time labels (hover on desktop, long-press on mobile)
- Auto-scaling **Y axis** (nice ticks) and time-based **X axis**
- High / low price marks and animated last-price mark
- **27 built-in technical indicators**, overlaid on the candle pane or in their own sub-panes
- Multiple stacked indicator panes
- Light / dark themes and fully overridable styles
- Register your own indicators and figures

### Built-in indicators

`MA` `EMA` `SMA` `BBI` `VOL` `MACD` `BOLL` `KDJ` `RSI` `BIAS` `BRAR` `CCI` `DMI`
`CR` `PSY` `DMA` `TRIX` `OBV` `VR` `WR` `MTM` `EMV` `SAR` `AO` `ROC` `PVT` `AVP`

## Getting started

Add the dependency:

```yaml
dependencies:
  kline_chart:
    git: https://github.com/klinecharts/KLineChart # or a path/pub reference
```

## Usage

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
      ..setSymbol(SymbolInfo(ticker: 'BTCUSDT', pricePrecision: 2, volumePrecision: 0))
      ..setPeriod(const Period(type: 'day', span: 1))
      ..applyNewData(myBars); // List<KLineData>

    // Overlay MA on the main pane; put VOL + MACD in their own sub-panes.
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
    return KLineChartWidget(
      controller: controller,
      backgroundColor: const Color(0xFF1B1B1F),
    );
  }
}
```

### Feeding data

```dart
// Full reset:
controller.applyNewData(bars);

// Append / update the latest bar (e.g. from a websocket):
controller.updateData(KLineData(
  timestamp: ts, open: o, high: h, low: l, close: c, volume: v,
));

// Prepend older history (pagination):
controller.prependData(olderBars);
```

`KLineData` can also be built from a JSON map with `KLineData.fromMap(map)`.

### Indicators

```dart
// Add to a new sub-pane (returns the pane id):
final paneId = controller.createIndicator('RSI');

// Overlay on the candle pane:
controller.createIndicator('BOLL', paneId: KLineChartController.candlePaneId);

// Custom calc parameters:
controller.createIndicator('MA', calcParams: [7, 25, 99]);

// Per-indicator styles, e.g. hide this indicator's legend text
// (keeps other indicators' legends):
controller.createIndicator('VOL', styles: {'tooltip': {'showRule': 'none'}});

// Remove:
controller.removeIndicator(name: 'RSI');

// List all supported indicators:
controller.supportedIndicators();
```

Register a custom indicator:

```dart
registerIndicator(IndicatorTemplate(
  name: 'MY',
  shortName: 'MY',
  figures: const [IndicatorFigure(key: 'v', title: 'MY: ', type: 'line')],
  calc: (dataList, indicator) => [
    for (final d in dataList) <String, dynamic>{'v': d.close},
  ],
));
```

### Interaction (tap / focus)

```dart
KLineChartWidget(
  controller: controller,
  // Fires on tap/click of a candle.
  onCandleTap: (KLineData data, Offset localPos) { /* show a popup */ },
  // Fires continuously as the focused candle changes (hover / long-press-drag
  // / tap); data is null when the crosshair leaves the chart.
  onCrosshairChange: (KLineData? data, Offset? localPos) { /* ... */ },
)
```

You can also subscribe to the ported actions, or read the focused bar directly:

```dart
controller.subscribeAction(ActionTypes.onCandleBarClick, ([data]) { /* KLineData */ });
final focused = controller.crosshairData; // KLineData?
```

Programmatic scroll / zoom (in addition to the built-in drag / wheel / pinch):

```dart
controller.zoomIn();               // zoom in, centred on the chart
controller.zoomOut();
controller.zoomBy(step);           // step > 0 zooms in (~10% per unit)
controller.startScroll();
controller.scrollByDistance(120);  // scroll horizontally by pixels
```

Hide the top OHLCV legend (e.g. to show only indicator legends):

```dart
controller.setStyles(<String, dynamic>{
  'candle': {'tooltip': {'showRule': 'none'}}, // 'always' | 'follow_cross' | 'none'
});
```

### Buy / sell markers

Anchor trade-signal markers to a bar; they render on the candle pane (buy =
green up-triangle + label below the point, sell = red down-triangle + label
above) and scroll/zoom with the chart. If a marker's bar is focused, its label
is also appended to the top OHLCV legend.

```dart
controller.setMarkers([
  TradeMarker(timestamp: bar.timestamp, price: bar.low,  side: TradeSide.buy,  text: 'Buy'),
  TradeMarker(timestamp: bar.timestamp, price: bar.high, side: TradeSide.sell, text: 'Sell'),
]);
controller.addMarker(marker); // append one
controller.clearMarkers();
```

To render markers as **custom Flutter widgets** (interactive, styled however you
like) instead of the built-in canvas triangles, pass `markerBuilder`. It
receives each marker (the bar's buy/sell info) and returns a widget that is
positioned on the candle pane and tracks scroll/zoom:

```dart
KLineChartWidget(
  controller: controller,
  markerBuilder: (context, m) {
    final buy = m.side == TradeSide.buy;
    return GestureDetector(
      onTap: () => showDetails(m),
      child: Chip(
        avatar: Icon(buy ? Icons.trending_up : Icons.trending_down),
        label: Text('${buy ? 'Buy' : 'Sell'} ${m.price.toStringAsFixed(0)}'),
      ),
    );
  },
)
```

Need a pixel position for your own overlay? `controller.pointToPixel(timestamp, price)`
returns the `Offset` within the chart.

### Styling

Styles are nested `Map<String, dynamic>` objects (matching the original library),
deep-merged over the defaults:

```dart
controller.setStyles(<String, dynamic>{
  'candle': {
    'type': CandleTypes.area, // candle_solid | candle_stroke | ohlc | area | ...
    'bar': {'upColor': '#26A69A', 'downColor': '#EF5350'},
  },
  'grid': {'show': false},
});

// Or switch themes:
controller.setStyles(darkStyleOverrides());
```

## Architecture

| Original (TypeScript) | This port (Dart) |
|---|---|
| HTML5 Canvas / `CanvasRenderingContext2D` | `CustomPainter` + `dart:ui.Canvas` via the `Ctx` adapter |
| DOM container + layered canvases | `KLineChartWidget` (`StatefulWidget`) + `CustomPaint` |
| DOM mouse/touch events | `GestureDetector` / `Listener` |
| `Store` state + coordinate engine | `ChartStore` (`ChangeNotifier`) — ported faithfully |
| `Indicator` / `Figure` / `View` | ported 1:1 (indicators, figures, views) |

## Notes / current limitations

This port covers the full data engine, coordinate/scroll/zoom system, candle &
indicator rendering, axes, crosshair and all 27 built-in indicators. Not yet
ported from upstream: drawing **overlays** (trend lines, shapes), the streaming
`DataLoader`/pagination callbacks, i18n locales and the tooltip legend/feature
buttons. The architecture mirrors the source so these can be added following the
same patterns.

## License

Apache-2.0, same as the upstream project.
# flutter_kline_chart
