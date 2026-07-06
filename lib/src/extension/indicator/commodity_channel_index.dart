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

/// Port of `extension/indicator/commodityChannelIndex.ts` (CCI).
///
/// CCI（N日）=（TP－MA）÷MD÷0.015
/// 其中，TP=（最高价+最低价+收盘价）÷3
/// MA=近N日TP价的累计之和÷N
/// MD=近N日TP - 当前MA绝对值的累计之和÷N
final IndicatorTemplate commodityChannelIndex = IndicatorTemplate(
  name: 'CCI',
  shortName: 'CCI',
  calcParams: <dynamic>[20],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'cci', title: 'CCI: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final n = (params[0] as num).toInt();
    final p = n - 1;
    var tpSum = 0.0;
    final tpList = <double>[];
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final cci = <String, dynamic>{};
      final kLineData = dataList[i];
      final tp = (kLineData.high + kLineData.low + kLineData.close) / 3;
      tpSum += tp;
      tpList.add(tp);
      if (i >= p) {
        final maTp = tpSum / n;
        final sliceTpList = tpList.sublist(i - p, i + 1);
        var sum = 0.0;
        for (final t in sliceTpList) {
          sum += (t - maTp).abs();
        }
        final md = sum / n;
        cci['cci'] = md != 0 ? (tp - maTp) / md / 0.015 : 0.0;
        final ago = dataList[i - p];
        final agoTp = (ago.high + ago.low + ago.close) / 3;
        tpSum -= agoTp;
      }
      result.add(cci);
    }
    return result;
  },
);
