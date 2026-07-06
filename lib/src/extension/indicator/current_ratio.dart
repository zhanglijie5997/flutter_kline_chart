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

/// Port of `extension/indicator/currentRatio.ts` (CR).
final IndicatorTemplate currentRatio = IndicatorTemplate(
  name: 'CR',
  shortName: 'CR',
  calcParams: <dynamic>[26, 10, 20, 40, 60],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'cr', title: 'CR: ', type: 'line'),
    IndicatorFigure(key: 'ma1', title: 'MA1: ', type: 'line'),
    IndicatorFigure(key: 'ma2', title: 'MA2: ', type: 'line'),
    IndicatorFigure(key: 'ma3', title: 'MA3: ', type: 'line'),
    IndicatorFigure(key: 'ma4', title: 'MA4: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final p0 = (params[0] as num).toInt();
    final p1 = (params[1] as num).toInt();
    final p2 = (params[2] as num).toInt();
    final p3 = (params[3] as num).toInt();
    final p4 = (params[4] as num).toInt();

    final ma1ForwardPeriod = (p1 / 2.5 + 1).ceil();
    final ma2ForwardPeriod = (p2 / 2.5 + 1).ceil();
    final ma3ForwardPeriod = (p3 / 2.5 + 1).ceil();
    final ma4ForwardPeriod = (p4 / 2.5 + 1).ceil();
    var ma1Sum = 0.0;
    final ma1List = <double>[];
    var ma2Sum = 0.0;
    final ma2List = <double>[];
    var ma3Sum = 0.0;
    final ma3List = <double>[];
    var ma4Sum = 0.0;
    final ma4List = <double>[];
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kLineData = dataList[i];
      final cr = <String, dynamic>{};
      final prevData = i - 1 >= 0 ? dataList[i - 1] : kLineData;
      final prevMid =
          (prevData.high + prevData.close + prevData.low + prevData.open) / 4;

      final highSubPreMid = math.max(0.0, kLineData.high - prevMid);

      final preMidSubLow = math.max(0.0, prevMid - kLineData.low);

      if (i >= p0 - 1) {
        double crValue;
        if (preMidSubLow != 0) {
          crValue = highSubPreMid / preMidSubLow * 100;
        } else {
          crValue = 0.0;
        }
        cr['cr'] = crValue;
        ma1Sum += crValue;
        ma2Sum += crValue;
        ma3Sum += crValue;
        ma4Sum += crValue;
        if (i >= p0 + p1 - 2) {
          ma1List.add(ma1Sum / p1);
          if (i >= p0 + p1 + ma1ForwardPeriod - 3) {
            final idx1 = ma1List.length - 1 - ma1ForwardPeriod;
            if (idx1 >= 0) cr['ma1'] = ma1List[idx1];
          }
          ma1Sum -= (result[i - (p1 - 1)]['cr'] as double?) ?? 0.0;
        }
        if (i >= p0 + p2 - 2) {
          ma2List.add(ma2Sum / p2);
          if (i >= p0 + p2 + ma2ForwardPeriod - 3) {
            final idx2 = ma2List.length - 1 - ma2ForwardPeriod;
            if (idx2 >= 0) cr['ma2'] = ma2List[idx2];
          }
          ma2Sum -= (result[i - (p2 - 1)]['cr'] as double?) ?? 0.0;
        }
        if (i >= p0 + p3 - 2) {
          ma3List.add(ma3Sum / p3);
          if (i >= p0 + p3 + ma3ForwardPeriod - 3) {
            final idx3 = ma3List.length - 1 - ma3ForwardPeriod;
            if (idx3 >= 0) cr['ma3'] = ma3List[idx3];
          }
          ma3Sum -= (result[i - (p3 - 1)]['cr'] as double?) ?? 0.0;
        }
        if (i >= p0 + p4 - 2) {
          ma4List.add(ma4Sum / p4);
          if (i >= p0 + p4 + ma4ForwardPeriod - 3) {
            final idx4 = ma4List.length - 1 - ma4ForwardPeriod;
            if (idx4 >= 0) cr['ma4'] = ma4List[idx4];
          }
          ma4Sum -= (result[i - (p4 - 1)]['cr'] as double?) ?? 0.0;
        }
      }
      result.add(cr);
    }
    return result;
  },
);
