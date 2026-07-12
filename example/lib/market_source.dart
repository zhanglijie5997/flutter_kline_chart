// An exchange-agnostic market-data interface so the chart can switch between
// Binance / OKX / Gate at runtime. It mirrors the API the chart already used
// from [BinanceSource]; each concrete source maps the canonical `BASEUSDT`
// symbol the UI uses to its own native contract format internally, and reports
// symbols/tickers back in that same canonical form so the picker keeps working.

import 'package:kline_chart/kline_chart.dart';

import 'binance.dart';

/// Abstraction over one exchange's USDT-perpetual market-data feed.
abstract class MarketSource {
  /// Active contract in canonical `BASEUSDT` form (e.g. `BTCUSDT`); mutable so
  /// the chart can switch contracts without recreating the source.
  String get symbol;
  set symbol(String value);

  /// Last-resort contract list when the catalog endpoint is unreachable.
  List<FuturesSymbol> get fallbackSymbols;

  /// This exchange's interval string for [period], or null if it has no such
  /// interval (the chart then aggregates a finer one).
  String? intervalOf(Period period);

  /// REST history: up to [limit] bars for [period], ending before [endTime]
  /// (ms) when paginating to the left. Ascending by time.
  Future<List<KLineData>> fetchHistory(Period period,
      {int limit = 1000, int? endTime});

  /// Full tradable USDT-perpetual list (popular first), in canonical form.
  Future<List<FuturesSymbol>> fetchSymbols();

  /// 24h last price + change% for every contract, keyed by canonical symbol.
  Future<Map<String, Ticker>> fetchTickers();

  /// Lightweight last prices for all contracts, keyed by canonical symbol.
  Future<Map<String, double>> fetchPrices();

  /// One contract's last price + 24h change.
  Future<Ticker> fetchTicker(String symbol);

  /// Subscribe to live updates for [period]. Callbacks mirror [BinanceSource]:
  /// [onBar] for klines, [onTrade]/[onPrice] for trades, [onTicker]/[onTickers]
  /// for 24h stats, [onPrices] for lightweight prices, [onStatus] for link
  /// state. All symbols reported are canonical.
  void subscribe(
    Period period,
    void Function(KLineData bar) onBar, {
    void Function(double price)? onPrice,
    void Function(TradeTick trade)? onTrade,
    void Function(Ticker t)? onTicker,
    void Function(Map<String, Ticker> tickers)? onTickers,
    void Function(Map<String, double> prices)? onPrices,
    void Function(WsStatus status)? onStatus,
  });

  void unsubscribe();
  void forceReconnect();
  void dispose();
}

/// Splits a canonical `BASEUSDT` symbol into `(base, quote)`. Only USDT-quoted
/// contracts are used, so this simply strips a trailing `USDT`.
({String base, String quote}) splitCanonical(String canonical) {
  if (canonical.endsWith('USDT')) {
    return (base: canonical.substring(0, canonical.length - 4), quote: 'USDT');
  }
  return (base: canonical, quote: '');
}

/// Adapts the existing [BinanceSource] (statics + instance) to [MarketSource].
/// Keeps `binance.dart` and its tests untouched.
class BinanceMarketSource implements MarketSource {
  BinanceMarketSource([BinanceSource? inner])
      : _b = inner ?? BinanceSource(symbol: 'BTCUSDT');

  final BinanceSource _b;

  @override
  String get symbol => _b.symbol;
  @override
  set symbol(String value) => _b.symbol = value;

  @override
  List<FuturesSymbol> get fallbackSymbols => BinanceSource.fallbackSymbols;

  @override
  String? intervalOf(Period period) => BinanceSource.intervalOf(period);

  @override
  Future<List<KLineData>> fetchHistory(Period period,
          {int limit = 1000, int? endTime}) =>
      _b.fetchHistory(period, limit: limit, endTime: endTime);

  @override
  Future<List<FuturesSymbol>> fetchSymbols() => BinanceSource.fetchSymbols();

  @override
  Future<Map<String, Ticker>> fetchTickers() => BinanceSource.fetchTickers();

  @override
  Future<Map<String, double>> fetchPrices() => BinanceSource.fetchPrices();

  @override
  Future<Ticker> fetchTicker(String symbol) => BinanceSource.fetchTicker(symbol);

  @override
  void subscribe(
    Period period,
    void Function(KLineData bar) onBar, {
    void Function(double price)? onPrice,
    void Function(TradeTick trade)? onTrade,
    void Function(Ticker t)? onTicker,
    void Function(Map<String, Ticker> tickers)? onTickers,
    void Function(Map<String, double> prices)? onPrices,
    void Function(WsStatus status)? onStatus,
  }) =>
      _b.subscribe(period, onBar,
          onPrice: onPrice,
          onTrade: onTrade,
          onTicker: onTicker,
          onTickers: onTickers,
          onPrices: onPrices,
          onStatus: onStatus);

  @override
  void unsubscribe() => _b.unsubscribe();
  @override
  void forceReconnect() => _b.forceReconnect();
  @override
  void dispose() => _b.dispose();
}
