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

/// Port of `extension/indicator/simpleMovingAverage.ts` (SMA).
final IndicatorTemplate simpleMovingAverage = IndicatorTemplate(
  name: 'SMA',
  shortName: 'SMA',
  series: 'price',
  calcParams: <dynamic>[12, 2],
  precision: 2,
  shouldOhlc: true,
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'sma', title: 'SMA: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final p0 = (indicator.calcParams[0] as num).toInt();
    final p1 = (indicator.calcParams[1] as num).toInt();
    var closeSum = 0.0;
    var smaValue = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final sma = <String, dynamic>{};
      final close = dataList[i].close;
      closeSum += close;
      if (i >= p0 - 1) {
        if (i > p0 - 1) {
          smaValue = (close * p1 + smaValue * (p0 - p1 + 1)) / (p0 + 1);
        } else {
          smaValue = closeSum / p0;
        }
        sma['sma'] = smaValue;
      }
      result.add(sma);
    }
    return result;
  },
);
