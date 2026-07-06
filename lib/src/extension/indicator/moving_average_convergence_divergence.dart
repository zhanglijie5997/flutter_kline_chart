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

import '../../common/utils/format.dart';
import '../../component/indicator.dart';

/// Port of `extension/indicator/movingAverageConvergenceDivergence.ts` (MACD).
final IndicatorTemplate movingAverageConvergenceDivergence = IndicatorTemplate(
  name: 'MACD',
  shortName: 'MACD',
  calcParams: <dynamic>[12, 26, 9],
  figures: <IndicatorFigure>[
    const IndicatorFigure(key: 'dif', title: 'DIF: ', type: 'line'),
    const IndicatorFigure(key: 'dea', title: 'DEA: ', type: 'line'),
    IndicatorFigure(
      key: 'macd',
      title: 'MACD: ',
      type: 'bar',
      baseValue: 0,
      styles: (params) {
        final current = params.data.current;
        final prev = params.data.prev;
        const minSafeInteger = -9007199254740991;
        final num prevMacd = (prev != null && prev['macd'] is num)
            ? prev['macd'] as num
            : minSafeInteger;
        final num currentMacd = (current != null && current['macd'] is num)
            ? current['macd'] as num
            : minSafeInteger;
        final defaultBars = (params.defaultStyles['bars'] as List).first as Map;
        Object? color;
        if (currentMacd > 0) {
          color = formatValue(
              params.indicator.styles, 'bars[0].upColor', defaultBars['upColor']);
        } else if (currentMacd < 0) {
          color = formatValue(params.indicator.styles, 'bars[0].downColor',
              defaultBars['downColor']);
        } else {
          color = formatValue(params.indicator.styles, 'bars[0].noChangeColor',
              defaultBars['noChangeColor']);
        }
        final style = prevMacd < currentMacd ? 'stroke' : 'fill';
        return <String, dynamic>{
          'style': style,
          'color': color,
          'borderColor': color,
        };
      },
    ),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final p0 = (params[0] as num).toInt();
    final p1 = (params[1] as num).toInt();
    final p2 = (params[2] as num).toInt();
    var closeSum = 0.0;
    var emaShort = 0.0;
    var emaLong = 0.0;
    var dif = 0.0;
    var difSum = 0.0;
    var dea = 0.0;
    final maxPeriod = math.max(p0, p1);
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final macd = <String, dynamic>{};
      final close = dataList[i].close;
      closeSum += close;
      if (i >= p0 - 1) {
        if (i > p0 - 1) {
          emaShort = (2 * close + (p0 - 1) * emaShort) / (p0 + 1);
        } else {
          emaShort = closeSum / p0;
        }
      }
      if (i >= p1 - 1) {
        if (i > p1 - 1) {
          emaLong = (2 * close + (p1 - 1) * emaLong) / (p1 + 1);
        } else {
          emaLong = closeSum / p1;
        }
      }
      if (i >= maxPeriod - 1) {
        dif = emaShort - emaLong;
        macd['dif'] = dif;
        difSum += dif;
        if (i >= maxPeriod + p2 - 2) {
          if (i > maxPeriod + p2 - 2) {
            dea = (dif * 2 + dea * (p2 - 1)) / (p2 + 1);
          } else {
            dea = difSum / p2;
          }
          macd['macd'] = (dif - dea) * 2;
          macd['dea'] = dea;
        }
      }
      result.add(macd);
    }
    return result;
  },
);
