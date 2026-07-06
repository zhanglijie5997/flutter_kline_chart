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

/// Port of `extension/indicator/bias.ts` (BIAS).
final IndicatorTemplate bias = IndicatorTemplate(
  name: 'BIAS',
  shortName: 'BIAS',
  calcParams: <dynamic>[6, 12, 24],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'bias1', title: 'BIAS6: ', type: 'line'),
    IndicatorFigure(key: 'bias2', title: 'BIAS12: ', type: 'line'),
    IndicatorFigure(key: 'bias3', title: 'BIAS24: ', type: 'line'),
  ],
  regenerateFigures: (params) => List<IndicatorFigure>.generate(
    params.length,
    (i) => IndicatorFigure(
        key: 'bias${i + 1}', title: 'BIAS${params[i]}: ', type: 'line'),
  ),
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final figures = indicator.figures;
    final closeSums = List<double>.filled(params.length, 0);
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final bias = <String, dynamic>{};
      final close = dataList[i].close;
      for (var index = 0; index < params.length; index++) {
        final p = (params[index] as num).toInt();
        closeSums[index] += close;
        if (i >= p - 1) {
          final mean = closeSums[index] / p;
          bias[figures[index].key] = (close - mean) / mean * 100;
          closeSums[index] -= dataList[i - (p - 1)].close;
        }
      }
      result.add(bias);
    }
    return result;
  },
);
