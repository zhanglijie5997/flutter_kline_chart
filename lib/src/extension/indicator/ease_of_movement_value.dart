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

/// Port of `extension/indicator/easeOfMovementValue.ts` (EMV).
final IndicatorTemplate easeOfMovementValue = IndicatorTemplate(
  name: 'EMV',
  shortName: 'EMV',
  calcParams: <dynamic>[14, 9],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'emv', title: 'EMV: ', type: 'line'),
    IndicatorFigure(key: 'maEmv', title: 'MAEMV: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final p0 = (params[0] as num).toInt();
    var emvValueSum = 0.0;
    final emvValueList = <double>[];
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final emv = <String, dynamic>{};
      if (i > 0) {
        final prevKLineData = dataList[i - 1];
        final high = dataList[i].high;
        final low = dataList[i].low;
        final volume = dataList[i].volume ?? 0;
        final distanceMoved =
            (high + low) / 2 - (prevKLineData.high + prevKLineData.low) / 2;

        double emvValue;
        if (volume == 0 || high - low == 0) {
          emvValue = 0.0;
        } else {
          final ratio = volume / 100000000 / (high - low);
          emvValue = distanceMoved / ratio;
        }
        emv['emv'] = emvValue;
        emvValueSum += emvValue;
        emvValueList.add(emvValue);
        if (i >= p0) {
          emv['maEmv'] = emvValueSum / p0;
          emvValueSum -= emvValueList[i - p0];
        }
      }
      result.add(emv);
    }
    return result;
  },
);
