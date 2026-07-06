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

/// Port of `extension/indicator/relativeStrengthIndex.ts` (RSI).
///
/// RSI = 100 - 100 / (1 + RMA(MAX(CHANGE(CLOSE), 0), N) / RMA(MAX(-CHANGE(CLOSE), 0), N))
final IndicatorTemplate relativeStrengthIndex = IndicatorTemplate(
  name: 'RSI',
  shortName: 'RSI',
  calcParams: <dynamic>[6, 12, 24],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'rsi1', title: 'RSI1: ', type: 'line'),
    IndicatorFigure(key: 'rsi2', title: 'RSI2: ', type: 'line'),
    IndicatorFigure(key: 'rsi3', title: 'RSI3: ', type: 'line'),
  ],
  regenerateFigures: (params) => List<IndicatorFigure>.generate(
    params.length,
    (i) => IndicatorFigure(
        key: 'rsi${i + 1}', title: 'RSI${i + 1}: ', type: 'line'),
  ),
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final figures = indicator.figures;
    final gainSums = List<double>.filled(params.length, 0);
    final lossSums = List<double>.filled(params.length, 0);
    final avgGains = List<double?>.filled(params.length, null);
    final avgLosses = List<double?>.filled(params.length, null);
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final rsi = <String, dynamic>{};
      final change = i == 0 ? 0.0 : dataList[i].close - dataList[i - 1].close;
      final gain = math.max(change, 0.0);
      final loss = math.max(-change, 0.0);
      for (var index = 0; index < params.length; index++) {
        final p = (params[index] as num).toInt();
        gainSums[index] += gain;
        lossSums[index] += loss;

        if (i < p) {
          continue;
        }

        if (avgGains[index] == null || avgLosses[index] == null) {
          avgGains[index] = gainSums[index] / p;
          avgLosses[index] = lossSums[index] / p;
        } else {
          avgGains[index] = (avgGains[index]! * (p - 1) + gain) / p;
          avgLosses[index] = (avgLosses[index]! * (p - 1) + loss) / p;
        }

        if (avgLosses[index] == 0) {
          rsi[figures[index].key] = 100;
        } else if (avgGains[index] == 0) {
          rsi[figures[index].key] = 0;
        } else {
          rsi[figures[index].key] =
              100 - (100 / (1 + avgGains[index]! / avgLosses[index]!));
        }
      }
      result.add(rsi);
    }
    return result;
  },
);
