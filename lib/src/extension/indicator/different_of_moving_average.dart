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

import '../../component/indicator.dart';

/// Port of `extension/indicator/differentOfMovingAverage.ts` (DMA).
final IndicatorTemplate differentOfMovingAverage = IndicatorTemplate(
  name: 'DMA',
  shortName: 'DMA',
  calcParams: <dynamic>[10, 50, 10],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'dma', title: 'DMA: ', type: 'line'),
    IndicatorFigure(key: 'ama', title: 'AMA: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final p0 = (indicator.calcParams[0] as num).toInt();
    final p1 = (indicator.calcParams[1] as num).toInt();
    final p2 = (indicator.calcParams[2] as num).toInt();
    final maxPeriod = math.max(p0, p1);
    var closeSum1 = 0.0;
    var closeSum2 = 0.0;
    var dmaSum = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final dma = <String, dynamic>{};
      final close = dataList[i].close;
      closeSum1 += close;
      closeSum2 += close;
      var ma1 = 0.0;
      var ma2 = 0.0;
      if (i >= p0 - 1) {
        ma1 = closeSum1 / p0;
        closeSum1 -= dataList[i - (p0 - 1)].close;
      }
      if (i >= p1 - 1) {
        ma2 = closeSum2 / p1;
        closeSum2 -= dataList[i - (p1 - 1)].close;
      }

      if (i >= maxPeriod - 1) {
        final dif = ma1 - ma2;
        dma['dma'] = dif;
        dmaSum += dif;
        if (i >= maxPeriod + p2 - 2) {
          dma['ama'] = dmaSum / p2;
          dmaSum -= (result[i - (p2 - 1)]['dma'] as num?)?.toDouble() ?? 0.0;
        }
      }
      result.add(dma);
    }
    return result;
  },
);
