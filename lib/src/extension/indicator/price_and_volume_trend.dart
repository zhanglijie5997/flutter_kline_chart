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

/// Port of `extension/indicator/priceAndVolumeTrend.ts` (PVT).
final IndicatorTemplate priceAndVolumeTrend = IndicatorTemplate(
  name: 'PVT',
  shortName: 'PVT',
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'pvt', title: 'PVT: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    var sum = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final pvt = <String, dynamic>{};
      final close = dataList[i].close;
      final volume = dataList[i].volume ?? 1;
      final prevClose = (i - 1 >= 0 ? dataList[i - 1] : dataList[i]).close;
      var x = 0.0;
      final total = prevClose * volume;
      if (total != 0) {
        x = (close - prevClose) / total;
      }
      sum += x;
      pvt['pvt'] = sum;
      result.add(pvt);
    }
    return result;
  },
);
