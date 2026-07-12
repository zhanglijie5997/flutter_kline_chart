// A minimal Binance USDT-M futures (合约) market-data source for the
// kline_chart example: the list of all perpetual contracts, REST history, and
// live WebSocket kline updates.
//
// Uses the public `fapi.binance.com` / `fstream.binance.com` endpoints, which
// serve futures market data without an API key.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:kline_chart/kline_chart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// One tradable Binance USDT-margined futures contract — either a crypto
/// perpetual or a TradFi perpetual (stocks / ETFs / metals, contractType
/// `TRADIFI_PERPETUAL`).
class FuturesSymbol {
  final String symbol; // e.g. 'BTCUSDT'
  final String baseAsset; // e.g. 'BTC' (or 'TSLA', 'XAU')
  final String quoteAsset; // e.g. 'USDT'
  final int pricePrecision;
  final int quantityPrecision;

  /// Binance sector tag / 板块 (e.g. 'TradFi', 'DeFi', 'Layer-1', 'Meme',
  /// 'AI', 'RWA', …), or 'Other' when Binance provides no tag.
  final String sector;

  /// True for `TRADIFI_PERPETUAL` contracts (tokenized stocks/ETFs/metals).
  final bool isTradFi;

  const FuturesSymbol({
    required this.symbol,
    required this.baseAsset,
    required this.quoteAsset,
    this.pricePrecision = 2,
    this.quantityPrecision = 3,
    this.sector = 'Other',
    this.isTradFi = false,
  });

  /// Human-readable pair, e.g. `BTC/USDT`.
  String get display => '$baseAsset/$quoteAsset';

  factory FuturesSymbol.fromJson(Map<String, dynamic> j) {
    final tradFi = j['contractType'] == 'TRADIFI_PERPETUAL';
    final subs =
        (j['underlyingSubType'] as List<dynamic>?) ?? const <dynamic>[];
    // TradFi contracts are always the TradFi 板块; otherwise use the first
    // Binance sub-type tag (Pre-IPO items list ['Pre-IPO','TradFi']).
    final sector =
        tradFi ? 'TradFi' : (subs.isNotEmpty ? subs.first.toString() : 'Other');
    return FuturesSymbol(
      symbol: j['symbol'] as String,
      baseAsset: j['baseAsset'] as String? ?? '',
      quoteAsset: j['quoteAsset'] as String? ?? '',
      pricePrecision: (j['pricePrecision'] as num?)?.toInt() ?? 2,
      quantityPrecision: (j['quantityPrecision'] as num?)?.toInt() ?? 3,
      sector: sector,
      isTradFi: tradFi,
    );
  }
}

/// 24h market snapshot for one contract: last price + 24h change percent.
typedef Ticker = ({double last, double? changePct});

/// One production futures trade used to keep the forming candle moving when a
/// websocket edge acknowledges `@kline` but does not deliver kline frames.
typedef TradeTick = ({double price, double quantity, int timestamp});

/// Live websocket connection state, reported to the UI.
/// - [connected]: handshake is up (frames may be sparse for a quiet market).
/// - [reconnecting]: actively retrying after a drop (show a spinner).
/// - [offline]: retries keep failing; retrying quietly without a spinner.
enum WsStatus { connected, reconnecting, offline }

class BinanceSource {
  // Futures REST hosts, tried in order. When `fapi.binance.com` is region- or
  // network-blocked, `www.binance.com` often still reaches the same futures
  // API, so we fail over instead of dropping to the tiny built-in list.
  static const List<String> _fapiHosts = <String>[
    'https://fapi.binance.com',
    'https://www.binance.com',
  ];
  // Keep the websocket on the production futures host. In particular,
  // `fstream.binancefuture.com` is demo/testnet data and must never be mixed
  // with the production REST history returned by `fapi.binance.com`.
  static const String _wsBase = 'wss://fstream.binance.com/ws';

  // The host that last answered 200 — tried first next time.
  static String _preferredHost = _fapiHosts.first;

  String symbol; // e.g. 'BTCUSDT'; mutable so the chart can switch contracts
  BinanceSource({this.symbol = 'BTCUSDT'});

