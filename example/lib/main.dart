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

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kline_chart/kline_chart.dart';

import 'binance.dart';

void main() => runApp(const MyApp());

/// Advance [dt] by one bar of [period].
DateTime advanceTime(DateTime dt, Period period) {
  switch (period.type) {
    case 'second':
      return dt.add(Duration(seconds: period.span));
    case 'minute':
      return dt.add(Duration(minutes: period.span));
    case 'hour':
      return dt.add(Duration(hours: period.span));
    case 'day':
      return dt.add(Duration(days: period.span));
    case 'week':
      return dt.add(Duration(days: 7 * period.span));
    case 'month':
      return DateTime(dt.year, dt.month + period.span, dt.day, dt.hour, dt.minute);
    case 'year':
      return DateTime(dt.year + period.span, dt.month, dt.day, dt.hour, dt.minute);
    default:
      return dt.add(Duration(days: period.span));
  }
}

/// Generate a random-walk candlestick series spaced by [period].
List<KLineData> generateData(Period period, {int count = 500}) {
  final data = <KLineData>[];
  var dt = DateTime(2023, 1, 1);
  var basePrice = 3500.0;
  final random = Random(period.type.hashCode ^ period.span ^ 7);
  for (var i = 0; i < count; i++) {
    basePrice += (random.nextDouble() - 0.5) * 40;
    final open = basePrice;
    final close = basePrice + (random.nextDouble() - 0.5) * 40;
    final high = max(open, close) + random.nextDouble() * 20;
    final low = min(open, close) - random.nextDouble() * 20;
    final volume = random.nextDouble() * 5000 + 2000;
    data.add(KLineData(
      timestamp: dt.millisecondsSinceEpoch,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
      turnover: volume * close,
    ));
    dt = advanceTime(dt, period);
  }
  return data;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kline_chart demo',
      theme: ThemeData.dark(useMaterial3: true),
      home: const ChartPage(),
    );
  }
}

class ChartPage extends StatefulWidget {
  const ChartPage({super.key, this.historyLoader, this.subscribeLive = true});

  /// Optional injected history loader. Defaults to fetching from Binance;
  /// tests pass a synthetic loader to stay offline/deterministic.
  final Future<List<KLineData>> Function(Period period)? historyLoader;

  /// Whether to open the live websocket (disabled in tests).
  final bool subscribeLive;

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final KLineChartController controller;
  final BinanceSource _binance = BinanceSource(symbol: 'BTCUSDT');
  bool _loading = false;
  String? _error;
  bool _loadingMore = false;
  bool _noMoreHistory = false;

  // Selectable timeframes (Chinese labels, like a Gate-style chart).
  static const List<(String, Period)> _periods = <(String, Period)>[
    ('1分', Period(type: 'minute', span: 1)),
    ('5分', Period(type: 'minute', span: 5)),
    ('15分', Period(type: 'minute', span: 15)),
    ('1时', Period(type: 'hour', span: 1)),
    ('4时', Period(type: 'hour', span: 4)),
    ('12时', Period(type: 'hour', span: 12)),
    ('1日', Period(type: 'day', span: 1)),
    ('3日', Period(type: 'day', span: 3)),
    ('1周', Period(type: 'week', span: 1)),
    ('1月', Period(type: 'month', span: 1)),
    ('1年', Period(type: 'year', span: 1)),
  ];
  int _periodIndex = 4; // 4时

  // Main-pane overlay indicators (bottom selector); BOLL is the default.
  static const List<String> _mainIndicators = <String>['BOLL', 'MA', 'EMA', 'SAR'];
  String _mainIndicator = 'BOLL';

  // Focused candle (follows the crosshair) + pointer position, used to place
  // the info panel in the opposite top corner.
  KLineData? _focused;
  Offset? _focusLocal;

