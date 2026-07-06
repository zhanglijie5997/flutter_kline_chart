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

/// Port of `extension/indicator/awesomeOscillator.ts` (AO).

const int _minSafeInteger = -9007199254740991;

final IndicatorTemplate awesomeOscillator = IndicatorTemplate(
  name: 'AO',
  shortName: 'AO',
  calcParams: <dynamic>[5, 34],
  figures: <IndicatorFigure>[
    IndicatorFigure(
      key: 'ao',
      title: 'AO: ',
      type: 'bar',
      baseValue: 0,
      styles: (params) {
        final prev = params.data.prev;
        final current = params.data.current;
        final prevAo = (prev?['ao'] as num?) ?? _minSafeInteger;
        final currentAo = (current?['ao'] as num?) ?? _minSafeInteger;
        final defaultBars = (params.defaultStyles['bars'] as List).first as Map;
        dynamic color;
        if (currentAo > prevAo) {
          color = formatValue(params.indicator.styles, 'bars[0].upColor',
              defaultBars['upColor']);
        } else {
          color = formatValue(params.indicator.styles, 'bars[0].downColor',
              defaultBars['downColor']);
        }
        final style = currentAo > prevAo ? 'stroke' : 'fill';
        return <String, dynamic>{
          'color': color,
          'style': style,
          'borderColor': color,
        };
      },
    ),
  ],
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final p0 = (params[0] as num).toInt();
    final p1 = (params[1] as num).toInt();
    final maxPeriod = math.max(p0, p1);
    var shortSum = 0.0;
    var longSum = 0.0;
    var short = 0.0;
    var long = 0.0;
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final kLineData = dataList[i];
      final ao = <String, dynamic>{};
      final middle = (kLineData.low + kLineData.high) / 2;
      shortSum += middle;
      longSum += middle;
      if (i >= p0 - 1) {
        short = shortSum / p0;
        final agoKLineData = dataList[i - (p0 - 1)];
        shortSum -= (agoKLineData.low + agoKLineData.high) / 2;
      }
      if (i >= p1 - 1) {
        long = longSum / p1;
        final agoKLineData = dataList[i - (p1 - 1)];
        longSum -= (agoKLineData.low + agoKLineData.high) / 2;
      }
      if (i >= maxPeriod - 1) {
        ao['ao'] = short - long;
      }
      result.add(ao);
    }
    return result;
  },
);
