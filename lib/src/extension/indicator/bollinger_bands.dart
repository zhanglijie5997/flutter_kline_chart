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

import '../../common/data.dart';
import '../../component/indicator.dart';

/// Port of `extension/indicator/bollingerBands.ts` (BOLL).

/// Calculate the standard deviation used by the BOLL indicator.
double _getBollMd(List<KLineData> dataList, double ma) {
  final dataSize = dataList.length;
  var sum = 0.0;
  for (final data in dataList) {
    final closeMa = data.close - ma;
    sum += closeMa * closeMa;
  }
  sum = sum.abs();
  return math.sqrt(sum / dataSize);
}

final IndicatorTemplate bollingerBands = IndicatorTemplate(
  name: 'BOLL',
  shortName: 'BOLL',
  series: 'price',
  calcParams: <dynamic>[20, 2],
  precision: 2,
  shouldOhlc: true,
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'up', title: 'UP: ', type: 'line'),
    IndicatorFigure(key: 'mid', title: 'MID: ', type: 'line'),
    IndicatorFigure(key: 'dn', title: 'DN: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final p = (params[0] as num).toInt() - 1;
    var closeSum = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final close = dataList[i].close;
      final boll = <String, dynamic>{};
      closeSum += close;
      if (i >= p) {
        final mid = closeSum / (params[0] as num).toInt();
        boll['mid'] = mid;
        final md = _getBollMd(dataList.sublist(i - p, i + 1), mid);
        boll['up'] = mid + (params[1] as num).toInt() * md;
        boll['dn'] = mid - (params[1] as num).toInt() * md;
        closeSum -= dataList[i - p].close;
      }
      result.add(boll);
    }
    return result;
  },
);