  @override
  void initState() {
    super.initState();
    controller = KLineChartController(styles: darkStyleOverrides());
    controller.setSymbol(
        SymbolInfo(ticker: 'BTCUSDT', pricePrecision: 2, volumePrecision: 3));
    // Top legend: show only technical-indicator values (MA/VOL/...), not the
    // candle OHLCV row. OHLCV is shown in the floating info card instead.
    controller.setStyles(<String, dynamic>{
      'candle': {
        'tooltip': {'showRule': 'none'},
      },
    });
    // Main overlay: BOLL (orange bands, green mid) + VOL and KDJ sub-panes,
    // matching a Gate-style layout. Their legends are shown at each pane's top.
    _createMainIndicator(_mainIndicator);
    controller.createIndicator('VOL');
    controller.createIndicator('KDJ');
    // Load older history when the user scrolls near the left edge.
    controller.store.addListener(_maybeLoadOlder);
    _load(_periods[_periodIndex].$2);
  }

  /// Prefetch older history when the oldest bar comes within 50px of the left
  /// edge.
  void _maybeLoadOlder() {
    if (widget.historyLoader != null) return; // offline / tests: no network
    if (_loading || _loadingMore || _noMoreHistory) return;
    final x0 = controller.oldestBarX;
    if (x0 != null && x0 >= -50) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    final data = controller.getDataList();
    if (data.isEmpty) return;
    _loadingMore = true;
    final period = _periods[_periodIndex].$2;
    final oldestTs = data.first.timestamp;
    try {
      final older = await _binance.fetchHistory(period,
          endTime: oldestTs - 1, limit: 500);
      final fresh = older.where((b) => b.timestamp < oldestTs).toList();
      if (fresh.isEmpty) {
        _noMoreHistory = true; // reached the start of available history
      } else {
        controller.prependData(fresh);
      }
    } catch (_) {
      // ignore; will retry on the next scroll
    } finally {
      _loadingMore = false;
    }
  }

