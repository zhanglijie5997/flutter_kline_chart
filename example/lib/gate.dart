// A Gate.io USDT-perpetual-futures (合约) market-data source for the
// kline_chart example: the tradable contract list, REST history, and live
// WebSocket kline / trade / ticker updates.
//
// Uses the public Gate.io v4 futures endpoints
// (`api.gateio.ws` REST / `fx-ws.gateio.ws` websocket), which serve futures
// market data without an API key.
//
// The UI works in canonical `BASEUSDT` symbols (e.g. `BTCUSDT`). Gate's native
// contract id is `BASE_USDT` (e.g. `BTC_USDT`); this source converts to that
// native form for every API call and maps results back to canonical before
// reporting them, so the shared picker/chart keep working unchanged.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kline_chart/kline_chart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'binance.dart'; // shared types (FuturesSymbol/Ticker/TradeTick/WsStatus) + fallbackSymbols
import 'market_source.dart'; // MarketSource + splitCanonical

class GateSource implements MarketSource {
  // Gate.io v4 REST base (public futures market data, no key required).
  static const String _restBase = 'https://api.gateio.ws/api/v4';
  // Gate.io USDT-settled futures websocket.
  static const String _wsBase = 'wss://fx-ws.gateio.ws/v4/ws/usdt';

  @override
  String symbol; // canonical, e.g. 'BTCUSDT'; mutable so the chart can switch
  GateSource({this.symbol = 'BTCUSDT'});

  // ---- symbol <-> native contract conversion --------------------------------

  /// Canonical `BTCUSDT` -> Gate native contract `BTC_USDT`.
  static String toContract(String canonical) {
    final parts = splitCanonical(canonical);
    if (parts.quote == 'USDT') return '${parts.base}_USDT';
    return canonical;
  }

  /// Gate native contract `BTC_USDT` -> canonical `BTCUSDT`.
  static String fromContract(String contract) {
    if (contract.endsWith('_USDT')) {
      return '${contract.substring(0, contract.length - '_USDT'.length)}USDT';
    }
    return contract.replaceAll('_', '');
  }

  String get _contract => toContract(symbol);

  // ---- HTTP -----------------------------------------------------------------

  static double _d(Object? v) => double.tryParse('$v') ?? 0;

