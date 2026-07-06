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

/// Port of `extension/indicator/tripleExponentiallySmoothedAverage.ts` (TRIX).
final IndicatorTemplate tripleExponentiallySmoothedAverage = IndicatorTemplate(
  name: 'TRIX',
  shortName: 'TRIX',
  calcParams: <dynamic>[12, 9],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'trix', title: 'TRIX: ', type: 'line'),
    IndicatorFigure(key: 'maTrix', title: 'MATRIX: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final p0 = (indicator.calcParams[0] as num).toInt();
    final p1 = (indicator.calcParams[1] as num).toInt();
    var closeSum = 0.0;
    var ema1 = 0.0;
    var ema2 = 0.0;
    var oldTr = 0.0;
    var ema1Sum = 0.0;
    var ema2Sum = 0.0;
    var trixSum = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final trix = <String, dynamic>{};
      final close = dataList[i].close;
      closeSum += close;
      if (i >= p0 - 1) {
        if (i > p0 - 1) {
          ema1 = (2 * close + (p0 - 1) * ema1) / (p0 + 1);
        } else {
          ema1 = closeSum / p0;
        }
        ema1Sum += ema1;
        if (i >= p0 * 2 - 2) {
          if (i > p0 * 2 - 2) {
            ema2 = (2 * ema1 + (p0 - 1) * ema2) / (p0 + 1);
          } else {
            ema2 = ema1Sum / p0;
          }
          ema2Sum += ema2;
          if (i >= p0 * 3 - 3) {
            var tr = 0.0;
            var trixValue = 0.0;
            if (i > p0 * 3 - 3) {
              tr = (2 * ema2 + (p0 - 1) * oldTr) / (p0 + 1);
              trixValue = (tr - oldTr) / oldTr * 100;
            } else {
              tr = ema2Sum / p0;
            }
            oldTr = tr;
            trix['trix'] = trixValue;
            trixSum += trixValue;
            if (i >= p0 * 3 + p1 - 4) {
              trix['maTrix'] = trixSum / p1;
              trixSum -= (result[i - (p1 - 1)]['trix'] as num?) ?? 0;
            }
          }
        }
      }
      result.add(trix);
    }
    return result;
  },
);
