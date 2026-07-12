// An OKX USDT-settled perpetual (SWAP) market-data source for the kline_chart
// example: the list of all USDT-margined perpetual contracts, REST history, and
// live WebSocket kline / trade / ticker updates.
//
// Uses the public OKX v5 API (`www.okx.com` REST + `ws.okx.com` public
// websocket), which serves market data without an API key.
//
// The UI works in canonical `BASEUSDT` symbols (e.g. `BTCUSDT`); OKX identifies
// a USDT perpetual by its instId `BASE-USDT-SWAP` (e.g. `BTC-USDT-SWAP`). This
// source maps canonical -> instId for every request and maps instId -> canonical
// for everything it reports back, so the picker and chart keep working.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kline_chart/kline_chart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'binance.dart' show BinanceSource, FuturesSymbol, Ticker, TradeTick, WsStatus;
import 'market_source.dart';

/// OKX v5 public market-data source, exposed through the shared [MarketSource]
/// interface. Mirrors [BinanceSource]'s auto-reconnecting websocket, stale
/// watchdog, and exponential backoff so a dropped socket recovers on its own.
class OkxSource implements MarketSource {
  static const String _restBase = 'https://www.okx.com';
  static const String _wsBase = 'wss://ws.okx.com:8443/ws/v5/public';

  static const String _swapSuffix = '-USDT-SWAP';

  @override
  String symbol; // canonical 'BTCUSDT'; mutable so the chart can switch contracts
  OkxSource({this.symbol = 'BTCUSDT'});

  // -- symbol mapping ---------------------------------------------------------

  /// Canonical `BASEUSDT` -> OKX instId `BASE-USDT-SWAP`.
  static String instIdOf(String canonical) {
    final parts = splitCanonical(canonical);
    final base = parts.base.isEmpty ? canonical : parts.base;
    return '$base$_swapSuffix';
  }

  /// OKX instId `BASE-USDT-SWAP` -> canonical `BASEUSDT`, or null when the
  /// instId is not a USDT-settled swap.
  static String? canonicalOf(String instId) {
    if (!instId.endsWith(_swapSuffix)) return null;
    final base = instId.substring(0, instId.length - _swapSuffix.length);
    if (base.isEmpty) return null;
    return '${base}USDT';
  }

  String get _instId => instIdOf(symbol);

  // -- fallback / popular -----------------------------------------------------

  /// Reuse Binance's canonical popular-first list when the OKX catalog endpoint
  /// is unreachable (fully offline / OKX blocked).
  @override
  List<FuturesSymbol> get fallbackSymbols => BinanceSource.fallbackSymbols;

  // Popular contracts to float to the top of the picker (in this order).
  static const List<String> _popular = <String>[
    'BTCUSDT',
    'ETHUSDT',
    'BNBUSDT',
    'SOLUSDT',
    'XRPUSDT',
    'DOGEUSDT',
    'ADAUSDT',
  ];

  static double _d(Object? v) => double.tryParse('$v') ?? 0;

  // -- REST -------------------------------------------------------------------

  static Future<http.Response> _get(String path) => http
      .get(Uri.parse('$_restBase$path'))
      .timeout(const Duration(seconds: 15));

  /// OKX `bar` string for a [Period] (shared by REST + WS channel), or `null`
  /// when OKX has no such interval (no per-second or per-year bar — the caller
  /// aggregates a finer one).
  @override
  String? intervalOf(Period period) {
    switch (period.type) {
      case 'minute':
        return '${period.span}m';
      case 'hour':
        return '${period.span}H';
      case 'day':
        return '${period.span}D';
      case 'week':
        return '1W';
      case 'month':
        return '${period.span}M';
      default:
        return null; // 'second' / 'year'
    }
  }