  static Future<http.Response> _get(String path) async {
    final resp = await http
        .get(Uri.parse('$_restBase$path'),
            headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode} from Gate ($path)');
    }
    return resp;
  }

  // ---- fallback / catalog ---------------------------------------------------

  /// Reuse Binance's canonical popular-contract list when Gate's catalog
  /// endpoint is unreachable (fully offline). The live [fetchSymbols] result
  /// replaces this.
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

  /// Build one canonical [FuturesSymbol] from a Gate contract id like
  /// `BTC_USDT`, or null if it is not a USDT-settled contract.
  static FuturesSymbol? _symbolFromContract(String contract) {
    if (!contract.endsWith('_USDT')) return null;
    final base = contract.substring(0, contract.length - '_USDT'.length);
    if (base.isEmpty) return null;
    return FuturesSymbol(
      symbol: '${base}USDT',
      baseAsset: base,
      quoteAsset: 'USDT',
    );
  }

  /// Parse a Gate `/futures/usdt/tickers` payload into the canonical tradable
  /// contract list, popular first then alphabetical. Static + network-free so
  /// it is unit-testable.
  static List<FuturesSymbol> parseSymbols(String body) {
    final list = jsonDecode(body) as List<dynamic>;
    final seen = <String>{};
    final out = <FuturesSymbol>[];
    for (final e in list) {
      if (e is! Map) continue;
      final contract = e['contract'] as String?;
      if (contract == null) continue;
      final fs = _symbolFromContract(contract);
      if (fs == null || !seen.add(fs.symbol)) continue;
      out.add(fs);
    }
    out.sort((a, b) {
      final pa = _popular.indexOf(a.symbol);
      final pb = _popular.indexOf(b.symbol);
      if (pa != pb) {
        if (pa == -1) return 1;
        if (pb == -1) return -1;
        return pa.compareTo(pb);
      }
      return a.symbol.compareTo(b.symbol);
    });
    return out;
  }

  /// Fetch every tradable USDT-settled perpetual, popular first then
  /// alphabetical. Falls back to [fallbackSymbols] if Gate is unreachable.
  @override
  Future<List<FuturesSymbol>> fetchSymbols() async {
    try {
      final resp = await _get('/futures/usdt/tickers');
      final syms = parseSymbols(resp.body);
      return syms.isEmpty ? fallbackSymbols : syms;
    } catch (_) {
      return fallbackSymbols;
    }
  }

  // ---- tickers / prices -----------------------------------------------------

  /// Parse a Gate `/futures/usdt/tickers` payload into canonical-keyed tickers.
  /// Static + network-free so it is unit-testable.
  static Map<String, Ticker> parseTickers(String body) {
    final decoded = jsonDecode(body);
    return _tickersFromPayload(decoded);
  }

  /// Turn a Gate tickers payload (a list, a single object, or the `result` of a
  /// ws frame) into canonical-keyed [Ticker]s.
  static Map<String, Ticker> _tickersFromPayload(dynamic payload) {
    final events = payload is List<dynamic>
        ? payload
        : payload is Map
            ? <dynamic>[payload]
            : const <dynamic>[];
    final out = <String, Ticker>{};
    for (final e in events) {
      if (e is! Map) continue;
      final contract = e['contract'] as String?;
      if (contract == null) continue;
      final canonical = fromContract(contract);
      final changeRaw = e['change_percentage'];
      out[canonical] = (
        last: _d(e['last']),
        changePct: changeRaw == null ? null : _d(changeRaw),
      );
    }
    return out;
  }

  @override
  Future<Map<String, Ticker>> fetchTickers() async {
    final resp = await _get('/futures/usdt/tickers');
    return parseTickers(resp.body);
  }

  @override
  Future<Map<String, double>> fetchPrices() async {
    final tickers = await fetchTickers();
    return tickers.map((k, v) => MapEntry(k, v.last));
  }

  @override
  Future<Ticker> fetchTicker(String symbol) async {
    final contract = toContract(symbol);
    final resp = await _get('/futures/usdt/tickers?contract=$contract');
    final tickers = parseTickers(resp.body);
    return tickers[symbol] ??
        tickers[fromContract(contract)] ??
        (last: 0.0, changePct: null);
  }

  // ---- intervals ------------------------------------------------------------

  /// Gate interval string for a [Period], or `null` if Gate has no such
  /// interval (seconds and years have none; the chart aggregates a finer one).
  @override
  String? intervalOf(Period period) {
    switch (period.type) {
      case 'minute':
        return '${period.span}m';
      case 'hour':
        return '${period.span}h';
      case 'day':
        return period.span == 1 ? '1d' : null;
      case 'week':
        return '7d';
      case 'month':
        return '30d';
      default:
        return null; // 'second' / 'year'
    }
  }

  // ---- history --------------------------------------------------------------

  /// Parse one Gate candlestick object
  /// `{"t":<sec>,"v":<num>,"c":"..","h":"..","l":"..","o":"..","sum":".."}`.
  /// `t` is in SECONDS. Returns null for a non-positive OHLC bar (a partial /
  /// garbled frame) so it never spikes the chart's auto-scale to 0.
  static KLineData? klineFromMap(Map<String, dynamic> m) {
    final open = _d(m['o']);
    final high = _d(m['h']);
    final low = _d(m['l']);
    final close = _d(m['c']);
    if (open <= 0 || high <= 0 || low <= 0 || close <= 0) return null;
    final t = m['t'];
    final tsSec = t is num ? t.toInt() : int.tryParse('$t') ?? 0;
    return KLineData(
      timestamp: tsSec * 1000,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: _d(m['v']),
      turnover: _d(m['sum']),
    );
  }

  /// Parse a Gate REST candlesticks array into ascending [KLineData], dropping
  /// non-positive bars. Static + network-free so it is unit-testable.
  static List<KLineData> parseKlines(String body) {
    final list = jsonDecode(body) as List<dynamic>;
    final out = <KLineData>[];
    for (final e in list) {
      if (e is! Map) continue;
      final bar = klineFromMap(Map<String, dynamic>.from(e));
      if (bar != null) out.add(bar);
    }
    out.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return out;
  }

  /// Fetch up to [limit] historical bars for [period]. Pass [endTime] (ms) to
  /// fetch the bars ending at/before that timestamp (left-pagination). Result
  /// is ascending by time.
  @override
  Future<List<KLineData>> fetchHistory(Period period,
      {int limit = 1000, int? endTime}) async {
    final interval = intervalOf(period);
    if (interval == null) return const <KLineData>[];
    var query = 'contract=$_contract&interval=$interval&limit=$limit';
    if (endTime != null) query += '&to=${endTime ~/ 1000}';
    final resp = await _get('/futures/usdt/candlesticks?$query');
    return parseKlines(resp.body);
  }

  // ---- live websocket (auto-reconnecting) -----------------------------------

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _staleTimer;
  Timer? _pingTimer;
  final Random _rand = Random();

  bool _wantLive = false; // true between subscribe() and unsubscribe()
  int _attempt = 0; // consecutive failed connects (drives backoff)
  String? _interval; // current candlestick interval, e.g. '1m' or null
  String? _liveContract; // native contract subscribed to
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
    _interval = intervalOf(period);
    _liveContract = _contract;
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

  int get _nowSec => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// Send one Gate subscribe frame for [channel] with [payload].
  void _sendSub(WebSocketChannel channel, String ch, List<String> payload) {
    try {
      channel.sink.add(jsonEncode(<String, dynamic>{
        'time': _nowSec,
        'channel': ch,
        'event': 'subscribe',
        'payload': payload,
      }));
    } catch (_) {}
  }

  /// Open (or re-open) the websocket for the current contract/interval.
  void _connect() {
    if (!_wantLive) return;
    final contract = _liveContract;
    if (contract == null) return;
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
      final interval = _interval;
      if (interval != null) {
        _sendSub(channel, 'futures.candlesticks', <String>[interval, contract]);
      }
      _sendSub(channel, 'futures.trades', <String>[contract]);
      _sendSub(channel, 'futures.tickers', <String>[contract]);
      _startPing();
    }).catchError((Object _) {
      if (!_wantLive || !identical(_channel, channel)) return;
      _scheduleReconnect();
    });
  }

  void _handleFrame(dynamic event) {
    if (event is! String) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(event);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;
    // Pong / subscribe-ack frames are still evidence the link is alive.
    final channel = decoded['channel'] as String?;
    final event0 = decoded['event'] as String?;
    if (event0 != 'update') {
      // ack / pong / subscribe reply — count as liveness but no payload.
      _markLive();
      return;
    }
    final result = decoded['result'];
    var gotMarketFrame = false;
    switch (channel) {
      case 'futures.candlesticks':
        final bars = result is List ? result : const <dynamic>[];
        for (final e in bars) {
          if (e is! Map) continue;
          final bar = klineFromMap(Map<String, dynamic>.from(e));
          if (bar != null) {
            gotMarketFrame = true;
            _onBar?.call(bar);
          }
        }
        break;
      case 'futures.trades':
        final trades = result is List ? result : const <dynamic>[];
        for (final e in trades) {
          if (e is! Map) continue;
          final price = _d(e['price']);
          if (price <= 0) continue; // ignore garbage ticks
          gotMarketFrame = true;
          final ct = e['create_time'];
          final tsSec = ct is num
              ? ct.toInt()
              : int.tryParse('$ct') ?? _nowSec;
          _onPrice?.call(price);
          _onTrade?.call((
            price: price,
            quantity: _d(e['size']).abs(),
            timestamp: tsSec * 1000,
          ));
        }
        break;
      case 'futures.tickers':
        // Gate delivers tickers as either a single object or an array.
        final tickers = _tickersFromPayload(result);
        if (tickers.isNotEmpty) {
          gotMarketFrame = true;
          _onTickers?.call(tickers);
          _onPrices?.call(tickers.map((k, v) => MapEntry(k, v.last)));
          final selected = tickers[symbol];
          if (selected != null) _onTicker?.call(selected);
        }
        break;
      default:
        break;
    }
    if (gotMarketFrame) _markLive();
  }

  /// Note a live frame and, once the socket has held for a few seconds, reset
  /// the backoff counter.
  void _markLive() {
    _lastMessageAt = DateTime.now();
    if (_attempt != 0 &&
        DateTime.now().difference(_connectedAt) > _stableAfter) {
      _attempt = 0;
    }
  }

  /// Gate closes idle sockets; keep it warm with a `futures.ping` every ~20s.
  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_wantLive) return;
      final channel = _channel;
      if (channel == null) return;
      try {
        channel.sink.add(jsonEncode(<String, dynamic>{
          'time': _nowSec,
          'channel': 'futures.ping',
        }));
      } catch (_) {}
    });
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
    _interval = null;
    _liveContract = null;
    _status = WsStatus.connected; // re-arm for the next subscription
    _closeChannel();
  }

  @override
  void dispose() => unsubscribe();
}
