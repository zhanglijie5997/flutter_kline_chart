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

/// Port of `extension/indicator/bullAndBearIndex.ts` (BBI).
final IndicatorTemplate bullAndBearIndex = IndicatorTemplate(
  name: 'BBI',
  shortName: 'BBI',
  series: 'price',
  precision: 2,
  calcParams: <dynamic>[3, 6, 12, 24],
  shouldOhlc: true,
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'bbi', title: 'BBI: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    var maxPeriod = 0;
    for (final p in params) {
      maxPeriod = math.max(maxPeriod, (p as num).toInt());
    }
    final closeSums = List<double>.filled(params.length, 0);
    final mas = List<double>.filled(params.length, 0);
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final bbi = <String, dynamic>{};
      final close = dataList[i].close;
      for (var index = 0; index < params.length; index++) {
        final p = (params[index] as num).toInt();
        closeSums[index] += close;
        if (i >= p - 1) {
          mas[index] = closeSums[index] / p;
          closeSums[index] -= dataList[i - (p - 1)].close;
        }
      }
      if (i >= maxPeriod - 1) {
        var maSum = 0.0;
        for (final ma in mas) {
          maSum += ma;
        }
        bbi['bbi'] = maSum / 4;
      }
      result.add(bbi);
    }
    return result;
  },
);
