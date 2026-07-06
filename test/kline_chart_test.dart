// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kline_chart/kline_chart.dart';

List<KLineData> gen(int n) {
  final data = <KLineData>[];
  var ts = DateTime(2021).millisecondsSinceEpoch;
  var price = 100.0;
  final r = Random(1);
  for (var i = 0; i < n; i++) {
    price += (r.nextDouble() - 0.5) * 4;
    final open = price;
    final close = price + (r.nextDouble() - 0.5) * 4;
    data.add(KLineData(
      timestamp: ts,
      open: open,
      high: max(open, close) + r.nextDouble() * 2,
      low: min(open, close) - r.nextDouble() * 2,
      close: close,
      volume: r.nextDouble() * 1000 + 100,
    ));
    ts += 24 * 60 * 60 * 1000;
  }
  return data;
}

KLineChartController freshController() {
  final c = KLineChartController();
  c
    ..setSymbol(SymbolInfo(ticker: 'T', pricePrecision: 2, volumePrecision: 0))
    ..setPeriod(const Period(type: 'day', span: 1))
    ..applyNewData(gen(200));
  return c;
}

void main() {
  testWidgets('renders candles + indicators and handles scroll/zoom',
      (tester) async {
    final controller = freshController();
    controller.createIndicator('MA', paneId: KLineChartController.candlePaneId);
    controller.createIndicator('VOL');
    controller.createIndicator('MACD');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 520,
          child: KLineChartWidget(controller: controller),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);

    // scroll
    controller.startScroll();
    controller.scrollByDistance(80);
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull);

    // zoom
    controller.zoomAtCoordinate(3, 350);
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull);

    // crosshair via drivers
    controller.store.setCrosshair(controller.crosshairAt(350, 200));
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a candle reports its data via onCandleTap + action',
      (tester) async {
    final controller = freshController();
    KLineData? tapped;
    KLineData? viaAction;
    KLineData? focused;
    Offset? focusPos;
    controller.subscribeAction(ActionTypes.onCandleBarClick, ([data]) {
      viaAction = data as KLineData?;
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 500,
          child: KLineChartWidget(
            controller: controller,
            onCandleTap: (data, pos) => tapped = data,
            onCrosshairChange: (data, pos) {
              focused = data;
              focusPos = pos;
            },
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tapAt(const Offset(350, 220));
    await tester.pump(const Duration(milliseconds: 30));

    expect(tapped, isNotNull);
    expect(viaAction, isNotNull);
    expect(identical(tapped, viaAction), isTrue);
    expect(controller.crosshairData, isNotNull);
    // crosshair-change callback fired with the focused bar + pointer position
    expect(focused, isNotNull);
    expect(focusPos, isNotNull);
    expect(identical(focused, tapped), isTrue);
  });

  testWidgets('markerBuilder renders custom marker widgets positioned on bars',
      (tester) async {
    final controller = freshController();
    final bars = controller.getDataList();
    final anchor = bars[bars.length - 30];
    controller.setMarkers([
      TradeMarker(
          timestamp: anchor.timestamp,
          price: anchor.low,
          side: TradeSide.buy,
          text: 'Buy'),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 800,
          height: 500,
          child: KLineChartWidget(
            controller: controller,
            markerBuilder: (context, m) =>
                Text('MK_${m.side == TradeSide.buy ? 'B' : 'S'}'),
          ),
        ),
      ),
    ));
    // First frame paints + publishes layout; the post-frame bump then rebuilds
    // the overlay, so pump twice.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
    expect(find.text('MK_B'), findsOneWidget);
  });

  testWidgets('renders indicators when the visible range starts before data',
      (tester) async {
    // A small dataset in a wide chart makes the visible range begin at a
    // negative dataIndex (realFrom < 0) — indicator rendering must not throw.
    final controller = KLineChartController();
    controller
      ..setSymbol(SymbolInfo(ticker: 'T'))
      ..setPeriod(const Period(type: 'day', span: 1))
      ..applyNewData(gen(20));
    controller.createIndicator('MA', paneId: KLineChartController.candlePaneId);
    controller.createIndicator('MACD');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 900,
          height: 520,
          child: KLineChartWidget(controller: controller),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders with no data (empty visible range) without throwing',
      (tester) async {
    final controller = KLineChartController();
    controller.createIndicator('MA', paneId: KLineChartController.candlePaneId);
    controller.createIndicator('VOL');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 700,
          height: 500,
          child: KLineChartWidget(controller: controller),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.takeException(), isNull);
  });

  test('every built-in indicator computes without throwing', () async {
    final names = getSupportedIndicators();
    expect(names.length, greaterThanOrEqualTo(27));
    final data = gen(200);
    final failures = <String, String>{};
    for (final name in names) {
      final c = freshController();
      final pid = c.createIndicator(name);
      if (pid == null) {
        failures[name] = 'createIndicator returned null';
        continue;
      }
      final ind = c.store.getIndicatorsByPaneId(pid).first;
      try {
        final res = await Future<List<Map<String, dynamic>>>.value(
            ind.calc(data, ind));
        if (res.length != data.length) {
          failures[name] = 'result length ${res.length} != ${data.length}';
        }
      } catch (e) {
        failures[name] = '$e';
      }
    }
    expect(failures, isEmpty, reason: 'indicator calc failures: $failures');
  });

  test('zoomIn / zoomOut change the bar space', () {
    final c = freshController();
    c.store.setTotalBarSpace(600);
    final before = c.store.getBarSpace().bar;
    c.zoomIn();
    final zoomedIn = c.store.getBarSpace().bar;
    expect(zoomedIn, greaterThan(before), reason: 'zoomIn widens bars');
    c.zoomOut();
    c.zoomOut();
    expect(c.store.getBarSpace().bar, lessThan(zoomedIn),
        reason: 'zoomOut narrows bars');
  });

  test('coordinate <-> index conversions round-trip', () {
    final c = freshController();
    c.store.setTotalBarSpace(600);
    for (var i = 5; i < 50; i++) {
      final x = c.store.dataIndexToCoordinate(i);
      final back = c.store.coordinateToDataIndex(x);
      expect(back, i, reason: 'index $i -> x $x -> $back');
    }
  });
}
