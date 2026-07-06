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

/// Port of `extension/indicator/rateOfChange.ts` (ROC).
final IndicatorTemplate rateOfChange = IndicatorTemplate(
  name: 'ROC',
  shortName: 'ROC',
  calcParams: <dynamic>[12, 6],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'roc', title: 'ROC: ', type: 'line'),
    IndicatorFigure(key: 'maRoc', title: 'MAROC: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final p0 = (params[0] as num).toInt();
    final p1 = (params[1] as num).toInt();
    final result = <Map<String, dynamic>>[];
    var rocSum = 0.0;
    for (var i = 0; i < dataList.length; i++) {
      final roc = <String, dynamic>{};
      if (i >= p0 - 1) {
        final close = dataList[i].close;
        final agoIndex = i - p0;
        final agoClose = agoIndex >= 0
            ? dataList[agoIndex].close
            : dataList[i - (p0 - 1)].close;
        double rocValue;
        if (agoClose != 0) {
          rocValue = (close - agoClose) / agoClose * 100;
        } else {
          rocValue = 0;
        }
        roc['roc'] = rocValue;
        rocSum += rocValue;
        if (i >= p0 - 1 + p1 - 1) {
          roc['maRoc'] = rocSum / p1;
          rocSum -= ((result[i - (p1 - 1)]['roc'] as num?) ?? 0).toDouble();
        }
      }
      result.add(roc);
    }
    return result;
  },
);
