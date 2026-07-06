// Standalone sanity check that Binance market data is reachable from the Dart
// runtime. Run with:  dart run tool/binance_live_check.dart
//
// Imports only `http` (no Flutter) so it runs in the plain Dart VM.
import 'dart:convert';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final uri = Uri.parse(
      'https://data-api.binance.vision/api/v3/klines?symbol=BTCUSDT&interval=1m&limit=5');
  final resp = await http.get(uri).timeout(const Duration(seconds: 20));
  if (resp.statusCode != 200) {
    print('FAIL http ${resp.statusCode}: ${resp.body}');
    return;
  }
  final list = jsonDecode(resp.body) as List;
  print('OK fetched ${list.length} BTCUSDT 1m bars');
  final last = list.last as List;
  final t = DateTime.fromMillisecondsSinceEpoch((last[0] as num).toInt());
  print('last bar openTime=$t close=${last[4]} volume=${last[5]}');
}
