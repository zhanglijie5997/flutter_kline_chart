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

import '../../common/utils/format.dart';
import '../../common/utils/type_checks.dart';
import '../../component/indicator.dart';

/// Port of `extension/indicator/volume.ts` (VOL).

IndicatorFigure _volumeFigure() => IndicatorFigure(
      key: 'volume',
      title: 'VOLUME: ',
      type: 'bar',
      baseValue: 0,
      styles: (params) {
        final current = params.data.current;
        final defaultBars = (params.defaultStyles['bars'] as List).first as Map;
        var color = formatValue(params.indicator.styles, 'bars[0].noChangeColor',
            defaultBars['noChangeColor']);
        if (isValid(current)) {
          final close = current!['close'] as num;
          final open = current['open'] as num;
          if (close > open) {
            color = formatValue(params.indicator.styles, 'bars[0].upColor',
                defaultBars['upColor']);
          } else if (close < open) {
            color = formatValue(params.indicator.styles, 'bars[0].downColor',
                defaultBars['downColor']);
          }
        }
        return <String, dynamic>{'color': color};
      },
    );

final IndicatorTemplate volume = IndicatorTemplate(
  name: 'VOL',
  shortName: 'VOL',
  series: 'volume',
  calcParams: <dynamic>[5, 10, 20],
  shouldFormatBigNumber: true,
  precision: 0,
  minValue: 0,
  figures: <IndicatorFigure>[
    const IndicatorFigure(key: 'ma1', title: 'MA5: ', type: 'line'),
    const IndicatorFigure(key: 'ma2', title: 'MA10: ', type: 'line'),
    const IndicatorFigure(key: 'ma3', title: 'MA20: ', type: 'line'),
    _volumeFigure(),
  ],
  regenerateFigures: (params) {
    final figures = List<IndicatorFigure>.generate(
      params.length,
      (i) => IndicatorFigure(
          key: 'ma${i + 1}', title: 'MA${params[i]}: ', type: 'line'),
    );
    figures.add(_volumeFigure());
    return figures;
  },
  calc: (dataList, indicator) {
    final params = indicator.calcParams;
    final figures = indicator.figures;
    final volSums = List<double>.filled(params.length, 0);
    final result = <Map<String, dynamic>>[];
    for (var i = 0; i < dataList.length; i++) {
      final volume = dataList[i].volume ?? 0;
      final vol = <String, dynamic>{
        'volume': volume,
        'open': dataList[i].open,
        'close': dataList[i].close,
      };
      for (var index = 0; index < params.length; index++) {
        final p = (params[index] as num).toInt();
        volSums[index] += volume;
        if (i >= p - 1) {
          vol[figures[index].key] = volSums[index] / p;
          volSums[index] -= dataList[i - (p - 1)].volume ?? 0;
        }
      }
      result.add(vol);
    }
    return result;
  },
);
