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
import 'dart:math';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kline_chart/kline_chart.dart';

import 'binance.dart';

/// Contract-list load state shared with the symbol picker.
typedef _SymbolState = ({
  List<FuturesSymbol> list,
  Map<String, Ticker> tickers,
  bool loading,
  String? error,
});

/// Format [v] to [precision] decimals with thousands separators, e.g.
/// `62,748.40`.
String _fmtPrice(double v, int precision) {
  final s = v.toStringAsFixed(precision);
  final dot = s.indexOf('.');
  final intPart = dot == -1 ? s : s.substring(0, dot);
  final frac = dot == -1 ? '' : s.substring(dot);
  final neg = intPart.startsWith('-');
  final digits = neg ? intPart.substring(1) : intPart;
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}$buf$frac';
}

/// A small pill tagging a contract as TradFi (gold) or a crypto 永续 (green).
Widget _typeTag(bool tradFi, {double fontSize = 10}) {
  final color = tradFi ? const Color(0xFFF5A623) : const Color(0xFF2DC08E);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Text(tradFi ? 'TradFi' : '永续',
        style: TextStyle(color: color, fontSize: fontSize)),
  );
}

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
      return DateTime(
          dt.year, dt.month + period.span, dt.day, dt.hour, dt.minute);
    case 'year':
      return DateTime(
          dt.year + period.span, dt.month, dt.day, dt.hour, dt.minute);
    default:
      return dt.add(Duration(days: period.span));
  }
}

