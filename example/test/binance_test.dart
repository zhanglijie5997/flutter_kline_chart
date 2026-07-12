import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kline_chart/kline_chart.dart';
import 'package:kline_chart_example/binance.dart';

void main() {
  test('intervalOf maps every timeframe to a Binance interval (year -> null)',
      () {
    expect(
        BinanceSource.intervalOf(const Period(type: 'minute', span: 1)), '1m');
    expect(
        BinanceSource.intervalOf(const Period(type: 'minute', span: 5)), '5m');
    expect(BinanceSource.intervalOf(const Period(type: 'minute', span: 15)),
        '15m');
    expect(BinanceSource.intervalOf(const Period(type: 'hour', span: 1)), '1h');
    expect(BinanceSource.intervalOf(const Period(type: 'hour', span: 4)), '4h');
    expect(
        BinanceSource.intervalOf(const Period(type: 'hour', span: 12)), '12h');
    expect(BinanceSource.intervalOf(const Period(type: 'day', span: 1)), '1d');
    expect(BinanceSource.intervalOf(const Period(type: 'day', span: 3)), '3d');
    expect(BinanceSource.intervalOf(const Period(type: 'week', span: 1)), '1w');
    expect(
        BinanceSource.intervalOf(const Period(type: 'month', span: 1)), '1M');
    expect(
        BinanceSource.intervalOf(const Period(type: 'year', span: 1)), isNull);
  });

  test('klineFromRestArray parses a real Binance REST kline', () {
    // A real BTCUSDT 1m bar from data-api.binance.vision.
    const raw =
        '[1783302540000,"63606.01000000","63611.82000000","63581.70000000","63611.81000000","5.64552000",1783302599999,"359042.49989920",2095,"2.06496000","131333.71794240","0"]';
    final k = BinanceSource.klineFromRestArray(jsonDecode(raw) as List);
    expect(k.timestamp, 1783302540000);
    expect(k.open, 63606.01);
    expect(k.high, 63611.82);
    expect(k.low, 63581.70);
    expect(k.close, 63611.81);
    expect(k.volume, closeTo(5.64552, 1e-6));
    expect(k.turnover, closeTo(359042.4998992, 1e-3));
  });

  test('parseKlineEvent parses a real Binance @kline websocket payload', () {
    const msg =
        '{"e":"kline","E":1783302599123,"s":"BTCUSDT","k":{"t":1783302540000,"T":1783302599999,"s":"BTCUSDT","i":"1m","o":"63606.01000000","c":"63611.81000000","h":"63611.82000000","l":"63581.70000000","v":"5.64552000","n":2095,"x":true,"q":"359042.49989920"}}';
    final k = BinanceSource.parseKlineEvent(msg);
    expect(k, isNotNull);
    expect(k!.timestamp, 1783302540000);
    expect(k.close, 63611.81);
    expect(k.high, 63611.82);
    expect(k.low, 63581.70);
    expect(k.volume, closeTo(5.64552, 1e-6));
  });

  test('parseTickerEvents parses raw, combined, and all-market payloads', () {
    const allMarket =
        '[{"e":"24hrTicker","s":"BTCUSDT","c":"64001.40","P":"-0.34"},'
        '{"e":"24hrTicker","s":"ETHUSDT","c":"1820.25","P":"1.27"}]';
    final batch = BinanceSource.parseTickerEvents(allMarket);
    expect(batch.keys, containsAll(<String>['BTCUSDT', 'ETHUSDT']));
    expect(batch['BTCUSDT']!.last, 64001.4);
    expect(batch['BTCUSDT']!.changePct, -0.34);
    expect(batch['ETHUSDT']!.last, 1820.25);
    expect(batch['ETHUSDT']!.changePct, 1.27);

    const combined = '{"stream":"btcusdt@ticker","data":{"e":"24hrTicker",'
        '"s":"BTCUSDT","c":"64002.10","P":"-0.33"}}';
    final one = BinanceSource.parseTickerEvents(combined);
    expect(one['BTCUSDT'], (last: 64002.1, changePct: -0.33));

    // Subscription acknowledgements are not market data.
    expect(BinanceSource.parseTickerEvents('{"result":null,"id":1}'), isEmpty);
  });

  test('reconnectDelay is exponential and capped at 30s', () {
    Duration d(int a) => BinanceSource.reconnectDelay(a);
    expect(d(0), const Duration(milliseconds: 500));
    expect(d(1), const Duration(seconds: 1));
    expect(d(2), const Duration(seconds: 2));
    expect(d(3), const Duration(seconds: 4));
    expect(d(4), const Duration(seconds: 8));
    expect(d(5), const Duration(seconds: 16));
    expect(d(6), const Duration(seconds: 30)); // 32s capped to 30s
    expect(d(10), const Duration(seconds: 30)); // stays capped
    expect(d(-1), const Duration(milliseconds: 500)); // clamps negatives
  });
}
