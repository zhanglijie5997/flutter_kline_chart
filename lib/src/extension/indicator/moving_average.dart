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

/// Port of `extension/indicator/movingAverage.ts` (MA).
final IndicatorTemplate movingAverage = IndicatorTemplate(
  name: 'MA',
  shortName: 'MA',
  series: 'price',
  calcParams: <dynamic>[5, 10, 30, 60],
  precision: 2,
  shouldOhlc: true,
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'ma1', title: 'MA5: ', type: 'line'),
    IndicatorFigure(key: 'ma2', title: 'MA10: ', type: 'line'),
    IndicatorFigure(key: 'ma3', title: 'MA30: ', type: 'line'),
    IndicatorFigure(key: 'ma4', title: 'MA60: ', type: 'line'),
  ],
  regenerateFigures: (params) => List<IndicatorFigure>.generate(
    params.length,
    (i) => IndicatorFigure(
        key: 'ma${i + 1}', title: 'MA${params[i]}: ', type: 'line'),
  ),
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final figures = indicator.figures;
    final closeSums = List<double>.filled(params.length, 0);
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final ma = <String, dynamic>{};
      final close = dataList[i].close;
      for (var index = 0; index < params.length; index++) {
        final p = (params[index] as num).toInt();
        closeSums[index] += close;
        if (i >= p - 1) {
          ma[figures[index].key] = closeSums[index] / p;
          closeSums[index] -= dataList[i - (p - 1)].close;
        }
      }
      result.add(ma);
    }
    return result;
  },
);
