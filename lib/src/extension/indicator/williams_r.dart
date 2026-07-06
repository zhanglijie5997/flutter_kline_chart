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

/// Port of `extension/indicator/williamsR.ts` (WR).
///
/// WR(N) = 100 * [ C - HIGH(N) ] / [ HIGH(N) - LOW(N) ]
final IndicatorTemplate williamsR = IndicatorTemplate(
  name: 'WR',
  shortName: 'WR',
  calcParams: <dynamic>[6, 10, 14],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'wr1', title: 'WR1: ', type: 'line'),
    IndicatorFigure(key: 'wr2', title: 'WR2: ', type: 'line'),
    IndicatorFigure(key: 'wr3', title: 'WR3: ', type: 'line'),
  ],
  regenerateFigures: (params) => List<IndicatorFigure>.generate(
    params.length,
    (i) => IndicatorFigure(
        key: 'wr${i + 1}', title: 'WR${i + 1}: ', type: 'line'),
  ),
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final figures = indicator.figures;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final wr = <String, dynamic>{};
      final close = dataList[i].close;
      for (var index = 0; index < params.length; index++) {
        final p = (params[index] as num).toInt() - 1;
        if (i >= p) {
          var hn = -double.maxFinite;
          var ln = double.maxFinite;
          for (var j = i - p; j <= i; j++) {
            hn = math.max(dataList[j].high, hn);
            ln = math.min(dataList[j].low, ln);
          }
          final hnSubLn = hn - ln;
          wr[figures[index].key] =
              hnSubLn == 0 ? 0.0 : (close - hn) / hnSubLn * 100;
        }
      }
      result.add(wr);
    }
    return result;
  },
);