/// Binance UTC bucket open time for a trade received before history is ready.
/// The explicit 3-day/weekly anchors match futures REST kline boundaries.
int tradeBucketStart(int timestamp, Period period) {
  final at = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  switch (period.type) {
    case 'second':
    case 'minute':
    case 'hour':
      final unitMs = period.type == 'second'
          ? const Duration(seconds: 1).inMilliseconds
          : period.type == 'minute'
              ? const Duration(minutes: 1).inMilliseconds
              : const Duration(hours: 1).inMilliseconds;
      final intervalMs = unitMs * period.span;
      return (timestamp ~/ intervalMs) * intervalMs;
    case 'day':
      if (period.span == 1) {
        return DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch;
      }
      final anchor = DateTime.utc(2000).millisecondsSinceEpoch;
      final intervalMs = Duration(days: period.span).inMilliseconds;
      return anchor + ((timestamp - anchor) ~/ intervalMs) * intervalMs;
    case 'week':
      final monday = DateTime.utc(at.year, at.month, at.day)
          .subtract(Duration(days: at.weekday - DateTime.monday));
      if (period.span == 1) return monday.millisecondsSinceEpoch;
      final anchor = DateTime.utc(2000, 1, 3).millisecondsSinceEpoch;
      final intervalMs = Duration(days: 7 * period.span).inMilliseconds;
      return anchor + ((timestamp - anchor) ~/ intervalMs) * intervalMs;
    case 'month':
      final absoluteMonth = at.year * 12 + at.month - 1;
      final bucketMonth = (absoluteMonth ~/ period.span) * period.span;
      return DateTime.utc(bucketMonth ~/ 12, bucketMonth % 12 + 1)
          .millisecondsSinceEpoch;
    case 'year':
      final bucketYear = (at.year ~/ period.span) * period.span;
      return DateTime.utc(bucketYear).millisecondsSinceEpoch;
    default:
      return timestamp;
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
  const ChartPage({
    super.key,
    this.historyLoader,
    this.subscribeLive = true,
    this.demoTickers,
    this.marketSource,
  });

  /// Optional injected history loader. Defaults to fetching from Binance;
  /// tests pass a synthetic loader to stay offline/deterministic.
  final Future<List<KLineData>> Function(Period period)? historyLoader;

  /// Whether to open the live websocket (disabled in tests).
  final bool subscribeLive;

  /// Optional seed price/change map for the picker (tests inject it since the
  /// live ticker fetch is skipped offline).
  final Map<String, Ticker>? demoTickers;

  /// Optional injected market source. Production creates a Binance source;
  /// tests can inject a deterministic source and exercise the live callbacks.
  final BinanceSource? marketSource;

  @override
  State<ChartPage> createState() => _ChartPageState();
}

class _ChartPageState extends State<ChartPage> {
  late final KLineChartController controller;
  late final BinanceSource _binance;

  // Available contracts (seeded with a small offline list, replaced by the full
  // Binance futures list once fetched) + load status, exposed to the picker via
  // a notifier so a late fetch / retry updates the sheet while it is open.
  final ValueNotifier<_SymbolState> _symbolsState =
      ValueNotifier<_SymbolState>((
    list: BinanceSource.fallbackSymbols,
    tickers: const <String, Ticker>{},
    loading: false,
    error: null,
  ));
  // The currently-selected contract.
  FuturesSymbol _symbol = BinanceSource.fallbackSymbols.first;

  // Remembered picker view so reopening returns to the last-closed position:
  // the selected 板块 (sector) and the list's scroll offset.
  String? _pickerSector;
  double _pickerScroll = 0;

  bool _loading = false;
  String? _error;
  bool _loadingMore = false;
  bool _noMoreHistory = false;
  // Bumped on every full reload; lets stale async responses (from a superseded
  // symbol/timeframe switch) bail before they clobber the current contract.
  int _loadGen = 0;

  // Live websocket status + the latest ticker (header price / 24h 涨跌幅) +
  // app-lifecycle listener used to reconnect & backfill on foreground.
  Ticker? _liveTicker;
  AppLifecycleListener? _lifecycle;
  // Data-freshness heartbeat. Bar, all-market-price, and 24h-stat freshness are
  // tracked independently: a healthy trade/ticker stream must not mask a frozen
  // kline stream, and the large 24h snapshot is refreshed much less frequently
  // than lightweight prices.
  Timer? _heartbeatTimer;
  DateTime _lastBarUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastBarSyncUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastMarketUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSelectedTickerUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSelectedTickerAttempt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastListPriceUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastFullTickerUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  int? _barPollingGen;
  int? _selectedTickerPollingGen;
  bool _pricePolling = false; // lightweight all-symbol prices poll is in flight
  bool _tickerPolling = false; // full all-symbol 24h poll is in flight
  Timer? _tradeFlushTimer; // caps high-frequency trade-driven chart rebuilds
  KLineData? _pendingLiveBar;
  int _tradeSequence = 0;
  bool _dataStale =
      false; // no update from WS or REST for a while (shows a hint)

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
  static const List<String> _mainIndicators = <String>[
    'BOLL',
    'MA',
    'EMA',
    'SAR'
  ];
  String _mainIndicator = 'BOLL';

  // Focused candle (follows the crosshair) + pointer position, used to place
  // the info panel in the opposite top corner.
  KLineData? _focused;
  Offset? _focusLocal;

  @override
  void initState() {
    super.initState();
    _binance = widget.marketSource ?? BinanceSource(symbol: 'BTCUSDT');
    controller = KLineChartController(styles: darkStyleOverrides());
    controller.setSymbol(SymbolInfo(
        ticker: _symbol.symbol,
        pricePrecision: _symbol.pricePrecision,
        volumePrecision: _symbol.quantityPrecision));
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
    // Reconnect + backfill when the app returns to the foreground.
    _lifecycle = AppLifecycleListener(onResume: _onAppResume);
    if (widget.demoTickers != null) {
      _symbolsState.value = (
        list: _symbolsState.value.list,
        tickers: widget.demoTickers!,
        loading: false,
        error: null,
      );
      _liveTicker = widget.demoTickers![_symbol.symbol];
    }
    _loadSymbols();
    _load(_periods[_periodIndex].$2);
  }

  /// Fetch the full list of Binance perpetual contracts (skipped offline/tests,
  /// where the fallback list is used instead). Updates [_symbolsState] so the
  /// picker shows the full list, a spinner, or an error+retry as appropriate.
  Future<void> _loadSymbols() async {
    if (widget.historyLoader != null) return; // offline / tests: no network
    if (_symbolsState.value.loading) return; // a fetch is already running
    final current = _symbolsState.value;
    _symbolsState.value = (
      list: current.list,
      tickers: current.tickers,
      loading: true,
      error: null,
    );
    final symbolsFuture = BinanceSource.fetchSymbols().then<void>((symbols) {
      if (!mounted) return;
      final latest = _symbolsState.value;
      _symbolsState.value = (
        list: symbols.isNotEmpty ? symbols : latest.list,
        tickers: latest.tickers,
        loading: false,
        error: symbols.isEmpty ? '未获取到合约' : null,
      );
    }).catchError((_) {
      if (!mounted) return;
      final latest = _symbolsState.value;
      _symbolsState.value = (
        list: latest.list,
        tickers: latest.tickers,
        loading: false,
        error: '合约列表加载失败（网络或地区限制）',
      );
    });
    final tickersFuture = BinanceSource.fetchTickers().then<void>((tickers) {
      if (!mounted || tickers.isEmpty) return;
      _mergeTickers(tickers);
      final now = DateTime.now();
      _lastListPriceUpdate = now;
      _lastFullTickerUpdate = now;
      _lastMarketUpdate = now;
      if (tickers.containsKey(_symbol.symbol)) {
        _lastSelectedTickerUpdate = now;
      }
    }).catchError((_) {
      // Prices have their own lightweight heartbeat fallback.
    });
    await Future.wait<void>(<Future<void>>[symbolsFuture, tickersFuture]);
  }

  /// Switch the charted contract: update precision, reload history, resubscribe.
  void _switchSymbol(FuturesSymbol s) {
    if (s.symbol == _symbol.symbol) return;
    _binance.symbol = s.symbol;
    controller.setSymbol(SymbolInfo(
        ticker: s.symbol,
        pricePrecision: s.pricePrecision,
        volumePrecision: s.quantityPrecision));
    setState(() {
      _symbol = s;
      // Show the picker's snapshot price immediately; the ticker stream refines
      // it. Null until we have data for the new contract.
      _liveTicker = _symbolsState.value.tickers[s.symbol];
    });
    _load(_periods[_periodIndex].$2);
  }

  /// Returning to the foreground: reopen the live socket immediately, then
  /// backfill missed closed bars without letting REST block realtime recovery.
  Future<void> _onAppResume() async {
    if (widget.historyLoader != null || !widget.subscribeLive) return;
    _binance.forceReconnect();
    try {
      await _backfillRecent().timeout(const Duration(seconds: 6));
    } catch (_) {
      // The still-running REST request may finish later; generation guards keep
      // it from touching a newly selected symbol/timeframe.
    }
  }

  /// Close the gap from being backgrounded by merging REST bars by timestamp.
  /// The current forming bar is preserved because the reconnected trade stream
  /// may already be newer than a delayed REST response.
  Future<void> _backfillRecent() async {
    final gen = _loadGen; // bail if a symbol/timeframe switch happens meanwhile
    final before = controller.getDataList();
    final beforeLastTs = before.isEmpty ? null : before.last.timestamp;
    final liveAtStart = _lastBarUpdate;
    try {
      final recent =
          await _binance.fetchHistory(_periods[_periodIndex].$2, limit: 500);
      if (!mounted || gen != _loadGen || recent.isEmpty) return;
      final current = controller.getDataList();
      final currentLastTs = current.isEmpty ? null : current.last.timestamp;
      final hasNewLiveBar = _lastBarUpdate.isAfter(liveAtStart) ||
          (_pendingLiveBar != null &&
              _pendingLiveBar!.timestamp == currentLastTs);
      var windowMissedGap = false;
      if (beforeLastTs != null && recent.length > 1) {
        final spacing = recent[1].timestamp - recent[0].timestamp;
        windowMissedGap =
            spacing > 0 && recent.first.timestamp - beforeLastTs > spacing;
      }
      final byTimestamp = <int, KLineData>{};
      if (!windowMissedGap) {
        for (final bar in current) {
          byTimestamp[bar.timestamp] = bar;
        }
      }
      for (final bar in recent) {
        final live = bar.timestamp == currentLastTs && hasNewLiveBar
            ? current.last
            : null;
        byTimestamp[bar.timestamp] =
            live == null ? bar : _overlayLivePrice(bar, live);
      }
      if (windowMissedGap) {
        // The 500-bar window cannot bridge a long background gap. Drop the old
        // disconnected prefix, but retain any reconnected live tail.
        for (final bar in current) {
          if (bar.timestamp > recent.last.timestamp) {
            byTimestamp[bar.timestamp] = bar;
          }
        }
      }
      final merged = byTimestamp.values.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      controller.applyNewData(merged);
      final focusedTs = _focused?.timestamp;
      if (focusedTs != null) {
        for (final bar in merged) {
          if (bar.timestamp == focusedTs) {
            setState(() => _focused = bar);
            break;
          }
        }
      }
      _markBarLive();
    } catch (_) {
      // Network still down on resume; the socket's own retry will recover.
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    final now = DateTime.now();
    _lastBarUpdate = now; // grace window before the first precision poll
    _lastBarSyncUpdate = now;
    _lastMarketUpdate = now;
    _lastSelectedTickerUpdate = now;
    _lastSelectedTickerAttempt = now;
    if (_lastListPriceUpdate.millisecondsSinceEpoch == 0) {
      _lastListPriceUpdate = now;
    }
    if (_lastFullTickerUpdate.millisecondsSinceEpoch == 0) {
      _lastFullTickerUpdate = now;
    }
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _heartbeat());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _markBarLive({bool precise = true}) {
    final now = DateTime.now();
    _lastBarUpdate = now;
    _lastMarketUpdate = now;
    if (precise) _lastBarSyncUpdate = now;
  }

  void _markMarketLive() => _lastMarketUpdate = DateTime.now();

  /// Merge ticker updates into the list snapshot and, when present, the header.
  /// Assigning a new map/record is important: the picker listens to this notifier
  /// and cannot observe in-place mutations of the old map.
  void _mergeTickers(Map<String, Ticker> updates) {
    if (!mounted || updates.isEmpty) return;
    final state = _symbolsState.value;
    final merged = <String, Ticker>{...state.tickers, ...updates};
    _symbolsState.value = (
      list: state.list,
      tickers: merged,
      loading: state.loading,
      error: state.error,
    );
    final selected = updates[_symbol.symbol];
    if (selected != null && selected != _liveTicker) {
      setState(() => _liveTicker = selected);
    }
  }

  /// Lightweight all-symbol prices arrive more often than full 24h statistics;
  /// preserve each row's last known change percentage while replacing its price.
  void _mergePrices(Map<String, double> prices) {
    if (prices.isEmpty) return;
    final current = _symbolsState.value.tickers;
    final updates = <String, Ticker>{};
    for (final entry in prices.entries) {
      updates[entry.key] = (
        last: entry.value,
        changePct: current[entry.key]?.changePct,
      );
    }
    _mergeTickers(updates);
  }

  KLineData _overlayLivePrice(KLineData baseline, KLineData live) => KLineData(
        timestamp: baseline.timestamp,
        open: baseline.open,
        high: max(baseline.high, live.high),
        low: min(baseline.low, live.low),
        close: live.close,
        // The REST/kline baseline has authoritative cumulative volume. Adding a
        // partial trade buffer would double-count trades already in the snapshot.
        volume: baseline.volume,
        turnover: baseline.turnover,
      );

  /// Keep each realtime surface fresh independently. The current candle and
  /// selected 24h ticker use cheap per-symbol requests; the list uses the light
  /// all-price endpoint; the much larger all-symbol 24h snapshot is infrequent.
  Future<void> _heartbeat() async {
    if (!mounted || widget.historyLoader != null) return;
    final now = DateTime.now();
    final period = _periods[_periodIndex].$2;
    final hasNativeKline = BinanceSource.intervalOf(period) != null;
    final barPollAfter = hasNativeKline
        ? const Duration(milliseconds: 800)
        : const Duration(seconds: 30);
    final futures = <Future<void>>[];

    if (now.difference(_lastBarSyncUpdate) > barPollAfter &&
        _barPollingGen != _loadGen) {
      final pollGen = _loadGen;
      final symbol = _symbol.symbol;
      _barPollingGen = pollGen;
      futures.add(_pollLatestBars(pollGen, symbol, period).whenComplete(() {
        if (_barPollingGen == pollGen) _barPollingGen = null;
      }));
    }
    if (now.difference(_lastSelectedTickerAttempt) >
            const Duration(seconds: 2) &&
        _selectedTickerPollingGen != _loadGen) {
      final pollGen = _loadGen;
      final symbol = _symbol.symbol;
      _selectedTickerPollingGen = pollGen;
      _lastSelectedTickerAttempt = now;
      futures.add(_pollSelectedTicker(pollGen, symbol).whenComplete(() {
        if (_selectedTickerPollingGen == pollGen) {
          _selectedTickerPollingGen = null;
        }
      }));
    }
    if (now.difference(_lastListPriceUpdate) > const Duration(seconds: 2) &&
        !_pricePolling) {
      _pricePolling = true;
      _lastListPriceUpdate = now; // bound retries even when the request fails
      futures
          .add(_refreshListPrices().whenComplete(() => _pricePolling = false));
    }
    if (now.difference(_lastFullTickerUpdate) > const Duration(minutes: 1) &&
        !_tickerPolling) {
      _tickerPolling = true;
      _lastFullTickerUpdate =
          now; // full 24h snapshot has a high request weight
      futures.add(
          _refreshFullTickers().whenComplete(() => _tickerPolling = false));
    }
    if (futures.isNotEmpty) await Future.wait(futures);

    final staleSince = hasNativeKline ? _lastBarUpdate : _lastMarketUpdate;
    final barStale = DateTime.now().difference(staleSince) >
        (hasNativeKline
            ? const Duration(seconds: 6)
            : const Duration(seconds: 35));
    final tickerStale = DateTime.now().difference(_lastSelectedTickerUpdate) >
        const Duration(seconds: 10);
    final stale = barStale || tickerStale;
    if (stale != _dataStale && mounted) {
      setState(() => _dataStale = stale);
    }
  }

  Future<void> _pollLatestBars(int gen, String symbol, Period period) async {
    final tradeSequenceAtStart = _tradeSequence;
    final barUpdateAtStart = _lastBarUpdate;
    List<KLineData> recent;
    try {
      recent = await _binance.fetchHistory(period, limit: 2);
    } catch (_) {
      return;
    }
    if (!mounted ||
        gen != _loadGen ||
        symbol != _symbol.symbol ||
        recent.isEmpty) {
      return;
    }

    // Use REST as the cumulative OHLCV baseline, then overlay price action that
    // arrived while the request was in flight so the forming bar never jumps
    // backwards on a slow response.
    final current = controller.getDataList();
    final hasNewLiveData = _tradeSequence != tradeSequenceAtStart ||
        _lastBarUpdate.isAfter(barUpdateAtStart);
    final newerLive = hasNewLiveData
        ? (_pendingLiveBar ?? (current.isEmpty ? null : current.last))
        : null;
    _pendingLiveBar = null;
    for (final bar in recent) {
      controller.updateData(newerLive?.timestamp == bar.timestamp
          ? _overlayLivePrice(bar, newerLive!)
          : bar);
    }
    if (newerLive != null && newerLive.timestamp > recent.last.timestamp) {
      controller.updateData(newerLive);
    }
    _markBarLive();
    final latestData = controller.getDataList();
    final effectiveLast = latestData.isEmpty ? recent.last : latestData.last;
    final previous = _liveTicker;
    _mergeTickers(<String, Ticker>{
      symbol: (
        last: effectiveLast.close,
        changePct: previous?.changePct,
      ),
    });

    // The floating OHLC card caches a focused data object. Replace that object
    // when its timestamp was just upserted so the card follows the live candle.
    final focusedTs = _focused?.timestamp;
    if (focusedTs != null) {
      KLineData? refreshed;
      for (final bar in latestData) {
        if (bar.timestamp == focusedTs) refreshed = bar;
      }
      if (refreshed != null && mounted) {
        setState(() => _focused = refreshed);
      }
    }
  }

  Future<void> _pollSelectedTicker(int gen, String symbol) async {
    Ticker ticker;
    try {
      ticker = await BinanceSource.fetchTicker(symbol);
    } catch (_) {
      return;
    }
    if (!mounted || gen != _loadGen || symbol != _symbol.symbol) return;
    _lastSelectedTickerUpdate = DateTime.now();
    _markMarketLive();
    _mergeTickers(<String, Ticker>{symbol: ticker});
  }

  Future<void> _refreshListPrices() async {
    try {
      final prices = await BinanceSource.fetchPrices();
      if (!mounted || prices.isEmpty) return;
      _mergePrices(prices);
      final now = DateTime.now();
      _lastListPriceUpdate = now;
      _lastMarketUpdate = now;
    } catch (_) {
      // The next heartbeat retries; existing list values remain visible.
    }
  }

  Future<void> _refreshFullTickers() async {
    try {
      final tickers = await BinanceSource.fetchTickers();
      if (!mounted || tickers.isEmpty) return;
      _mergeTickers(tickers);
      final now = DateTime.now();
      _lastListPriceUpdate = now;
      _lastFullTickerUpdate = now;
      _lastMarketUpdate = now;
      if (tickers.containsKey(_symbol.symbol)) {
        _lastSelectedTickerUpdate = now;
      }
    } catch (_) {
      // The next minute-level refresh retries without clearing live prices.
    }
  }

  /// Open the searchable contract picker (切换/搜索币种).
  void _openSymbolPicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17171C),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => _SymbolPicker(
        state: _symbolsState,
        selected: _symbol.symbol,
        // Restore the last-closed 板块 + scroll position.
        initialSector: _pickerSector,
        initialScroll: _pickerScroll,
        onSelected: (s) {
          Navigator.of(ctx).pop();
          _switchSymbol(s);
        },
        // Remember where the user left the picker for next time.
        onClose: (sector, scroll) {
          _pickerSector = sector;
          _pickerScroll = scroll;
        },
        // No retry affordance offline / in tests (no network path).
        onRetry: widget.historyLoader == null ? _loadSymbols : null,
      ),
    );
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
    final gen = _loadGen;
    final period = _periods[_periodIndex].$2;
    final oldestTs = data.first.timestamp;
    try {
      final older = await _binance.fetchHistory(period,
          endTime: oldestTs - 1, limit: 500);
      if (gen != _loadGen) return; // contract/timeframe switched mid-fetch
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

  bool get _shouldSubscribeLive =>
      widget.subscribeLive &&
      (widget.historyLoader == null || widget.marketSource != null);

  int _tradeBucketFromAnchor(int anchor, int timestamp, Period period) {
    if (timestamp <= anchor) return anchor;
    int? intervalMs;
    switch (period.type) {
      case 'second':
        intervalMs = Duration(seconds: period.span).inMilliseconds;
        break;
      case 'minute':
        intervalMs = Duration(minutes: period.span).inMilliseconds;
        break;
      case 'hour':
        intervalMs = Duration(hours: period.span).inMilliseconds;
        break;
      case 'day':
        intervalMs = Duration(days: period.span).inMilliseconds;
        break;
      case 'week':
        intervalMs = Duration(days: 7 * period.span).inMilliseconds;
        break;
      case 'month':
        final start = DateTime.fromMillisecondsSinceEpoch(anchor, isUtc: true);
        final at = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
        final monthDelta = (at.year - start.year) * 12 + at.month - start.month;
        final steps = (monthDelta ~/ period.span) * period.span;
        return DateTime.utc(start.year, start.month + steps, start.day,
                start.hour, start.minute, start.second, start.millisecond)
            .millisecondsSinceEpoch;
      case 'year':
        final start = DateTime.fromMillisecondsSinceEpoch(anchor, isUtc: true);
        final at = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
        final steps = ((at.year - start.year) ~/ period.span) * period.span;
        return DateTime.utc(start.year + steps, start.month, start.day,
                start.hour, start.minute, start.second, start.millisecond)
            .millisecondsSinceEpoch;
    }
    if (intervalMs == null || intervalMs <= 0) return timestamp;
    return anchor + ((timestamp - anchor) ~/ intervalMs) * intervalMs;
  }

  void _queueLiveTrade(
      int gen, String subscribedSymbol, Period period, TradeTick trade) {
    if (!mounted || gen != _loadGen || _symbol.symbol != subscribedSymbol) {
      return;
    }
    _tradeSequence++;
    _markMarketLive();
    final data = controller.getDataList();
    final base = _pendingLiveBar ?? (data.isEmpty ? null : data.last);
    if (base == null) {
      _pendingLiveBar = KLineData(
        timestamp: tradeBucketStart(trade.timestamp, period),
        open: trade.price,
        high: trade.price,
        low: trade.price,
        close: trade.price,
        volume: trade.quantity,
        turnover: trade.price * trade.quantity,
      );
    } else {
      final bucket =
          _tradeBucketFromAnchor(base.timestamp, trade.timestamp, period);
      _pendingLiveBar = bucket == base.timestamp
          ? KLineData(
              timestamp: base.timestamp,
              open: base.open,
              high: max(base.high, trade.price),
              low: min(base.low, trade.price),
              close: trade.price,
              volume: (base.volume ?? 0) + trade.quantity,
              turnover: (base.turnover ?? 0) + trade.price * trade.quantity,
            )
          : KLineData(
              timestamp: bucket,
              open: trade.price,
              high: trade.price,
              low: trade.price,
              close: trade.price,
              volume: trade.quantity,
              turnover: trade.price * trade.quantity,
            );
    }
    if (_tradeFlushTimer?.isActive ?? false) return;
    _tradeFlushTimer = Timer(const Duration(milliseconds: 250), () {
      _tradeFlushTimer = null;
      final bar = _pendingLiveBar;
      _pendingLiveBar = null;
      if (!mounted ||
          bar == null ||
          gen != _loadGen ||
          _symbol.symbol != subscribedSymbol) {
        return;
      }
      controller.updateData(bar);
      _markBarLive(precise: false);
      final previous = _liveTicker;
      final next = (
        last: bar.close,
        changePct: previous?.changePct,
      );
      final symbolState = _symbolsState.value;
      _symbolsState.value = (
        list: symbolState.list,
        tickers: <String, Ticker>{
          ...symbolState.tickers,
          subscribedSymbol: next,
        },
        loading: symbolState.loading,
        error: symbolState.error,
      );
      final refreshFocus = _focused?.timestamp == bar.timestamp;
      if (next != previous || refreshFocus) {
        setState(() {
          _liveTicker = next;
          if (refreshFocus) _focused = bar;
        });
      }
    });
  }

  /// Start live callbacks after either real or fallback history has been
  /// installed. This deliberately does not depend on the history request having
  /// succeeded: REST/CORS failure must not permanently disable live prices.
  void _startLive(int gen, Period period) {
    if (!_shouldSubscribeLive || gen != _loadGen) return;
    final subscribedSymbol = _symbol.symbol;
    _liveTicker = _symbolsState.value.tickers[subscribedSymbol] ?? _liveTicker;
    _binance.subscribe(
      period,
      (bar) {
        if (!mounted || gen != _loadGen || _symbol.symbol != subscribedSymbol) {
          return;
        }
        final currentData = controller.getDataList();
        final currentLastTs =
            currentData.isEmpty ? null : currentData.last.timestamp;
        final pending = _pendingLiveBar;
        final pendingIsNewer =
            pending != null && pending.timestamp > bar.timestamp;
        final canAffectLive = !pendingIsNewer &&
            (currentLastTs == null || bar.timestamp >= currentLastTs);
        if (canAffectLive) _pendingLiveBar = null;
        controller.updateData(bar);
        if (!canAffectLive) return;
        _markBarLive();
        final previous = _liveTicker;
        final next = (
          last: bar.close,
          changePct: previous?.changePct,
        );
        final refreshFocus = _focused?.timestamp == bar.timestamp;
        if (next != previous || refreshFocus) {
          setState(() {
            _liveTicker = next;
            if (refreshFocus) _focused = bar;
          });
        }
      },
      onTrade: (trade) => _queueLiveTrade(gen, subscribedSymbol, period, trade),
      onTickers: (tickers) {
        if (!mounted || gen != _loadGen || _symbol.symbol != subscribedSymbol) {
          return;
        }
        final now = DateTime.now();
        _lastListPriceUpdate = now;
        _lastMarketUpdate = now;
        if (tickers.containsKey(subscribedSymbol)) {
          _lastSelectedTickerUpdate = now;
        }
        _mergeTickers(tickers);
      },
      onPrices: (prices) {
        if (!mounted || gen != _loadGen || _symbol.symbol != subscribedSymbol) {
          return;
        }
        final now = DateTime.now();
        _lastListPriceUpdate = now;
        _lastMarketUpdate = now;
        _mergePrices(prices);
      },
    );
    _startHeartbeat();
  }

  /// Load history for [period] from Binance, then subscribe to live updates.
  /// Falls back to synthetic data if Binance is unreachable.
  Future<void> _load(Period period) async {
    final gen = ++_loadGen;
    _stopHeartbeat(); // a fresh load restarts it when it re-subscribes
    _tradeFlushTimer?.cancel();
    _tradeFlushTimer = null;
    _pendingLiveBar = null;
    _dataStale = false;
    _noMoreHistory = false;
    _loadingMore = false;
    setState(() {
      _loading = true;
      _error = null;
      _focused = null;
      _focusLocal = null;
    });
    _binance.unsubscribe();
    controller
      ..setPeriod(period)
      ..applyNewData(const <KLineData>[]);
    controller.clearMarkers();
    // Open the production stream immediately. History can take up to two REST
    // host timeouts; live trade buffering must not wait behind that request.
    _startLive(gen, period);
    final loader = widget.historyLoader;
    late List<KLineData> data;
    String? loadError;
    try {
      data = loader != null
          ? await loader(period)
          : await _binance
              .fetchHistory(period, limit: 1000)
              .timeout(const Duration(seconds: 8));
    } catch (e) {
      // Offline / geo-blocked: show synthetic data so the demo still works.
      data = generateData(period);
      loadError = 'Binance unavailable — showing demo data';
    }
    if (!mounted || gen != _loadGen) return; // superseded by a newer switch
    final liveData = controller.getDataList();
    final pendingBar = _pendingLiveBar;
    _tradeFlushTimer?.cancel();
    _tradeFlushTimer = null;
    _pendingLiveBar = null;
    final byTimestamp = <int, KLineData>{
      for (final bar in data) bar.timestamp: bar,
    };
    void mergeLiveBar(KLineData bar) {
      final baseline = byTimestamp[bar.timestamp];
      byTimestamp[bar.timestamp] =
          baseline == null ? bar : _overlayLivePrice(baseline, bar);
    }

    for (final bar in liveData) {
      mergeLiveBar(bar);
    }
    if (pendingBar != null) mergeLiveBar(pendingBar);
    final merged = byTimestamp.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    controller
      ..setPeriod(period)
      ..applyNewData(merged);
    _placeDemoMarkers(merged);
    setState(() {
      _loading = false;
      _error = loadError;
    });
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
    _stopHeartbeat();
    _tradeFlushTimer?.cancel();
    _lifecycle?.dispose();
    _binance.dispose();
    _symbolsState.dispose();
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
            _symbolBar(),
            _topBar(),
            Expanded(child: _buildChart()),
          ],
        ),
      ),
    );
  }

  /// Symbol header: the current contract (tap to switch) + a search affordance.
  /// Both open the searchable contract picker (切换/搜索币种).
  Widget _symbolBar() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openSymbolPicker,
      child: Container(
        height: 46,
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Row(
          children: [
            // Contract name always shown in full — no ellipsis, and it keeps its
            // natural width so the price can never cover or squeeze it.
            Text(
              _symbol.display,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            _typeTag(_symbol.isTradFi),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.white54, size: 22),
            // Live price + 24h 涨跌幅, right-aligned in the remaining space; it
            // scales down (never the symbol) if the row gets tight.
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _headerPrice(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _wsIndicator(),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.search, color: Colors.white54, size: 22),
              tooltip: '搜索币种',
              onPressed: _openSymbolPicker,
            ),
          ],
        ),
      ),
    );
  }

  /// Live last price + 24h 涨跌幅 for the selected contract, coloured by
  /// direction (green up / red down / grey flat). Stacked (price over change)
  /// and right-aligned so it stays compact. Empty until a price is known.
  Widget _headerPrice() {
    final t = _liveTicker;
    if (t == null) return const SizedBox.shrink();
    final chg = t.changePct;
    final color = chg == null || chg == 0
        ? const Color(0xFF76808F)
        : (chg > 0 ? const Color(0xFF2DC08E) : const Color(0xFFF92855));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _fmtPrice(t.last, _symbol.pricePrecision),
          style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1.15),
        ),
        Text(
          chg == null
              ? '--'
              : '${chg > 0 ? '+' : ''}${chg.toStringAsFixed(2)}%',
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.15),
        ),
      ],
    );
  }

  /// Shown only when data has actually stopped flowing — i.e. neither the
  /// websocket nor the REST heartbeat has produced an update recently. While
  /// data is current (from either source) nothing is shown.
  Widget _wsIndicator() {
    if (!_dataStale) return const SizedBox.shrink();
    return const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.cloud_off_outlined, color: Color(0xFFF5A623), size: 15),
      SizedBox(width: 4),
      Text('行情延迟', style: TextStyle(color: Color(0xFFF5A623), fontSize: 12)),
      SizedBox(width: 8),
    ]);
  }

  /// Top bar: timeframe tabs + a few (decorative) tool icons, like the header
  /// of a Gate-style chart.
  Widget _topBar() {
    Widget icon(IconData i) => IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(i, color: Colors.white54, size: 20),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                duration: Duration(milliseconds: 700), content: Text('demo')),
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
      'VOL',
      'KDJ',
      'MA',
      'EMA',
      'BOLL',
      'SAR',
      '撑压线',
      '超级趋势'
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
              if (_loading) const Center(child: CircularProgressIndicator()),
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
    final bodyColor =
        (d.close >= d.open) ? const Color(0xFF2DC08E) : const Color(0xFFF92855);
    Widget row(String k, String v, [Color? c]) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  width: 52,
                  child: Text(k,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12))),
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
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
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

