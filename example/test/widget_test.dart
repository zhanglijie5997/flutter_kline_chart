import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kline_chart/kline_chart.dart';
import 'package:kline_chart_example/binance.dart';
import 'package:kline_chart_example/main.dart';

class _FakeBinanceSource extends BinanceSource {
  _FakeBinanceSource() : super(symbol: 'BTCUSDT');

  void Function(KLineData bar)? onBar;
  void Function(double price)? onPrice;
  void Function(TradeTick trade)? onTrade;
  void Function(Map<String, Ticker> tickers)? onTickers;
  void Function(Map<String, double> prices)? onPrices;

  @override
  void subscribe(
    Period period,
    void Function(KLineData bar) barCallback, {
    void Function(double price)? onPrice,
    void Function(TradeTick trade)? onTrade,
    void Function(Ticker t)? onTicker,
    void Function(Map<String, Ticker> tickers)? onTickers,
    void Function(Map<String, double> prices)? onPrices,
    void Function(WsStatus status)? onStatus,
  }) {
    onBar = barCallback;
    this.onPrice = onPrice;
    this.onTrade = onTrade;
    this.onTickers = onTickers;
    this.onPrices = onPrices;
    onStatus?.call(WsStatus.connected);
  }

  @override
  void unsubscribe() {
    onBar = null;
    onPrice = null;
    onTrade = null;
    onTickers = null;
    onPrices = null;
  }

  void emitPrice(double value) => onPrice?.call(value);
  void emitTrade(TradeTick value) => onTrade?.call(value);
  void emitBar(KLineData value) => onBar?.call(value);
  void emitTickers(Map<String, Ticker> value) => onTickers?.call(value);
  void emitPrices(Map<String, double> value) => onPrices?.call(value);
}