  /// GET [path] (e.g. `/fapi/v1/klines?...`) from the first reachable futures
  /// host, cascading over [_fapiHosts] and remembering the winner. Throws only
  /// if every host fails.
  static Future<http.Response> _getFapi(String path) async {
    final ordered = <String>[
      _preferredHost,
      ..._fapiHosts.where((h) => h != _preferredHost),
    ];
    Object? lastError;
    for (final host in ordered) {
      try {
        final resp = await http
            .get(Uri.parse('$host$path'))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode == 200) {
          _preferredHost = host;
          return resp;
        }
        lastError = 'HTTP ${resp.statusCode} from $host';
      } catch (e) {
        lastError = e;
      }
    }
    throw Exception('All Binance futures hosts unreachable ($lastError)');
  }

  /// Popular contracts used as a last-resort list when every host in
  /// [_fapiHosts] is unreachable (fully offline / all Binance domains blocked).
  /// The live [fetchSymbols] result (all ~500 contracts) replaces this.
  static final List<FuturesSymbol> fallbackSymbols = <FuturesSymbol>[
    // Crypto perpetuals.
    _fb('BTC'), _fb('ETH'), _fb('BNB'), _fb('SOL'), _fb('XRP', 4),
    _fb('DOGE', 5), _fb('ADA', 4), _fb('AVAX', 3), _fb('LINK', 3),
    _fb('DOT', 3), _fb('TRX', 5), _fb('LTC'), _fb('BCH'), _fb('NEAR', 4),
    _fb('UNI', 3), _fb('APT', 4), _fb('FIL', 3), _fb('ARB', 4), _fb('OP', 4),
    _fb('INJ', 3), _fb('SUI', 4), _fb('TIA', 4), _fb('SEI', 4), _fb('PEPE', 8),
    _fb('WIF', 4), _fb('SHIB', 8), _fb('TON', 4), _fb('ATOM', 3), _fb('ETC', 3),
    _fb('XLM', 5), _fb('AAVE'), _fb('ORDI', 3), _fb('RUNE', 4), _fb('FTM', 4),
    // TradFi perpetuals (stocks / ETFs / metals).
    _fbT('XAU', 2), _fbT('XAG', 4), _fbT('TSLA'), _fbT('NVDA'), _fbT('AAPL'),
    _fbT('MSFT'), _fbT('GOOGL'), _fbT('AMZN'), _fbT('META'), _fbT('COIN'),
    _fbT('MSTR'), _fbT('QQQ'), _fbT('SPY'),
  ];

  /// Terse builder for a crypto `<base>USDT` fallback contract.
  static FuturesSymbol _fb(String base, [int pricePrecision = 2]) =>
      FuturesSymbol(
        symbol: '${base}USDT',
        baseAsset: base,
        quoteAsset: 'USDT',
        pricePrecision: pricePrecision,
      );

  /// Terse builder for a TradFi `<base>USDT` fallback contract.
  static FuturesSymbol _fbT(String base, [int pricePrecision = 5]) =>
      FuturesSymbol(
        symbol: '${base}USDT',
        baseAsset: base,
        quoteAsset: 'USDT',
        pricePrecision: pricePrecision,
        sector: 'TradFi',
        isTradFi: true,
      );

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

  /// Fetch every tradable USDT-margined perpetual contract, popular ones first
  /// then alphabetical. Throws if Binance is unreachable.
  static Future<List<FuturesSymbol>> fetchSymbols() async {
    final resp = await _getFapi('/fapi/v1/exchangeInfo');
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final symbols = (json['symbols'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((s) =>
            s['status'] == 'TRADING' &&
            (s['contractType'] == 'PERPETUAL' ||
                s['contractType'] == 'TRADIFI_PERPETUAL') &&
            s['quoteAsset'] == 'USDT')
        .map(FuturesSymbol.fromJson)
        .toList()
      ..sort((a, b) {
        final pa = _popular.indexOf(a.symbol);
        final pb = _popular.indexOf(b.symbol);
        if (pa != pb) {
          // Both popular: keep _popular order. One popular: it wins.
          if (pa == -1) return 1;
          if (pb == -1) return -1;
          return pa.compareTo(pb);
        }
        return a.symbol.compareTo(b.symbol);
      });
    return symbols;
  }

  /// Fetch the 24h price + change% for every contract in one request
  /// (`/fapi/v1/ticker/24hr` with no symbol), keyed by ticker symbol.
  static Future<Map<String, Ticker>> fetchTickers() async {
    final resp = await _getFapi('/fapi/v1/ticker/24hr');
    final list = jsonDecode(resp.body) as List<dynamic>;
    final out = <String, Ticker>{};
    for (final e in list) {
      final m = e as Map<String, dynamic>;
      final sym = m['symbol'] as String?;
      if (sym == null) continue;
      out[sym] =
          (last: _d(m['lastPrice']), changePct: _d(m['priceChangePercent']));
    }
    return out;
  }

  /// Fetch one contract's exact last price + 24h change. This endpoint has a
  /// much lower request weight than refreshing every contract's 24h statistics.
  static Future<Ticker> fetchTicker(String symbol) async {
    final resp = await _getFapi('/fapi/v1/ticker/24hr?symbol=$symbol');
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (
      last: _d(data['lastPrice']),
      changePct: _d(data['priceChangePercent']),
    );
  }

  /// Fetch lightweight last prices for all contracts. The all-symbol price
  /// endpoint is small/low-weight compared with `/ticker/24hr`, making it safe
  /// to use as a short-interval fallback for the visible contract list.
  static Future<Map<String, double>> fetchPrices() async {
    final resp = await _getFapi('/fapi/v1/ticker/price');
    final list = jsonDecode(resp.body) as List<dynamic>;
    final out = <String, double>{};
    for (final event in list) {
      final data = event as Map<String, dynamic>;
      final symbol = data['symbol'] as String?;
      if (symbol != null) out[symbol] = _d(data['price']);
    }
    return out;
  }

  // ---- live websocket (auto-reconnecting) ----------------------------------

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnectTimer;
  Timer? _staleTimer;
  Timer? _priceBatchTimer;
  final Random _rand = Random();
  final Map<String, double> _pendingPrices = <String, double>{};

  bool _wantLive = false; // true between subscribe() and unsubscribe()
  int _attempt = 0; // consecutive failed connects (drives backoff)
  String? _streamName; // primary path stream, e.g. 'btcusdt@trade'
  List<String> _additionalStreams = const <String>[];
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
  /// (frozen after backgrounding / network change / sleep) and reconnected. A
  /// BTC trade heartbeat is added when the selected market itself is quiet.
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

  /// Binance interval string for a [Period], or `null` if Binance has no such
  /// interval (it has no yearly interval — we aggregate monthly bars instead).
  static String? intervalOf(Period period) {
    switch (period.type) {
      case 'second':
        return '${period.span}s';
      case 'minute':
        return '${period.span}m';
      case 'hour':
        return '${period.span}h';
      case 'day':
        return '${period.span}d';
      case 'week':
        return '${period.span}w';
      case 'month':
        return '${period.span}M';
      default:
        return null; // 'year'
    }
  }

  static double _d(Object? v) => double.tryParse('$v') ?? 0;

  /// Parse one Binance REST kline array
  /// `[openTime, open, high, low, close, volume, closeTime, quoteVolume, ...]`.
  static KLineData klineFromRestArray(List<dynamic> a) => KLineData(
        timestamp: (a[0] as num).toInt(),
        open: _d(a[1]),
        high: _d(a[2]),
        low: _d(a[3]),
        close: _d(a[4]),
        volume: _d(a[5]),
        turnover: _d(a[7]),
      );

  /// Fetch up to [limit] historical bars for [period]. Pass [endTime] (ms) to
  /// fetch the bars ending before that timestamp (for pagination to the left).
  Future<List<KLineData>> fetchHistory(Period period,
      {int limit = 1000, int? endTime}) async {
    final interval = intervalOf(period);
    if (interval == null) {
      // No yearly interval on Binance -> aggregate monthly bars into years.
      final monthly = await _fetch('1M', 1000, endTime: endTime);
      return _aggregateYearly(monthly, period.span);
    }
    return _fetch(interval, limit, endTime: endTime);
  }

  Future<List<KLineData>> _fetch(String interval, int limit,
      {int? endTime}) async {
    final query = 'symbol=$symbol&interval=$interval&limit=$limit'
        '${endTime != null ? '&endTime=$endTime' : ''}';
    final resp = await _getFapi('/fapi/v1/klines?$query');
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => klineFromRestArray(e as List<dynamic>)).toList();
  }

  List<KLineData> _aggregateYearly(List<KLineData> monthly, int spanYears) {
    final span = spanYears <= 0 ? 1 : spanYears;
    final byBucket = <int, List<KLineData>>{};
    for (final k in monthly) {
      // Binance monthly bars open at UTC midnight on the 1st; bucket by UTC
      // year so a January bar never folds into the prior year west of UTC.
      final year =
          DateTime.fromMillisecondsSinceEpoch(k.timestamp, isUtc: true).year;
      final bucket = (year ~/ span) * span;
      byBucket.putIfAbsent(bucket, () => <KLineData>[]).add(k);
    }
    final buckets = byBucket.keys.toList()..sort();
    return buckets.map((y) {
      final bars = byBucket[y]!
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      var high = bars.first.high;
      var low = bars.first.low;
      var vol = 0.0;
      for (final b in bars) {
        if (b.high > high) high = b.high;
        if (b.low < low) low = b.low;
        vol += b.volume ?? 0;
      }
      return KLineData(
        timestamp: DateTime.utc(y).millisecondsSinceEpoch,
        open: bars.first.open,
        high: high,
        low: low,
        close: bars.last.close,
        volume: vol,
      );
    }).toList();
  }

  /// Parse a raw Binance `@kline` websocket payload string into a [KLineData].
  static KLineData? parseKlineEvent(String message) {
    try {
      final json = jsonDecode(message);
      if (json is Map<String, dynamic>) return _klineFromMap(json);
    } catch (_) {}
    return null;
  }

  static KLineData? _klineFromMap(Map<String, dynamic> json) {
    final k = json['k'];
    if (k is Map) {
      return KLineData(
        timestamp: (k['t'] as num).toInt(),
        open: _d(k['o']),
        high: _d(k['h']),
        low: _d(k['l']),
        close: _d(k['c']),
        volume: _d(k['v']),
        turnover: _d(k['q']),
      );
    }
    return null;
  }

  /// Parse a `24hrTicker` payload into a [Ticker] (last price + 24h change%).
  static Ticker? _tickerFromMap(Map<String, dynamic> d) {
    if (d['c'] == null) return null;
    return (last: _d(d['c']), changePct: _d(d['P']));
  }

  /// Parse a raw, combined-stream, or `!ticker@arr` payload into ticker updates
  /// keyed by symbol. The all-market stream is incremental, so callers should
  /// merge the returned entries into their existing snapshot.
  static Map<String, Ticker> parseTickerEvents(String message) {
    try {
      return _tickersFromPayload(jsonDecode(message));
    } catch (_) {
      return const <String, Ticker>{};
    }
  }

  static Map<String, Ticker> _tickersFromPayload(dynamic payload) {
    // Combined streams wrap either a single event or an event array in `data`.
    if (payload is Map<String, dynamic> && payload.containsKey('data')) {
      payload = payload['data'];
    }
    final events = payload is List<dynamic>
        ? payload
        : payload is Map
            ? <dynamic>[payload]
            : const <dynamic>[];
    final out = <String, Ticker>{};
    for (final event in events) {
      if (event is! Map) continue;
      final data = Map<String, dynamic>.from(event);
      if (data['e'] != '24hrTicker') continue;
      final symbol = data['s'] as String?;
      final ticker = _tickerFromMap(data);
      if (symbol != null && ticker != null) out[symbol] = ticker;
    }
    return out;
  }

  /// Subscribe to live updates for [period] over one production websocket.
  /// `@trade` drives [onPrice] immediately and doubles as a liveness heartbeat;
  /// `@kline` goes to [onBar] when Binance delivers it; `!ticker@arr` updates go
  /// to [onTickers], with the selected symbol also forwarded to [onTicker].
  /// Call [forceReconnect] when the app returns to the foreground.
  void subscribe(Period period, void Function(KLineData bar) onBar,
      {void Function(double price)? onPrice,
      void Function(TradeTick trade)? onTrade,
      void Function(Ticker t)? onTicker,
      void Function(Map<String, Ticker> tickers)? onTickers,
      void Function(Map<String, double> prices)? onPrices,
      void Function(WsStatus status)? onStatus}) {
    unsubscribe();
    final interval = intervalOf(period);
    _wantLive = true;
    _attempt = 0;
    _onBar = onBar;
    _onPrice = onPrice;
    _onTrade = onTrade;
    _onTicker = onTicker;
    _onTickers = onTickers;
    _onPrices = onPrices;
    _onStatus = onStatus;
    final s = symbol.toLowerCase();
    // The production `@trade` stream is used as the primary path because some
    // edges currently ack `@kline`/`@ticker` subscriptions but emit no frames.
    // REST polling in the UI periodically corrects full OHLCV and 24h stats.
    _streamName = '$s@trade';
    _additionalStreams = <String>[
      if (interval != null) '$s@kline_$interval',
      '!ticker@arr',
      '!bookTicker',
      // A closed/quiet selected market should not look like a dead socket.
      if (s != 'btcusdt') 'btcusdt@trade',
    ];
    _startStaleWatchdog();
    _connect();
  }

  void _setStatus(WsStatus s) {
    if (_status == s) return;
    _status = s;
    _onStatus?.call(s);
  }

  /// Open (or re-open) the websocket for the current [_streamName].
  void _connect() {
    if (!_wantLive) return;
    final stream = _streamName;
    if (stream == null) return;
    _closeChannel();
    _lastMessageAt =
        DateTime.now(); // give the fresh socket a full grace window
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(Uri.parse('$_wsBase/$stream'));
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
      if (_additionalStreams.isNotEmpty) {
        try {
          channel.sink.add(jsonEncode(
              {'method': 'SUBSCRIBE', 'params': _additionalStreams, 'id': 1}));
        } catch (_) {}
      }
    }).catchError((Object _) {
      if (!_wantLive || !identical(_channel, channel)) return;
      _scheduleReconnect();
    });
  }

  void _handleFrame(dynamic event) {
    if (event is! String) return;
    dynamic payload;
    try {
      final decoded = jsonDecode(event);
      payload = decoded is Map<String, dynamic> && decoded.containsKey('data')
          ? decoded['data']
          : decoded;
    } catch (_) {
      return;
    }
    var gotMarketFrame = false;
    if (payload is Map<String, dynamic> && payload['e'] == 'trade') {
      gotMarketFrame = true;
      if (payload['s'] == symbol && payload['p'] != null) {
        final price = _d(payload['p']);
        final eventTime = payload['T'] ?? payload['E'];
        _onPrice?.call(price);
        _onTrade?.call((
          price: price,
          quantity: _d(payload['q']),
          timestamp: eventTime is num
              ? eventTime.toInt()
              : DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
    if (payload is Map<String, dynamic> && payload['e'] == 'kline') {
      final bar = _klineFromMap(payload);
      if (bar != null) {
        gotMarketFrame = true;
        _onBar?.call(bar);
      }
    }
    if (payload is Map<String, dynamic> && payload['e'] == 'bookTicker') {
      gotMarketFrame = true;
      final bookSymbol = payload['s'] as String?;
      final bid = _d(payload['b']);
      final ask = _d(payload['a']);
      if (bookSymbol != null && (bid > 0 || ask > 0)) {
        _pendingPrices[bookSymbol] =
            bid > 0 && ask > 0 ? (bid + ask) / 2 : (bid > 0 ? bid : ask);
        _priceBatchTimer ??= Timer(const Duration(milliseconds: 500), () {
          _priceBatchTimer = null;
          if (!_wantLive || _pendingPrices.isEmpty) return;
          final batch = Map<String, double>.from(_pendingPrices);
          _pendingPrices.clear();
          _onPrices?.call(batch);
        });
      }
    }
    final tickers = _tickersFromPayload(payload);
    if (tickers.isNotEmpty) {
      gotMarketFrame = true;
      _onTickers?.call(tickers);
      final selected = tickers[symbol];
      if (selected != null) _onTicker?.call(selected);
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
      if (_reconnectTimer?.isActive ?? false)
        return; // reconnect already queued
      if (DateTime.now().difference(_lastMessageAt) > _staleAfter) {
        _scheduleReconnect();
      }
    });
  }

  /// Force an immediate reconnect (e.g. when the app returns to the foreground,
  /// where a backgrounded socket is often silently dead). No-op if not live.
  void forceReconnect() {
    if (!_wantLive) return;
    _reconnectTimer?.cancel();
    _attempt = 0;
    _connect();
  }

  void _closeChannel() {
    _priceBatchTimer?.cancel();
    _priceBatchTimer = null;
    _pendingPrices.clear();
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void unsubscribe() {
    _wantLive = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    _priceBatchTimer?.cancel();
    _priceBatchTimer = null;
    _pendingPrices.clear();
    _onBar = null;
    _onPrice = null;
    _onTrade = null;
    _onTicker = null;
    _onTickers = null;
    _onPrices = null;
    _onStatus = null;
    _streamName = null;
    _additionalStreams = const <String>[];
    _status = WsStatus.connected; // re-arm for the next subscription
    _closeChannel();
  }

  void dispose() => unsubscribe();
}