  /// Load history for [period] from Binance, then subscribe to live updates.
  /// Falls back to synthetic data if Binance is unreachable.
  Future<void> _load(Period period) async {
    _noMoreHistory = false;
    _loadingMore = false;
    setState(() {
      _loading = true;
      _error = null;
      _focused = null;
      _focusLocal = null;
    });
    _binance.unsubscribe();
    try {
      final loader = widget.historyLoader;
      final data = loader != null
          ? await loader(period)
          : await _binance.fetchHistory(period, limit: 1000);
      controller
        ..setPeriod(period)
        ..applyNewData(data);
      _placeDemoMarkers(data);
      // Live updates (forming bar + closed bar) push into the chart.
      if (loader == null && widget.subscribeLive) {
        _binance.subscribe(period, controller.updateData);
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      // Offline / geo-blocked: show synthetic data so the demo still works.
      final data = generateData(period);
      controller
        ..setPeriod(period)
        ..applyNewData(data);
      _placeDemoMarkers(data);
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Binance unavailable — showing demo data';
        });
      }
    }
  }

  void _switchPeriod(int index) {
    if (index == _periodIndex) return;
    setState(() => _periodIndex = index);
    _load(_periods[index].$2);
  }

  void _placeDemoMarkers(List<KLineData> data) {
    if (data.length < 60) {
      controller.clearMarkers();
      return;
    }
    final buy = data[data.length - 40];
    final sell = data[data.length - 25];
    controller.setMarkers([
      TradeMarker(
          timestamp: buy.timestamp,
          price: buy.low,
          side: TradeSide.buy,
          text: 'Buy'),
      TradeMarker(
          timestamp: sell.timestamp,
          price: sell.high,
          side: TradeSide.sell,
          text: 'Sell'),
    ]);
  }

  // Tap the chart to drop a buy marker at the focused bar (demo).
  void _addBuyAtFocus() {
    final k = controller.crosshairData;
    if (k != null) {
      controller.addMarker(TradeMarker(
          timestamp: k.timestamp,
          price: k.low,
          side: TradeSide.buy,
          text: 'Buy'));
    }
  }

  /// Create the main-pane overlay indicator, colouring BOLL like the reference.
  void _createMainIndicator(String name) {
    Map<String, dynamic>? styles;
    if (name == 'BOLL') {
      styles = <String, dynamic>{
        'lines': [
          {'color': '#F5A623'}, // UB — orange
          {'color': '#2DC08E'}, // MB — green
          {'color': '#F5A623'}, // LB — orange
        ],
      };
    }
    controller.createIndicator(name,
        paneId: KLineChartController.candlePaneId, styles: styles);
  }

  void _switchMain(String name) {
    if (name == _mainIndicator) return;
    controller.removeIndicator(
        paneId: KLineChartController.candlePaneId, name: _mainIndicator);
    setState(() => _mainIndicator = name);
    _createMainIndicator(name);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    controller.store.removeListener(_maybeLoadOlder);
    _binance.dispose();
    controller.dispose();
    super.dispose();
  }

  bool _lastLandscape = false;

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (landscape != _lastLandscape) {
      _lastLandscape = landscape;
      // Immersive fullscreen chart in landscape; normal chrome in portrait.
      SystemChrome.setEnabledSystemUIMode(
        landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      );
    }

    // Landscape: show only the K-line chart, filling the whole screen.
    if (landscape) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B1B1F),
        body: _buildChart(padding: EdgeInsets.zero),
      );
    }

    // Portrait: full UI.
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'zoomIn',
            tooltip: 'Zoom in',
            onPressed: () => controller.zoomIn(),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'zoomOut',
            tooltip: 'Zoom out',
            onPressed: () => controller.zoomOut(),
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.small(
            heroTag: 'buyMarker',
            tooltip: 'Add buy marker at focused bar',
            onPressed: _addBuyAtFocus,
            child: const Icon(Icons.push_pin_outlined),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0D0D0F),
      bottomNavigationBar: SafeArea(top: false, child: _indicatorBar()),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _buildChart()),
          ],
        ),
      ),
    );
  }

  /// Top bar: timeframe tabs + a few (decorative) tool icons, like the header
  /// of a Gate-style chart.
  Widget _topBar() {
    Widget icon(IconData i) => IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(i, color: Colors.white54, size: 20),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                duration: Duration(milliseconds: 700),
                content: Text('demo')),
          ),
        );
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Expanded(child: _timeframeBar()),
          icon(Icons.fullscreen),
          icon(Icons.candlestick_chart_outlined),
          icon(Icons.settings_outlined),
        ],
      ),
    );
  }

  /// Bottom bar: main-pane indicator switcher (MA/EMA/BOLL/SAR) plus the fixed
  /// sub-pane labels, like a Gate-style indicator menu.
  Widget _indicatorBar() {
    const items = <String>[
      'VOL', 'KDJ', 'MA', 'EMA', 'BOLL', 'SAR', '撑压线', '超级趋势'
    ];
    final switchable = _mainIndicators.toSet();
    return Container(
      height: 44,
      color: const Color(0xFF17171C),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 22),
        itemBuilder: (context, i) {
          final name = items[i];
          final isMain = switchable.contains(name);
          final selected = isMain && name == _mainIndicator;
          final subPane = name == 'VOL' || name == 'KDJ';
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (isMain) {
                _switchMain(name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    duration: const Duration(milliseconds: 800),
                    content: Text('$name: demo only')));
              }
            },
            child: Center(
              child: Text(
                name,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : (subPane ? Colors.white70 : Colors.white54),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _timeframeBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: _periods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) {
          final selected = i == _periodIndex;
          return GestureDetector(
            onTap: () => _switchPeriod(i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF33343A) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _periods[i].$1,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildChart({EdgeInsets padding = const EdgeInsets.all(8)}) {
    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // Finger on the LEFT half -> panel on the RIGHT corner, and
          // vice-versa, so the panel never hides the focused candle.
          final onLeftHalf = (_focusLocal?.dx ?? 0) < width / 2;
          return Stack(
            children: [
                KLineChartWidget(
                  controller: controller,
                  backgroundColor: const Color(0xFF1B1B1F),
                  // Focus (hover / long-press-drag / tap) -> update the panel.
                  onCrosshairChange: (data, localPos) {
                    setState(() {
                      _focused = data;
                      _focusLocal = localPos;
                    });
                  },
                  // Render buy/sell markers as custom, interactive widgets.
                  // The builder gets this bar's buy/sell info (the marker).
                  markerBuilder: (context, m) => _buildMarker(context, m),
                ),
                if (_focused != null)
                  Positioned(
                    top: 8,
                    left: onLeftHalf ? null : 8,
                    right: onLeftHalf ? 8 : null,
                    child: IgnorePointer(child: _infoCard(_focused!)),
                  ),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
                if (_error != null)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xCCB00020),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
  }

  /// Custom buy/sell marker widget (fully replaces the built-in canvas marker).
  ///
  /// Rendered as a speech-bubble: a tappable pill + a triangle pointer aimed at
  /// the bar. Sell sits above the point (pointer down); buy hangs below it
  /// (pointer up). Style it however you like.
  Widget _buildMarker(BuildContext context, TradeMarker m) {
    final buy = m.side == TradeSide.buy;
    final color = buy ? const Color(0xFF2DC08E) : const Color(0xFFF92855);

    final pill = GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content:
              Text('${buy ? 'BUY' : 'SELL'} @ ${m.price.toStringAsFixed(2)}'),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(buy ? Icons.trending_up : Icons.trending_down,
                size: 13, color: Colors.white),
            const SizedBox(width: 3),
            Text(m.text ?? (buy ? 'Buy' : 'Sell'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    final pointer = CustomPaint(
      size: const Size(12, 6),
      painter: _TrianglePainter(color, up: buy),
    );

    // Buy: pointer on top (aims up at the point, pill below).
    // Sell: pill on top, pointer at the bottom (aims down at the point).
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buy ? [pointer, pill] : [pill, pointer],
    );
  }

  Widget _infoCard(KLineData d) {
    final date = DateTime.fromMillisecondsSinceEpoch(d.timestamp);
    final dateText =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    // 涨跌幅 (change %): close vs. the previous bar's close, coloured by
    // direction exactly like the chart's built-in candle tooltip (neutral at
    // a flat bar, no sign — the direction is conveyed by colour).
    final list = controller.getDataList();
    final i = list.indexWhere((e) => e.timestamp == d.timestamp);
    final prevClose = (i > 0) ? list[i - 1].close : d.close;
    final change = d.close - prevClose;
    final pct = prevClose == 0 ? double.nan : change / prevClose * 100;
    final changeColor = change == 0
        ? const Color(0xFF76808F)
        : (change > 0 ? const Color(0xFF2DC08E) : const Color(0xFFF92855));
    final changeText = pct.isFinite ? '${pct.toStringAsFixed(2)}%' : '--';
    // The Close row keeps its candle-body colour (open vs close) so it matches
    // the drawn bars.
    final bodyColor = (d.close >= d.open)
        ? const Color(0xFF2DC08E)
        : const Color(0xFFF92855);
    Widget row(String k, String v, [Color? c]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 52,
                  child: Text(k,
                      style: const TextStyle(color: Colors.white54, fontSize: 12))),
              Text(v,
                  style: TextStyle(
                      color: c ?? Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xE62A2A30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(dateText,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          row('Open', d.open.toStringAsFixed(2)),
          row('High', d.high.toStringAsFixed(2)),
          row('Low', d.low.toStringAsFixed(2)),
          row('Close', d.close.toStringAsFixed(2), bodyColor),
          row('涨跌幅', changeText, changeColor),
          row('Volume', (d.volume ?? 0).toStringAsFixed(0)),
          // Buy/sell markers on this bar -> show side + price in the popup.
          ...controller.markers
              .where((m) => m.timestamp == d.timestamp)
              .map((m) => row(
                    m.side == TradeSide.buy ? 'Buy' : 'Sell',
                    m.price.toStringAsFixed(2),
                    m.side == TradeSide.buy
                        ? const Color(0xFF2DC08E)
                        : const Color(0xFFF92855),
                  )),
        ],
      ),
    );
  }
}

/// A small solid triangle pointer for the marker speech-bubble.
class _TrianglePainter extends CustomPainter {
  final Color color;
  final bool up; // apex at top when true
  _TrianglePainter(this.color, {required this.up});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (up) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(0, size.height)
        ..lineTo(size.width, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.up != up;
}