  /// Parse one OKX candle array
  /// `[ts, o, h, l, c, vol, volCcy, volCcyQuote, confirm]` (ts is ms as a
  /// string). Returns null for a partial/garbled bar with any non-positive OHLC
  /// so the chart never auto-scales to 0.
  static KLineData? klineFromArray(List<dynamic> a) {
    if (a.length < 5) return null;
    final open = _d(a[1]);
    final high = _d(a[2]);
    final low = _d(a[3]);
    final close = _d(a[4]);
    if (open <= 0 || high <= 0 || low <= 0 || close <= 0) return null;
    return KLineData(
      timestamp: int.tryParse('${a[0]}') ?? _d(a[0]).toInt(),
      open: open,
      high: high,
      low: low,
      close: close,
      volume: a.length > 5 ? _d(a[5]) : 0,
      // volCcyQuote (USDT turnover) is index 7; fall back to volCcy (index 6).
      turnover: a.length > 7
          ? _d(a[7])
          : (a.length > 6 ? _d(a[6]) : 0),
    );
  }

  /// Parse an OKX candles REST body (`{"code":"0","data":[[...], ...]}`) into
  /// bars ASCENDING by timestamp. OKX returns newest-first, so the parsed list
  /// is reversed. Bars with non-positive OHLC are dropped.
  static List<KLineData> parseKlines(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return const <KLineData>[];
    final data = json['data'];
    if (data is! List) return const <KLineData>[];
    final out = <KLineData>[];
    for (final e in data) {
      if (e is List) {
        final k = klineFromArray(e);
        if (k != null) out.add(k);
      }
    }
    out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out;
  }

  /// Fetch up to [limit] historical bars for [period], ascending by time. Pass
  /// [endTime] (ms) to fetch the bars strictly older than that timestamp (for
  /// pagination to the left) — this uses OKX's history-candles endpoint with
  /// `after`.
  @override
  Future<List<KLineData>> fetchHistory(Period period,
      {int limit = 1000, int? endTime}) async {
    final bar = intervalOf(period);
    if (bar == null) return const <KLineData>[]; // caller aggregates finer bars
    // OKX caps candle requests at 100 (recent) / 100 (history) per call.
    final capped = limit < 1 ? 1 : (limit > 100 ? 100 : limit);
    final instId = _instId;
    final path = endTime != null
        ? '/api/v5/market/history-candles?instId=$instId&bar=$bar'
            '&after=$endTime&limit=$capped'
        : '/api/v5/market/candles?instId=$instId&bar=$bar&limit=$capped';
    final resp = await _get(path);
    if (resp.statusCode != 200) return const <KLineData>[];
    return parseKlines(resp.body);
  }

  /// Fetch every tradable USDT-settled perpetual, popular ones first then
  /// alphabetical. Falls back to [fallbackSymbols] on any error.
  @override
  Future<List<FuturesSymbol>> fetchSymbols() async {
    try {
      final resp = await _get('/api/v5/market/tickers?instType=SWAP');
      if (resp.statusCode != 200) return fallbackSymbols;
      final json = jsonDecode(resp.body);
      if (json is! Map<String, dynamic>) return fallbackSymbols;
      final data = json['data'];
      if (data is! List) return fallbackSymbols;
      final symbols = <FuturesSymbol>[];
      final seen = <String>{};
      for (final e in data) {
        if (e is! Map) continue;
        final instId = e['instId'] as String?;
        if (instId == null) continue;
        final canonical = canonicalOf(instId);
        if (canonical == null || !seen.add(canonical)) continue;
        final parts = splitCanonical(canonical);
        symbols.add(FuturesSymbol(
          symbol: canonical,
          baseAsset: parts.base,
          quoteAsset: 'USDT',
        ));
      }
      if (symbols.isEmpty) return fallbackSymbols;
      symbols.sort((a, b) {
        final pa = _popular.indexOf(a.symbol);
        final pb = _popular.indexOf(b.symbol);
        if (pa != pb) {
          if (pa == -1) return 1;
          if (pb == -1) return -1;
          return pa.compareTo(pb);
        }
        return a.symbol.compareTo(b.symbol);
      });
      return symbols;
    } catch (_) {
      return fallbackSymbols;
    }
  }

