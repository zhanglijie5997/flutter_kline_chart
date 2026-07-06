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

/// Port of `extension/indicator/stoch.ts` (KDJ).
final IndicatorTemplate stoch = IndicatorTemplate(
  name: 'KDJ',
  shortName: 'KDJ',
  calcParams: <dynamic>[9, 3, 3],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'k', title: 'K: ', type: 'line'),
    IndicatorFigure(key: 'd', title: 'D: ', type: 'line'),
    IndicatorFigure(key: 'j', title: 'J: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final p0 = (indicator.calcParams[0] as num).toInt();
    final p1 = (indicator.calcParams[1] as num).toInt();
    final p2 = (indicator.calcParams[2] as num).toInt();
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kdj = <String, dynamic>{};
      final close = dataList[i].close;
      if (i >= p0 - 1) {
        final start = i - (p0 - 1);
        var hn = dataList[start].high;
        var ln = dataList[start].low;
        for (var index = start; index <= i; index++) {
          hn = math.max(hn, dataList[index].high);
          ln = math.min(ln, dataList[index].low);
        }
        final hnSubLn = hn - ln;
        final rsv = (close - ln) / (hnSubLn == 0 ? 1.0 : hnSubLn) * 100;
        final prevK = i - 1 >= 0
            ? (result[i - 1]['k'] as num?)?.toDouble() ?? 50.0
            : 50.0;
        final prevD = i - 1 >= 0
            ? (result[i - 1]['d'] as num?)?.toDouble() ?? 50.0
            : 50.0;
        final k = ((p1 - 1) * prevK + rsv) / p1;
        final d = ((p2 - 1) * prevD + k) / p2;
        final j = 3.0 * k - 2.0 * d;
        kdj['k'] = k;
        kdj['d'] = d;
        kdj['j'] = j;
      }
      result.add(kdj);
    }
    return result;
  },
);
