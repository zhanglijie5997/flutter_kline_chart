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

import 'dart:math' as math;

import '../../common/utils/format.dart';
import '../../component/indicator.dart';

/// Port of `extension/indicator/stopAndReverse.ts` (SAR).
final IndicatorTemplate stopAndReverse = IndicatorTemplate(
  name: 'SAR',
  shortName: 'SAR',
  series: 'price',
  calcParams: <dynamic>[2, 2, 20],
  precision: 2,
  shouldOhlc: true,
  figures: <IndicatorFigure>[
    IndicatorFigure(
      key: 'sar',
      title: 'SAR: ',
      type: 'circle',
      styles: (params) {
        final current = params.data.current;
        final sar = (current?['sar'] as num?) ?? -9007199254740991;
        final high = (current?['high'] as num?) ?? 0;
        final low = (current?['low'] as num?) ?? 0;
        final halfHL = (high + low) / 2;
        final defaultCircles =
            (params.defaultStyles['circles'] as List).first as Map;
        final color = sar < halfHL
            ? formatValue(params.indicator.styles, 'circles[0].upColor',
                defaultCircles['upColor'])
            : formatValue(params.indicator.styles, 'circles[0].downColor',
                defaultCircles['downColor']);
        return <String, dynamic>{'color': color};
      },
    ),
  ],
  calc: (dataList, indicator) {
    final startAf = (indicator.calcParams[0] as num).toInt() / 100;
    final step = (indicator.calcParams[1] as num).toInt() / 100;
    final maxAf = (indicator.calcParams[2] as num).toInt() / 100;

    // 加速因子
    var af = startAf;
    // 极值
    var ep = -100.0;
    // 判断是上涨还是下跌  false：下跌
    var isIncreasing = false;
    var sar = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kLineData = dataList[i];
      // 上一个周期的sar
      final preSar = sar;
      final high = kLineData.high;
      final low = kLineData.low;
      if (isIncreasing) {
        // 上涨
        if (ep == -100 || ep < high) {
          // 重新初始化值
          ep = high;
          af = math.min(af + step, maxAf);
        }
        sar = preSar + af * (ep - preSar);
        final lowMin = math.min(dataList[math.max(1, i) - 1].low, low);
        if (sar > kLineData.low) {
          sar = ep;
          // 重新初始化值
          af = startAf;
          ep = -100;
          isIncreasing = !isIncreasing;
        } else if (sar > lowMin) {
          sar = lowMin;
        }
      } else {
        if (ep == -100 || ep > low) {
          // 重新初始化值
          ep = low;
          af = math.min(af + step, maxAf);
        }
        sar = preSar + af * (ep - preSar);
        final highMax = math.max(dataList[math.max(1, i) - 1].high, high);
        if (sar < kLineData.high) {
          sar = ep;
          // 重新初始化值
          af = 0;
          ep = -100;
          isIncreasing = !isIncreasing;
        } else if (sar < highMax) {
          sar = highMax;
        }
      }
      result.add(<String, dynamic>{'high': high, 'low': low, 'sar': sar});
    }
    return result;
  },
);
