import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kline_chart/kline_chart.dart';
import 'package:kline_chart_example/main.dart';

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
