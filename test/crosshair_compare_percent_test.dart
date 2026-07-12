import 'package:flutter_test/flutter_test.dart';
import 'package:kline_chart/src/view/crosshair_view.dart';

void main() {
  group('crosshairComparePercent', () {
    test('crosshair above the current price is a positive %', () {
      expect(crosshairComparePercent(110, 100), closeTo(10, 1e-9));
    });

    test('crosshair below the current price is a negative %', () {
      expect(crosshairComparePercent(98.81, 100), closeTo(-1.19, 1e-9));
    });

    test('crosshair at the current price is 0', () {
      expect(crosshairComparePercent(100, 100), 0);
    });

    test('no reference price yields null', () {
      expect(crosshairComparePercent(100, null), isNull);
      expect(crosshairComparePercent(100, 0), isNull);
    });
  });

  group('formatComparePercent', () {
    test('positive gets a + sign and 2 decimals', () {
      expect(formatComparePercent(10), '+10.00%');
    });

    test('negative keeps its - sign', () {
      expect(formatComparePercent(-1.19), '-1.19%');
    });

    test('zero has no sign', () {
      expect(formatComparePercent(0), '0.00%');
    });

    test('rounds to two decimals', () {
      // (63200 - 63959.7) / 63959.7 * 100 = -1.1877... -> -1.19%
      final pct = crosshairComparePercent(63200, 63959.7)!;
      expect(formatComparePercent(pct), '-1.19%');
    });
  });
}
