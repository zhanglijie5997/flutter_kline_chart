// Standalone sanity check that the production futures REST + websocket paths
// used by the example are reachable and agree. Run with:
//   dart run tool/binance_live_check.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  const restBase = 'https://fapi.binance.com';
  const symbol = 'BTCUSDT';
  final responses = await Future.wait(<Future<http.Response>>[
    http
        .get(Uri.parse('$restBase/fapi/v1/klines'
            '?symbol=$symbol&interval=1m&limit=2'))
        .timeout(const Duration(seconds: 15)),
    http
        .get(Uri.parse('$restBase/fapi/v1/ticker/price?symbol=$symbol'))
        .timeout(const Duration(seconds: 15)),
    http
        .get(Uri.parse('$restBase/fapi/v1/ticker/price'))
        .timeout(const Duration(seconds: 15)),
  ]);
  for (final response in responses) {
    if (response.statusCode != 200) {
      throw StateError(
          'production REST failed: ${response.statusCode} ${response.body}');
    }
  }

  final bars = jsonDecode(responses[0].body) as List<dynamic>;
  final restTicker = jsonDecode(responses[1].body) as Map<String, dynamic>;
  final allPrices = jsonDecode(responses[2].body) as List<dynamic>;
  final restPrice = double.parse(restTicker['price'] as String);
  print('OK production REST: ${bars.length} bars, '
      '${allPrices.length} prices, $symbol=$restPrice');

  final socket =
      await WebSocket.connect('wss://fstream.binance.com/ws/btcusdt@trade')
          .timeout(const Duration(seconds: 8));
  try {
    final events = socket
        .where((event) => event is String)
        .cast<String>()
        .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
        .asBroadcastStream();
    final tradeFuture = events
        .firstWhere((event) => event['e'] == 'trade')
        .timeout(const Duration(seconds: 8));
    final bookFuture = events
        .firstWhere((event) => event['e'] == 'bookTicker')
        .timeout(const Duration(seconds: 8));
    socket.add(jsonEncode({
      'method': 'SUBSCRIBE',
      'params': ['!bookTicker', 'btcusdt@kline_1m', '!ticker@arr'],
      'id': 1,
    }));
    final live = await Future.wait<Map<String, dynamic>>(
        <Future<Map<String, dynamic>>>[tradeFuture, bookFuture]);
    final trade = live[0];
    final book = live[1];
    final tradePrice = double.parse(trade['p'] as String);
    // Prices naturally move between the REST request and websocket frame. The
    // tolerance catches accidental demo/testnet mixing without requiring exact
    // equality on an active market.
    final driftPct = (tradePrice - restPrice).abs() / restPrice * 100;
    if (driftPct > 1) {
      throw StateError('REST/WS mismatch: REST=$restPrice WS=$tradePrice '
          '(${driftPct.toStringAsFixed(3)}%)');
    }
    print('OK production websocket: trade=$tradePrice '
        'drift=${driftPct.toStringAsFixed(4)}%, '
        'bookTicker=${book['s']}');
  } finally {
    await socket.close();
  }
}
