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

/// Port of `extension/indicator/onBalanceVolume.ts` (OBV).
///
/// OBV = REF(OBV) + sign * V
final IndicatorTemplate onBalanceVolume = IndicatorTemplate(
  name: 'OBV',
  shortName: 'OBV',
  calcParams: <dynamic>[30],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'obv', title: 'OBV: ', type: 'line'),
    IndicatorFigure(key: 'maObv', title: 'MAOBV: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final p = (indicator.calcParams[0] as num).toInt();
    var obvSum = 0.0;
    var oldObv = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kLineData = dataList[i];
      final prevKLineData = i - 1 >= 0 ? dataList[i - 1] : kLineData;
      if (kLineData.close < prevKLineData.close) {
        oldObv -= (kLineData.volume ?? 0);
      } else if (kLineData.close > prevKLineData.close) {
        oldObv += (kLineData.volume ?? 0);
      }
      final obv = <String, dynamic>{'obv': oldObv};
      obvSum += oldObv;
      if (i >= p - 1) {
        obv['maObv'] = obvSum / p;
        obvSum -= (result[i - (p - 1)]['obv'] as num? ?? 0);
      }
      result.add(obv);
    }
    return result;
  },
);
