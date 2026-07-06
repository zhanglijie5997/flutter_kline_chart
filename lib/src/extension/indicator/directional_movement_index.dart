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

/// Port of `extension/indicator/directionalMovementIndex.ts` (DMI).
final IndicatorTemplate directionalMovementIndex = IndicatorTemplate(
  name: 'DMI',
  shortName: 'DMI',
  calcParams: <dynamic>[14, 6],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'pdi', title: 'PDI: ', type: 'line'),
    IndicatorFigure(key: 'mdi', title: 'MDI: ', type: 'line'),
    IndicatorFigure(key: 'adx', title: 'ADX: ', type: 'line'),
    IndicatorFigure(key: 'adxr', title: 'ADXR: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params0 = (indicator.calcParams[0] as num).toInt();
    final params1 = (indicator.calcParams[1] as num).toInt();
    var trSum = 0.0;
    var hSum = 0.0;
    var lSum = 0.0;
    var mtr = 0.0;
    var dmp = 0.0;
    var dmm = 0.0;
    var dxSum = 0.0;
    var adx = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kLineData = dataList[i];
      final dmi = <String, dynamic>{};
      final prevKLineData = i - 1 >= 0 ? dataList[i - 1] : kLineData;
      final preClose = prevKLineData.close;
      final high = kLineData.high;
      final low = kLineData.low;
      final hl = high - low;
      final hcy = (high - preClose).abs();
      final lcy = (preClose - low).abs();
      final hhy = high - prevKLineData.high;
      final lyl = prevKLineData.low - low;
      final tr = math.max(math.max(hl, hcy), lcy);
      final h = (hhy > 0 && hhy > lyl) ? hhy : 0.0;
      final l = (lyl > 0 && lyl > hhy) ? lyl : 0.0;
      trSum += tr;
      hSum += h;
      lSum += l;
      if (i >= params0 - 1) {
        if (i > params0 - 1) {
          mtr = mtr - mtr / params0 + tr;
          dmp = dmp - dmp / params0 + h;
          dmm = dmm - dmm / params0 + l;
        } else {
          mtr = trSum;
          dmp = hSum;
          dmm = lSum;
        }
        var pdi = 0.0;
        var mdi = 0.0;
        if (mtr != 0) {
          pdi = dmp * 100 / mtr;
          mdi = dmm * 100 / mtr;
        }
        dmi['pdi'] = pdi;
        dmi['mdi'] = mdi;
        var dx = 0.0;
        if (mdi + pdi != 0) {
          dx = (mdi - pdi).abs() / (mdi + pdi) * 100;
        }
        dxSum += dx;
        if (i >= params0 * 2 - 2) {
          if (i > params0 * 2 - 2) {
            adx = (adx * (params0 - 1) + dx) / params0;
          } else {
            adx = dxSum / params0;
          }
          dmi['adx'] = adx;
          if (i >= params0 * 2 + params1 - 3) {
            dmi['adxr'] =
                (((result[i - (params1 - 1)]['adx'] as num?) ?? 0) + adx) / 2;
          }
        }
      }
      result.add(dmi);
    }
    return result;
  },
);
