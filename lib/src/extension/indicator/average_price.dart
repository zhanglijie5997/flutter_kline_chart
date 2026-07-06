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

/// Port of `extension/indicator/averagePrice.ts` (AVP).
final IndicatorTemplate averagePrice = IndicatorTemplate(
  name: 'AVP',
  shortName: 'AVP',
  series: 'price',
  precision: 2,
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'avp', title: 'AVP: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    var totalTurnover = 0.0;
    var totalVolume = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final avp = <String, dynamic>{};
      final turnover = dataList[i].turnover ?? 0;
      final volume = dataList[i].volume ?? 0;
      totalTurnover += turnover;
      totalVolume += volume;
      if (totalVolume != 0) {
        avp['avp'] = totalTurnover / totalVolume;
      }
      result.add(avp);
    }
    return result;
  },
);
