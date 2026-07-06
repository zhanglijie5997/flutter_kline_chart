// A minimal Binance market-data source for the kline_chart example:
// REST history + live WebSocket kline updates for BTC/USDT.
//
// Uses the public `*.binance.vision` data endpoints, which serve market data
// without an API key and are not geo-restricted like `api.binance.com`.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kline_chart/kline_chart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class BinanceSource {
  static const String _restBase =
      'https://data-api.binance.vision/api/v3/klines';
  static const String _wsBase = 'wss://data-stream.binance.vision/ws';

  final String symbol; // e.g. 'BTCUSDT'
  BinanceSource({this.symbol = 'BTCUSDT'});

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

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
    final uri = Uri.parse('$_restBase?$query');
    final resp = await http.get(uri).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw Exception('Binance HTTP ${resp.statusCode}: ${resp.body}');
    }
    final list = jsonDecode(resp.body) as List<dynamic>;
    return list.map((e) => klineFromRestArray(e as List<dynamic>)).toList();
  }

  List<KLineData> _aggregateYearly(List<KLineData> monthly, int spanYears) {
    final span = spanYears <= 0 ? 1 : spanYears;
    final byBucket = <int, List<KLineData>>{};
    for (final k in monthly) {
      final year = DateTime.fromMillisecondsSinceEpoch(k.timestamp).year;
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
        timestamp: DateTime(y).millisecondsSinceEpoch,
        open: bars.first.open,
        high: high,
        low: low,
        close: bars.last.close,
        volume: vol,
      );
    }).toList();
  }

  /// Parse a Binance `@kline` websocket payload into a [KLineData], or `null`.
  static KLineData? parseKlineEvent(String message) {
    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
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
    } catch (_) {}
    return null;
  }

  /// Subscribe to live kline updates for [period]; [onBar] is called for each
  /// update (the still-forming bar repeatedly, then the closed bar).
  void subscribe(Period period, void Function(KLineData bar) onBar) {
    unsubscribe();
    final interval = intervalOf(period);
    if (interval == null) {
      return; // no live stream for yearly
    }
    final stream = '${symbol.toLowerCase()}@kline_$interval';
    final channel = WebSocketChannel.connect(Uri.parse('$_wsBase/$stream'));
    _channel = channel;
    _sub = channel.stream.listen(
      (event) {
        final bar = parseKlineEvent(event as String);
        if (bar != null) onBar(bar);
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }

  void unsubscribe() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() => unsubscribe();
}
