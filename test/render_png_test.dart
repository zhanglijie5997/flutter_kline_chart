import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kline_chart/kline_chart.dart';

import 'kline_chart_test.dart' show gen;

void main() {
  testWidgets('render chart to PNG for visual inspection', (tester) async {
    final controller = KLineChartController(styles: darkStyleOverrides());
    controller
      ..setSymbol(SymbolInfo(ticker: 'DEMO', pricePrecision: 2, volumePrecision: 0))
      ..setPeriod(const Period(type: 'day', span: 1))
      ..applyNewData(gen(300));
    // Top legend: indicators only (hide the candle OHLCV row).
    controller.setStyles(<String, dynamic>{
      'candle': {
        'tooltip': {'showRule': 'none'},
      },
    });
    controller.createIndicator('MA', paneId: KLineChartController.candlePaneId);
    // Sub-pane indicators with their legend hidden (per-indicator showRule).
    const hide = <String, dynamic>{
      'tooltip': {'showRule': 'none'}
    };
    // VOL with empty calcParams -> volume bars only (no volume-MA lines).
    controller.createIndicator('VOL', calcParams: <dynamic>[], styles: hide);
    controller.createIndicator('MACD', styles: hide);

    final bars = controller.getDataList();
    controller.setMarkers([
      TradeMarker(
          timestamp: bars[280].timestamp,
          price: bars[280].low,
          side: TradeSide.buy,
          text: 'Buy'),
      TradeMarker(
          timestamp: bars[290].timestamp,
          price: bars[290].high,
          side: TradeSide.sell,
          text: 'Sell'),
    ]);

    final key = GlobalKey();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 900,
                height: 560,
                child: KLineChartWidget(
                  controller: controller,
                  backgroundColor: const Color(0xFF1B1B1F),
                  markerBuilder: (context, m) {
                    final buy = m.side == TradeSide.buy;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: buy
                            ? const Color(0xFF2DC08E)
                            : const Color(0xFFF92855),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${buy ? 'Buy' : 'Sell'} ${m.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));

    // Focus the Buy marker's bar so the top legend shows the "Buy" entry.
    final buyIdx = controller.store.timestampToDataIndex(bars[280].timestamp);
    final mx = controller.store.dataIndexToCoordinate(buyIdx);
    controller.store.setCrosshair(
        Crosshair(x: mx, y: 160, paneId: KLineChartController.candlePaneId));
    await tester.pump(const Duration(milliseconds: 40));

    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('/tmp/kline_render.png');
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(file.existsSync(), isTrue);
    // ignore: avoid_print
    print('WROTE ${file.lengthSync()} bytes to ${file.path}');
  });
}
