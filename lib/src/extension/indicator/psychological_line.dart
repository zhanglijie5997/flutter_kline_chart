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

/// Port of `extension/indicator/psychologicalLine.ts` (PSY).
final IndicatorTemplate psychologicalLine = IndicatorTemplate(
  name: 'PSY',
  shortName: 'PSY',
  calcParams: <dynamic>[12, 6],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'psy', title: 'PSY: ', type: 'line'),
    IndicatorFigure(key: 'maPsy', title: 'MAPSY: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final param0 = (indicator.calcParams[0] as num).toInt();
    final param1 = (indicator.calcParams[1] as num).toInt();
    var upCount = 0.0;
    var psySum = 0.0;
    final upList = <double>[];
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kLineData = dataList[i];
      final psy = <String, dynamic>{};
      final prevClose = (i - 1 >= 0 ? dataList[i - 1] : kLineData).close;
      final upFlag = kLineData.close - prevClose > 0 ? 1.0 : 0.0;
      upList.add(upFlag);
      upCount += upFlag;
      if (i >= param0 - 1) {
        final psyValue = upCount / param0 * 100;
        psy['psy'] = psyValue;
        psySum += psyValue;
        if (i >= param0 + param1 - 2) {
          psy['maPsy'] = psySum / param1;
          psySum -= (result[i - (param1 - 1)]['psy'] as double? ?? 0.0);
        }
        upCount -= upList[i - (param0 - 1)];
      }
      result.add(psy);
    }
    return result;
  },
);
