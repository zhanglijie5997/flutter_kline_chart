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

/// Port of `extension/indicator/brar.ts` (BRAR).
final IndicatorTemplate brar = IndicatorTemplate(
  name: 'BRAR',
  shortName: 'BRAR',
  calcParams: <dynamic>[26],
  figures: const <IndicatorFigure>[
    IndicatorFigure(key: 'br', title: 'BR: ', type: 'line'),
    IndicatorFigure(key: 'ar', title: 'AR: ', type: 'line'),
  ],
  calc: (dataList, indicator) {
    final p = (indicator.calcParams[0] as num).toInt();
    var hcy = 0.0;
    var cyl = 0.0;
    var ho = 0.0;
    var ol = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kLineData = dataList[i];
      final brar = <String, dynamic>{};
      final high = kLineData.high;
      final low = kLineData.low;
      final open = kLineData.open;
      final prevClose = (i - 1 >= 0 ? dataList[i - 1] : kLineData).close;
      ho += (high - open);
      ol += (open - low);
      hcy += (high - prevClose);
      cyl += (prevClose - low);
      if (i >= p - 1) {
        if (ol != 0) {
          brar['ar'] = ho / ol * 100;
        } else {
          brar['ar'] = 0;
        }
        if (cyl != 0) {
          brar['br'] = hcy / cyl * 100;
        } else {
          brar['br'] = 0;
        }
        final agoKLineData = dataList[i - (p - 1)];
        final agoHigh = agoKLineData.high;
        final agoLow = agoKLineData.low;
        final agoOpen = agoKLineData.open;
        final agoPreClose =
            (i - p >= 0 ? dataList[i - p] : dataList[i - (p - 1)]).close;
        hcy -= (agoHigh - agoPreClose);
        cyl -= (agoPreClose - agoLow);
        ho -= (agoHigh - agoOpen);
        ol -= (agoOpen - agoLow);
      }
      result.add(brar);
    }
    return result;
  },
);