  /// Parse an OKX tickers REST body (`{"data":[{"instId","last","open24h"},...]}`)
  /// into [Ticker]s keyed by canonical `BASEUSDT`. Only `-USDT-SWAP` instruments
  /// are kept.
  static Map<String, Ticker> parseTickers(String body) {
    final out = <String, Ticker>{};
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) return out;
    final data = json['data'];
    if (data is! List) return out;
    for (final e in data) {
      if (e is! Map) continue;
      final instId = e['instId'] as String?;
      if (instId == null) continue;
      final canonical = canonicalOf(instId);
      if (canonical == null) continue;
      final t = _tickerFromMap(Map<String, dynamic>.from(e));
      if (t != null) out[canonical] = t;
    }
    return out;
  }

  /// Build a [Ticker] from one OKX ticker object. `changePct` is derived from
  /// `last` vs `open24h`. Returns null when `last` is missing/unparseable.
  static Ticker? _tickerFromMap(Map<String, dynamic> m) {
    if (m['last'] == null) return null;
    final last = _d(m['last']);
    final open24h = _d(m['open24h']);
    final changePct = open24h > 0 ? (last - open24h) / open24h * 100 : null;
    return (last: last, changePct: changePct);
  }

  /// 24h last price + change% for every USDT swap, keyed by canonical symbol.
  @override
  Future<Map<String, Ticker>> fetchTickers() async {
    final resp = await _get('/api/v5/market/tickers?instType=SWAP');
    if (resp.statusCode != 200) return const <String, Ticker>{};
    return parseTickers(resp.body);
  }

  /// Lightweight last prices for all USDT swaps, keyed by canonical symbol.
  @override
  Future<Map<String, double>> fetchPrices() async {
    final tickers = await fetchTickers();
    return tickers.map((k, v) => MapEntry(k, v.last));
  }

  /// One contract's last price + 24h change.
  @override
  Future<Ticker> fetchTicker(String symbol) async {
    final instId = instIdOf(symbol);
    final resp = await _get('/api/v5/market/ticker?instId=$instId');
    if (resp.statusCode != 200) return (last: 0.0, changePct: null);
    final json = jsonDecode(resp.body);
    if (json is Map<String, dynamic>) {
      final data = json['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        final t = _tickerFromMap(Map<String, dynamic>.from(data.first as Map));
        if (t != null) return t;
      }
    }
    return (last: 0.0, changePct: null);
  }

  // ---- live websocket (auto-reconnecting) ----------------------------------

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _staleTimer;
  Timer? _pingTimer;
  final Random _rand = Random();

  bool _wantLive = false; // true between subscribe() and unsubscribe()
  int _attempt = 0; // consecutive failed connects (drives backoff)
  String? _bar; // OKX candle bar for the subscribed period, e.g. '4H'
  String? _subInstId; // instId captured at subscribe time
  void Function(KLineData bar)? _onBar;
  void Function(double price)? _onPrice;
  void Function(TradeTick trade)? _onTrade;
  void Function(Ticker t)? _onTicker;
  void Function(Map<String, Ticker> tickers)? _onTickers;
  void Function(Map<String, double> prices)? _onPrices;
  void Function(WsStatus status)? _onStatus;
  WsStatus _status = WsStatus.connected; // last reported status
  DateTime _lastMessageAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _connectedAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// If no frame arrives for this long the socket is treated as half-open
  /// (frozen after backgrounding / network change / sleep) and reconnected.
  static const Duration _staleAfter = Duration(seconds: 30);
  static const Duration _maxBackoff = Duration(seconds: 30);
  static const Duration _connectTimeout = Duration(seconds: 8);
  // A connection must stay up this long before its backoff counter resets, so a
  // socket that opens then immediately freezes still escalates its backoff.
  static const Duration _stableAfter = Duration(seconds: 5);
  // After this many failed attempts, drop the spinner for a calm "offline" hint.
  static const int _offlineAfter = 4;

  /// Exponential reconnect backoff (no jitter): 0.5s, 1s, 2s, … capped at
  /// [_maxBackoff]. Pure + deterministic so it can be unit-tested.
  static Duration reconnectDelay(int attempt) {
    final a = attempt < 0 ? 0 : (attempt > 6 ? 6 : attempt);
    final ms = 500 * (1 << a); // 500, 1000, 2000, … 32000
    final capped =
        ms > _maxBackoff.inMilliseconds ? _maxBackoff.inMilliseconds : ms;
    return Duration(milliseconds: capped);
  }

  /// Subscribe to live updates for [period] over one OKX public websocket.
  /// `trades` drives [onPrice]/[onTrade] and doubles as a liveness heartbeat;
  /// `candle{BAR}` goes to [onBar]; `tickers` goes to [onTicker] + [onTickers]
  /// (keyed by the canonical symbol). Call [forceReconnect] on foreground.
  @override
  void subscribe(Period period, void Function(KLineData bar) onBar,
      {void Function(double price)? onPrice,
      void Function(TradeTick trade)? onTrade,
      void Function(Ticker t)? onTicker,
      void Function(Map<String, Ticker> tickers)? onTickers,
      void Function(Map<String, double> prices)? onPrices,
      void Function(WsStatus status)? onStatus}) {
    unsubscribe();
    _wantLive = true;
    _attempt = 0;
    _bar = intervalOf(period);
    _subInstId = _instId;
    _onBar = onBar;
    _onPrice = onPrice;
    _onTrade = onTrade;
    _onTicker = onTicker;
    _onTickers = onTickers;
    _onPrices = onPrices;
    _onStatus = onStatus;
    _startStaleWatchdog();
    _connect();
  }

  void _setStatus(WsStatus s) {
    if (_status == s) return;
    _status = s;
    _onStatus?.call(s);
  }

  /// The subscribe frame for the current instId + bar: candle (when the period
  /// maps to an OKX bar), trades, and tickers.
  String _subscribeFrame() {
    final instId = _subInstId ?? _instId;
    final args = <Map<String, String>>[
      if (_bar != null) {'channel': 'candle${_bar!}', 'instId': instId},
      {'channel': 'trades', 'instId': instId},
      {'channel': 'tickers', 'instId': instId},
    ];
    return jsonEncode({'op': 'subscribe', 'args': args});
  }

  /// Open (or re-open) the public websocket and (re)subscribe.
  void _connect() {
    if (!_wantLive) return;
    _closeChannel();
    _lastMessageAt =
        DateTime.now(); // give the fresh socket a full grace window
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse(_wsBase));
    } catch (_) {
      _scheduleReconnect();
      return;
    }
    _channel = channel;
    _sub = channel.stream.listen(
      (event) {
        if (identical(_channel, channel)) _handleFrame(event);
      },
      onError: (_) {
        if (identical(_channel, channel)) _scheduleReconnect();
      },
      onDone: () {
        if (identical(_channel, channel)) _scheduleReconnect();
      },
      cancelOnError: true,
    );
    // "Connected" = the handshake completed, NOT the first data frame — so a
    // quiet-but-healthy stream doesn't look stuck reconnecting, and a resume
    // reliably clears the hint even when no bar has arrived yet.
    channel.ready.timeout(_connectTimeout).then((_) {
      if (!_wantLive || !identical(_channel, channel)) return;
      _connectedAt = DateTime.now();
      _setStatus(WsStatus.connected);
      try {
        channel.sink.add(_subscribeFrame());
      } catch (_) {}
      _startPing();
    }).catchError((Object _) {
      if (!_wantLive || !identical(_channel, channel)) return;
      _scheduleReconnect();
    });
  }

  void _handleFrame(dynamic event) {
    if (event is! String) return;
    // OKX keep-alive: server replies 'pong' to our 'ping'. Treat it as liveness.
    if (event == 'pong') {
      _lastMessageAt = DateTime.now();
      return;
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(event);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    // Subscription acks / errors carry no market data.
    final arg = decoded['arg'];
    final data = decoded['data'];
    if (arg is! Map || data is! List) return;
    final channel = arg['channel'] as String?;
    if (channel == null) return;
    final instId = arg['instId'] as String?;
    final canonical = instId != null ? canonicalOf(instId) : null;

    var gotMarketFrame = false;

    if (channel.startsWith('candle')) {
      for (final row in data) {
        if (row is List) {
          final bar = klineFromArray(row);
          if (bar != null) {
            gotMarketFrame = true;
            _onBar?.call(bar);
          }
        }
      }
    } else if (channel == 'trades') {
      for (final e in data) {
        if (e is! Map) continue;
        final price = _d(e['px']);
        if (price <= 0) continue; // ignore garbage ticks (0 pins the bar's low)
        gotMarketFrame = true;
        final ts = e['ts'];
        final timestamp = int.tryParse('$ts') ??
            (ts is num ? ts.toInt() : DateTime.now().millisecondsSinceEpoch);
        _onPrice?.call(price);
        _onTrade?.call((
          price: price,
          quantity: _d(e['sz']),
          timestamp: timestamp,
        ));
      }
    } else if (channel == 'tickers') {
      final updates = <String, Ticker>{};
      for (final e in data) {
        if (e is! Map) continue;
        final tInstId = e['instId'] as String? ?? instId;
        final tCanonical =
            tInstId != null ? canonicalOf(tInstId) : canonical;
        if (tCanonical == null) continue;
        final t = _tickerFromMap(Map<String, dynamic>.from(e));
        if (t != null) updates[tCanonical] = t;
      }
      if (updates.isNotEmpty) {
        gotMarketFrame = true;
        _onTickers?.call(updates);
        final selected = updates[symbol];
        if (selected != null) _onTicker?.call(selected);
        _onPrices?.call(updates.map((k, v) => MapEntry(k, v.last)));
      }
    }

    if (gotMarketFrame) {
      _lastMessageAt = DateTime.now();
      // Only trust the link once it has held for a few seconds (so a socket that
      // opens then immediately freezes keeps escalating its backoff).
      if (_attempt != 0 &&
          DateTime.now().difference(_connectedAt) > _stableAfter) {
        _attempt = 0;
      }
    }
  }

  /// Tear down the current socket and reconnect after an exponential backoff.
  void _scheduleReconnect() {
    if (!_wantLive) return;
    if (_reconnectTimer?.isActive ?? false) return; // already pending
    _closeChannel();
    // Stop nagging after several failures: switch the spinner to a calm hint.
    _setStatus(
        _attempt >= _offlineAfter ? WsStatus.offline : WsStatus.reconnecting);
    final base = reconnectDelay(_attempt);
    _attempt++;
    // +jitter (up to 400ms) so many charts don't reconnect in lockstep.
    final delay = base + Duration(milliseconds: _rand.nextInt(400));
    _reconnectTimer = Timer(delay, _connect);
  }

  /// Periodically reconnect if no frame has arrived for [_staleAfter] — the
  /// only way to detect a half-open socket that never fires onError/onDone
  /// (common after backgrounding, sleep, or a network switch).
  void _startStaleWatchdog() {
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_wantLive) return;
      if (_reconnectTimer?.isActive ?? false) return; // reconnect already queued
      if (DateTime.now().difference(_lastMessageAt) > _staleAfter) {
        _scheduleReconnect();
      }
    });
  }

  /// OKX closes idle sockets: send the literal string 'ping' every ~20s; the
  /// server replies 'pong' (handled as liveness in [_handleFrame]).
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_wantLive) return;
      try {
        _channel?.sink.add('ping');
      } catch (_) {}
    });
  }

  /// Force an immediate reconnect (e.g. when the app returns to the foreground,
  /// where a backgrounded socket is often silently dead). No-op if not live.
  @override
  void forceReconnect() {
    if (!_wantLive) return;
    _reconnectTimer?.cancel();
    _attempt = 0;
    _connect();
  }

  void _closeChannel() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  @override
  void unsubscribe() {
    _wantLive = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _onBar = null;
    _onPrice = null;
    _onTrade = null;
    _onTicker = null;
    _onTickers = null;
    _onPrices = null;
    _onStatus = null;
    _bar = null;
    _subInstId = null;
    _status = WsStatus.connected; // re-arm for the next subscription
    _closeChannel();
  }

  @override
  void dispose() => unsubscribe();
}