void main() {
  testWidgets('switching timeframes rebuilds the chart without error',
      (tester) async {
    // Portrait surface so the timeframe bar is shown (landscape = chart only).
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        // Offline synthetic loader so the test doesn't hit the network.
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    // Tap a few timeframe chips that are visible at the start of the row.
    for (final label in ['5分', '15分', '1时', '4时']) {
      final finder = find.text(label);
      if (finder.evaluate().isNotEmpty) {
        await tester.tap(finder.first, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.takeException(), isNull, reason: 'after tapping $label');
      }
    }
  });

  testWidgets('landscape shows only the fullscreen chart (no chrome)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 420); // landscape
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);

    // Chrome (app bar title, timeframe chips, zoom FABs) is hidden.
    expect(find.text('BTC/USDT · Binance'), findsNothing);
    expect(find.text('1D'), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    // The chart is present.
    expect(find.byType(KLineChartWidget), findsOneWidget);
  });

  testWidgets('symbol picker opens, searches, and switches the contract',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    // Header shows the default contract.
    expect(find.text('BTC/USDT'), findsOneWidget);

    // Tapping the header opens the searchable picker.
    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    expect(find.text('搜索币种 (BTC, ETH…)'), findsOneWidget);

    // Typing filters the list down to matching contracts only.
    await tester.enterText(find.byType(TextField), 'ETH');
    await tester.pump();
    expect(find.text('ETH/USDT'), findsOneWidget);
    expect(find.text('BNB/USDT'), findsNothing);

    // Selecting a contract closes the sheet and updates the header.
    await tester.tap(find.text('ETH/USDT'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('搜索币种 (BTC, ETH…)'), findsNothing); // sheet closed
    expect(find.text('ETH/USDT'), findsOneWidget); // header switched
  });

  testWidgets('search field stays on-screen when the keyboard is up',
      (tester) async {
    const screenH = 900.0;
    const keyboardH = 320.0;
    tester.view.physicalSize = const Size(420, screenH);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    // Open the searchable picker; its search box sits at the top of the sheet.
    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField);
    expect(field, findsOneWidget);
    final topBefore = tester.getRect(field).top;

    // Simulate the on-screen keyboard occupying the bottom of the screen.
    tester.view.viewInsets = const FakeViewPadding(bottom: keyboardH);
    await tester.pumpAndSettle();

    // Focusing must NOT push the popup up: the search box stays exactly where
    // it was (the sheet shrinks its body instead of growing upward)...
    final rect = tester.getRect(field);
    expect(rect.top, moreOrLessEquals(topBefore, epsilon: 0.5),
        reason: 'the keyboard pushed the popup up');
    // ...and it stays fully above the keyboard.
    expect(rect.bottom, lessThanOrEqualTo(screenH - keyboardH),
        reason: 'search field overlaps the keyboard');
  });

  testWidgets('a zero-price trade does not spike the forming bar to 0',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeBinanceSource();
    final bars = generateData(const Period(type: 'hour', span: 4));

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (_) async => bars,
        marketSource: source,
        demoTickers: const <String, Ticker>{
          'BTCUSDT': (last: 100, changePct: 1),
        },
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    // A good trade establishes a clean forming-bar price.
    final prev = bars.last;
    source.emitTrade((price: 250, quantity: 1, timestamp: prev.timestamp + 1000));
    await tester.pump(const Duration(milliseconds: 260)); // flush the throttle
    expect(find.text('250.00'), findsOneWidget);

    // A garbage 0-price tick must be ignored — not fold the bar's low/close to
    // 0, which would collapse the header and spike the chart's axis to 0.00.
    source
        .emitTrade((price: 0, quantity: 1, timestamp: prev.timestamp + 2000));
    await tester.pump(const Duration(milliseconds: 260));
    expect(tester.takeException(), isNull);
    expect(find.text('0.00'), findsNothing); // header did not collapse to zero
    expect(find.text('250.00'), findsOneWidget); // last good price retained
  });

  testWidgets('TradFi 板块 chip filters to TradFi contracts', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    // Open the picker (offline -> fallback list, which includes TradFi entries).
    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();

    // A crypto contract is visible under the default 全部 sector. (Use ETH, not
    // the selected BTC, since the header always shows the selected contract.)
    expect(find.text('ETH/USDT'), findsWidgets);

    // Tap the TradFi 板块 chip (first in tree order) -> only TradFi remain.
    await tester.tap(find.text('TradFi').first);
    await tester.pumpAndSettle();
    expect(find.text('TSLA/USDT'), findsOneWidget); // a TradFi stock
    expect(find.text('XAU/USDT'), findsOneWidget); // gold
    expect(find.text('ETH/USDT'), findsNothing); // crypto filtered out

    // Select a TradFi contract -> header switches and shows the TradFi tag.
    await tester.tap(find.text('TSLA/USDT'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('TSLA/USDT'), findsOneWidget); // header
    expect(find.text('TradFi'), findsOneWidget); // header type tag
  });

  testWidgets('picker rows show last price and 24h change%', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
        // Injected 24h snapshot (live fetch is skipped offline).
        demoTickers: const <String, Ticker>{
          'BTCUSDT': (last: 62748.4, changePct: 1.01),
          'ETHUSDT': (last: 1745.37, changePct: -0.43),
        },
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // no RenderFlex overflow in rows

    // BTC (the selected contract) shows in both the header and its picker row.
    expect(find.text('62,748.40'), findsNWidgets(2));
    expect(find.text('+1.01%'), findsNWidgets(2));
    // ETH only in its picker row, formatted with thousands separators + sign.
    expect(find.text('1,745.37'), findsOneWidget);
    expect(find.text('-0.43%'), findsOneWidget);
  });

  testWidgets('header shows the selected contract live price + 24h change',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
        demoTickers: const <String, Ticker>{
          'BTCUSDT': (last: 62748.4, changePct: 1.01),
        },
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    // Picker closed -> the price/change belong to the header only.
    expect(find.text('62,748.40'), findsOneWidget);
    expect(find.text('+1.01%'), findsOneWidget);
  });

  testWidgets('live prices update the chart header and open contract list',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeBinanceSource();
    final bars = generateData(const Period(type: 'hour', span: 4));

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (_) async => bars,
        marketSource: source,
        demoTickers: const <String, Ticker>{
          'BTCUSDT': (last: 100, changePct: 1),
          'ETHUSDT': (last: 200, changePct: -2),
        },
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    source.emitTickers(const <String, Ticker>{
      'BTCUSDT': (last: 101, changePct: 1.5),
      'ETHUSDT': (last: 201, changePct: -2.5),
    });
    await tester.pump();
    expect(find.text('101.00'), findsOneWidget);
    expect(find.text('+1.50%'), findsOneWidget);

    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    expect(find.text('201.00'), findsOneWidget);
    expect(find.text('-2.50%'), findsOneWidget);
    source.emitPrices(const <String, double>{'ETHUSDT': 202});
    await tester.pump();
    expect(find.text('202.00'), findsOneWidget);
    expect(find.text('-2.50%'), findsOneWidget);

    // A same-timestamp forming-bar update also refreshes the header price.
    final previous = bars.last;
    source.emitBar(KLineData(
      timestamp: previous.timestamp,
      open: previous.open,
      high: previous.high + 1,
      low: previous.low,
      close: 102,
      volume: previous.volume,
      turnover: previous.turnover,
    ));
    await tester.pump();
    expect(find.text('102.00'), findsOneWidget);

    // An authoritative kline arriving inside the trade throttle window must
    // clear the older pending trade instead of being overwritten 250ms later.
    source.emitTrade((
      price: 103,
      quantity: 1,
      timestamp: previous.timestamp + 1000,
    ));
    source.emitBar(KLineData(
      timestamp: previous.timestamp,
      open: previous.open,
      high: previous.high + 2,
      low: previous.low,
      close: 104,
      volume: previous.volume,
      turnover: previous.turnover,
    ));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('104.00'), findsOneWidget);
    expect(find.text('103.00'), findsNothing);

    // A delayed final kline from the previous period must not erase a newer
    // period's first trade or move the header backwards.
    source.emitTrade((
      price: 105,
      quantity: 1,
      timestamp:
          previous.timestamp + const Duration(hours: 4).inMilliseconds + 1000,
    ));
    source.emitBar(KLineData(
      timestamp: previous.timestamp,
      open: previous.open,
      high: previous.high,
      low: previous.low,
      close: 106,
      volume: previous.volume,
      turnover: previous.turnover,
    ));
    await tester.pump();
    expect(find.text('106.00'), findsNothing);
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('105.00'), findsNWidgets(2));
  });

  testWidgets('history failure does not disable the live subscription',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = _FakeBinanceSource();

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (_) => Future<List<KLineData>>.error('offline'),
        marketSource: source,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));
    expect(source.onTrade, isNotNull);

    source.emitTrade((
      price: 321.5,
      quantity: 1,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    ));
    await tester.pump(const Duration(milliseconds: 260));
    expect(find.text('321.50'), findsOneWidget);
    expect(find.text('--'), findsOneWidget);
  });

  testWidgets('picker remembers the last 板块 across opens', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    // Open, switch to the TradFi 板块, then dismiss (tap the barrier above sheet).
    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TradFi').first);
    await tester.pumpAndSettle();
    expect(find.text('TSLA/USDT'), findsOneWidget);
    await tester.tapAt(const Offset(210, 12));
    await tester.pumpAndSettle();

    // Reopen -> restored to the TradFi 板块 (crypto still filtered out).
    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    expect(find.text('TSLA/USDT'), findsOneWidget);
    expect(find.text('ETH/USDT'), findsNothing);
  });

  testWidgets('picker remembers the scroll position across opens',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: ChartPage(
        historyLoader: (p) async => generateData(p),
        subscribeLive: false,
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    expect(find.text('ETH/USDT'), findsOneWidget); // visible at the top

    // Scroll the list well past the top row, then dismiss.
    await tester.drag(find.text('SOL/USDT'), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('ETH/USDT'), findsNothing); // scrolled off (beyond cache)
    await tester.tapAt(const Offset(210, 12));
    await tester.pumpAndSettle();

    // Reopen: if the scroll reset to 0, ETH would be back at the top. It stays
    // hidden -> the offset was restored.
    await tester.tap(find.text('BTC/USDT'));
    await tester.pumpAndSettle();
    expect(find.text('ETH/USDT'), findsNothing);
  });

  group('parseKlineEvent rejects zero / partial OHLC frames', () {
    String klineMsg(
            {String o = '100', String h = '110', String l = '90', String c = '105'}) =>
        '{"e":"kline","k":{"t":1783828800000,"o":"$o","h":"$h","l":"$l","c":"$c","v":"5","q":"500"}}';

    test('a valid kline parses to its positive OHLC', () {
      final bar = BinanceSource.parseKlineEvent(klineMsg());
      expect(bar, isNotNull);
      expect(bar!.open, 100);
      expect(bar.high, 110);
      expect(bar.low, 90);
      expect(bar.close, 105);
    });

    test('a kline with a zero low is dropped (no spike to 0.00)', () {
      expect(BinanceSource.parseKlineEvent(klineMsg(l: '0')), isNull);
    });

    test('a kline with a missing OHLC field is dropped', () {
      expect(
        BinanceSource.parseKlineEvent(
            '{"e":"kline","k":{"t":1,"o":"100","h":"110","c":"105","v":"5","q":"500"}}'),
        isNull,
      );
    });
  });

  test('trade fallback aligns the first bar to Binance UTC buckets', () {
    const tradeTime = 1783832040123; // 2026-07-12 04:54:00.123 UTC
    expect(tradeBucketStart(tradeTime, const Period(type: 'minute', span: 1)),
        1783832040000);
    expect(tradeBucketStart(tradeTime, const Period(type: 'hour', span: 4)),
        1783828800000); // 04:00 UTC
    expect(tradeBucketStart(tradeTime, const Period(type: 'day', span: 3)),
        1783641600000); // Binance 3d bar: 2026-07-10 00:00 UTC
    expect(tradeBucketStart(tradeTime, const Period(type: 'week', span: 1)),
        1783296000000); // Monday 00:00 UTC
    expect(tradeBucketStart(tradeTime, const Period(type: 'month', span: 1)),
        1782864000000); // first day of the month, UTC
  });

  test('generateData produces correctly-spaced bars for every timeframe', () {
    final cases = <Period>[
      const Period(type: 'minute', span: 1),
      const Period(type: 'minute', span: 5),
      const Period(type: 'minute', span: 15),
      const Period(type: 'hour', span: 1),
      const Period(type: 'hour', span: 4),
      const Period(type: 'hour', span: 12),
      const Period(type: 'day', span: 1),
      const Period(type: 'day', span: 3),
      const Period(type: 'week', span: 1),
      const Period(type: 'month', span: 1),
      const Period(type: 'year', span: 1),
    ];
    for (final p in cases) {
      final data = generateData(p, count: 50);
      expect(data.length, 50, reason: '${p.type}/${p.span}');
      // strictly increasing timestamps
      for (var i = 1; i < data.length; i++) {
        expect(data[i].timestamp, greaterThan(data[i - 1].timestamp),
            reason: '${p.type}/${p.span} at $i');
      }
      // second bar equals advanceTime of the first
      final first = DateTime.fromMillisecondsSinceEpoch(data[0].timestamp);
      expect(data[1].timestamp, advanceTime(first, p).millisecondsSinceEpoch,
          reason: '${p.type}/${p.span} spacing');
    }
  });
}