/// A searchable, sector-filterable list of Binance futures contracts, shown as
/// a bottom sheet. Pick a 板块 chip (全部 / TradFi / DeFi / …) and/or type in the
/// search box to filter by ticker or coin; tap a row to select the contract.
class _SymbolPicker extends StatefulWidget {
  const _SymbolPicker({
    required this.state,
    required this.selected,
    required this.onSelected,
    this.initialSector,
    this.initialScroll = 0,
    this.onClose,
    this.onRetry,
  });

  /// Live contract-list state (updates while the sheet is open).
  final ValueListenable<_SymbolState> state;
  final String selected;
  final ValueChanged<FuturesSymbol> onSelected;

  /// 板块 + scroll offset to restore (the position the picker was last closed at).
  final String? initialSector;
  final double initialScroll;

  /// Reports the 板块 + scroll offset when the picker closes, to remember it.
  final void Function(String? sector, double scroll)? onClose;

  /// Re-fetch the contract list; `null` disables the retry affordance.
  final Future<void> Function()? onRetry;

  @override
  State<_SymbolPicker> createState() => _SymbolPickerState();
}

class _SymbolPickerState extends State<_SymbolPicker> {
  final TextEditingController _query = TextEditingController();
  late final ScrollController _scroll;

  // Selected 板块 (sector); null = 全部 (all).
  String? _sector;
  // Latest scroll offset, tracked so it can be reported back on close.
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    _sector = widget.initialSector;
    _offset = widget.initialScroll;
    _scroll = ScrollController(initialScrollOffset: widget.initialScroll)
      ..addListener(() {
        if (_scroll.hasClients) _offset = _scroll.offset;
      });
  }

  @override
  void dispose() {
    // Hand the last-viewed 板块 + scroll position back so reopening restores it.
    widget.onClose?.call(_sector, _offset);
    _scroll.dispose();
    _query.dispose();
    super.dispose();
  }

  void _selectSector(String? sec) {
    if (sec == _sector) return;
    setState(() => _sector = sec);
    // A new sector is a new list — start it at the top.
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _offset = 0;
  }

  /// The 板块 chips to show: 全部 first, then TradFi (prominent), then the
  /// crypto sectors present in [all], most-populated first.
  List<String?> _sectorsOf(List<FuturesSymbol> all) {
    final counts = <String, int>{};
    for (final s in all) {
      counts[s.sector] = (counts[s.sector] ?? 0) + 1;
    }
    final others = counts.keys.where((k) => k != 'TradFi').toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return <String?>[
      null, // 全部
      if (counts.containsKey('TradFi')) 'TradFi',
      ...others,
    ];
  }

  List<FuturesSymbol> _filter(List<FuturesSymbol> all) {
    Iterable<FuturesSymbol> r = all;
    if (_sector != null) r = r.where((s) => s.sector == _sector);
    final q = _query.text.trim().toUpperCase();
    if (q.isNotEmpty) {
      r = r.where((s) =>
          s.symbol.toUpperCase().contains(q) ||
          s.baseAsset.toUpperCase().contains(q));
    }
    return r.toList();
  }

  /// Horizontal, scrollable row of 板块 (sector) filter chips.
  Widget _sectorChips(List<String?> sectors) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: sectors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sec = sectors[i];
          final selected = sec == _sector;
          final accent = sec == 'TradFi'
              ? const Color(0xFFF5A623)
              : const Color(0xFF2DC08E);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _selectSector(sec),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.18)
                    : const Color(0xFF23232A),
                borderRadius: BorderRadius.circular(15),
                border: selected
                    ? Border.all(color: accent.withValues(alpha: 0.6))
                    : null,
              ),
              child: Text(
                sec ?? '全部',
                style: TextStyle(
                  color: selected ? accent : Colors.white60,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// A thin status line above the list: loading spinner, error+retry, or count.
  Widget _statusRow(_SymbolState st, int shown) {
    const pad = EdgeInsets.fromLTRB(16, 2, 8, 6);
    if (st.loading) {
      return const Padding(
        padding: pad,
        child: Row(children: [
          SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white38)),
          SizedBox(width: 8),
          Text('正在加载全部合约…',
              style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]),
      );
    }
    if (st.error != null) {
      return Padding(
        padding: pad,
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFF5A623), size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(st.error!,
                style: const TextStyle(color: Color(0xFFF5A623), fontSize: 12)),
          ),
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
              style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: const Text('重试', style: TextStyle(fontSize: 12)),
            ),
        ]),
      );
    }
    return Padding(
      padding: pad,
      child: Row(children: [
        Text('共 $shown 个合约',
            style: const TextStyle(color: Colors.white38, fontSize: 12)),
        const Spacer(),
        if (widget.onRetry != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh, color: Colors.white38, size: 18),
            tooltip: '刷新',
            onPressed: widget.onRetry,
          ),
      ]),
    );
  }

  /// Right-aligned last price + 24h 涨跌幅 for a row; `null` when no data yet
  /// (offline, or the ticker snapshot hasn't loaded).
  Widget? _priceCell(Ticker? t, int precision) {
    if (t == null) return null;
    final chg = t.changePct;
    final color = chg == null || chg == 0
        ? const Color(0xFF76808F)
        : (chg > 0 ? const Color(0xFF2DC08E) : const Color(0xFFF92855));
    final chgText =
        chg == null ? '--' : '${chg > 0 ? '+' : ''}${chg.toStringAsFixed(2)}%';
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(_fmtPrice(t.last, precision),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(chgText,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    // Cap the sheet so its content + the keyboard never exceeds the screen.
    // Otherwise the bottom-anchored sheet grows past the top edge and pushes
    // the search field up under the status bar. Above the keyboard we keep the
    // full 78% height; while it's open we shrink to the space that remains.
    final sheetHeight = min(
      mq.size.height * 0.78,
      mq.size.height - mq.padding.top - keyboard,
    );
    return Padding(
      // Lift the sheet above the on-screen keyboard.
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: TextField(
                controller: _query,
                autofocus: false,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索币种 (BTC, ETH…)',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.white38, size: 20),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.white38, size: 18),
                          onPressed: () => setState(_query.clear),
                        ),
                  filled: true,
                  fillColor: const Color(0xFF23232A),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<_SymbolState>(
                valueListenable: widget.state,
                builder: (context, st, _) {
                  final results = _filter(st.list);
                  return Column(
                    children: [
                      _sectorChips(_sectorsOf(st.list)),
                      _statusRow(st, results.length),
                      Expanded(
                        child: results.isEmpty
                            ? const Center(
                                child: Text('无匹配币种',
                                    style: TextStyle(color: Colors.white38)))
                            : ListView.builder(
                                controller: _scroll,
                                itemCount: results.length,
                                itemBuilder: (context, i) {
                                  final s = results[i];
                                  final selected = s.symbol == widget.selected;
                                  return ListTile(
                                    dense: true,
                                    selected: selected,
                                    selectedTileColor: const Color(0x142DC08E),
                                    onTap: () => widget.onSelected(s),
                                    title: Row(
                                      children: [
                                        Flexible(
                                          child: Text(s.display,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: selected
                                                    ? const Color(0xFF2DC08E)
                                                    : Colors.white,
                                                fontSize: 15,
                                                fontWeight: selected
                                                    ? FontWeight.bold
                                                    : FontWeight.w500,
                                              )),
                                        ),
                                        const SizedBox(width: 8),
                                        _typeTag(s.isTradFi, fontSize: 11),
                                      ],
                                    ),
                                    trailing: _priceCell(
                                        st.tickers[s.symbol], s.pricePrecision),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
