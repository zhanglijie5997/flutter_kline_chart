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

/// Port of `extension/indicator/momentum.ts` (MTM).
final IndicatorTemplate momentum = IndicatorTemplate(
  name: 'MTM',
  shortName: 'MTM',
  calcParams: <dynamic>[12, 6],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'mtm', title: 'MTM: ', type: 'line'),
    IndicatorFigure(key: 'maMtm', title: 'MAMTM: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final p0 = (params[0] as num).toInt();
    final p1 = (params[1] as num).toInt();
    var mtmSum = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final mtm = <String, dynamic>{};
      if (i >= p0) {
        final close = dataList[i].close;
        final agoClose = dataList[i - p0].close;
        final mtmValue = close - agoClose;
        mtm['mtm'] = mtmValue;
        mtmSum += mtmValue;
        if (i >= p0 + p1 - 1) {
          mtm['maMtm'] = mtmSum / p1;
          mtmSum -= (result[i - (p1 - 1)]['mtm'] as num?) ?? 0;
        }
      }
      result.add(mtm);
    }
    return result;
  },
);
