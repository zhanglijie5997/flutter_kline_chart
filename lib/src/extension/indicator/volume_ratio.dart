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

/// Port of `extension/indicator/volumeRatio.ts` (VR).
final IndicatorTemplate volumeRatio = IndicatorTemplate(
  name: 'VR',
  shortName: 'VR',
  calcParams: <dynamic>[26, 6],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'vr', title: 'VR: ', type: 'line'),
    IndicatorFigure(key: 'maVr', title: 'MAVR: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final p0 = (indicator.calcParams[0] as num).toInt();
    final p1 = (indicator.calcParams[1] as num).toInt();
    var uvs = 0.0;
    var dvs = 0.0;
    var pvs = 0.0;
    var vrSum = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final vr = <String, dynamic>{};
      final close = dataList[i].close;
      final preClose = (i - 1 >= 0 ? dataList[i - 1] : dataList[i]).close;
      final volume = dataList[i].volume ?? 0;
      if (close > preClose) {
        uvs += volume;
      } else if (close < preClose) {
        dvs += volume;
      } else {
        pvs += volume;
      }
      if (i >= p0 - 1) {
        final halfPvs = pvs / 2;
        double vrValue;
        if (dvs + halfPvs == 0) {
          vrValue = 0;
        } else {
          vrValue = (uvs + halfPvs) / (dvs + halfPvs) * 100;
        }
        vr['vr'] = vrValue;
        vrSum += vrValue;
        if (i >= p0 + p1 - 2) {
          vr['maVr'] = vrSum / p1;
          vrSum -= (result[i - (p1 - 1)]['vr'] as double?) ?? 0;
        }

        final agoData = dataList[i - (p0 - 1)];
        final agoPreData = i - p0 >= 0 ? dataList[i - p0] : agoData;
        final agoClose = agoData.close;
        final agoVolume = agoData.volume ?? 0;
        if (agoClose > agoPreData.close) {
          uvs -= agoVolume;
        } else if (agoClose < agoPreData.close) {
          dvs -= agoVolume;
        } else {
          pvs -= agoVolume;
        }
      }
      result.add(vr);
    }
    return result;
  },
);
