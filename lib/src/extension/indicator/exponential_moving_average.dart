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

import '../../component/indicator.dart';

/// Port of `extension/indicator/exponentialMovingAverage.ts` (EMA).
final IndicatorTemplate exponentialMovingAverage = IndicatorTemplate(
  name: 'EMA',
  shortName: 'EMA',
  series: 'price',
  calcParams: <dynamic>[6, 12, 20],
  precision: 2,
  shouldOhlc: true,
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'ema1', title: 'EMA6: ', type: 'line'),
    IndicatorFigure(key: 'ema2', title: 'EMA12: ', type: 'line'),
    IndicatorFigure(key: 'ema3', title: 'EMA20: ', type: 'line'),
  ],
  regenerateFigures: (params) => List<IndicatorFigure>.generate(
    params.length,
    (i) => IndicatorFigure(
        key: 'ema${i + 1}', title: 'EMA${params[i]}: ', type: 'line'),
  ),
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final figures = indicator.figures;
    var closeSum = 0.0;
    final emaValues = List<double>.filled(params.length, 0);
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final ema = <String, dynamic>{};
      final close = dataList[i].close;
      closeSum += close;
      for (var index = 0; index < params.length; index++) {
        final p = (params[index] as num).toInt();
        if (i >= p - 1) {
          if (i > p - 1) {
            emaValues[index] =
                (2 * close + (p - 1) * emaValues[index]) / (p + 1);
          } else {
            emaValues[index] = closeSum / p;
          }
          ema[figures[index].key] = emaValues[index];
        }
      }
      result.add(ema);
    }
    return result;
  },
);
