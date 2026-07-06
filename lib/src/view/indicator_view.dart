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

import '../common/coordinate.dart';
import '../common/ctx.dart';
import '../common/data.dart';
import '../common/utils/style.dart';
import '../common/utils/type_checks.dart';
import '../component/indicator.dart';
import '../extension/figure/circle.dart';
import '../extension/figure/line.dart';
import '../extension/figure/rect.dart';
import '../extension/figure/text.dart';
import 'render_context.dart';

class _LineSeg {
  final List<Coordinate> coordinates;
  final Map<String, dynamic> styles;
  _LineSeg(this.coordinates, this.styles);
}

/// Port of `view/IndicatorView.ts` — draws indicator figures.
void drawIndicators(Ctx ctx, PaneRenderContext c) {
  final store = c.store;
  final xAxis = c.xAxis;
  final yAxis = c.yAxis;
  final bounding = c.content;
  final indicators = store.getIndicatorsByPaneId(c.paneId);
  final defaultStyles = asMap(store.getStyles()['indicator']);
  final barSpace = store.getBarSpace();
  final visible = store.getVisibleRangeDataList();

  for (final indicator in indicators) {
    if (!indicator.visible) continue;
    final result = indicator.result;
    final lines = <int, List<_LineSeg>>{};

    for (final data in visible) {
      final dataIndex = data.dataIndex;
      final x = data.x;
      final halfGapBar = barSpace.halfGapBar;
      final prevX = xAxis.convertToPixel((dataIndex - 1).toDouble());
      final nextX = xAxis.convertToPixel((dataIndex + 1).toDouble());
      final prevData =
          dataIndex - 1 >= 0 && dataIndex - 1 < result.length ? result[dataIndex - 1] : null;
      final currentData =
          dataIndex >= 0 && dataIndex < result.length ? result[dataIndex] : null;
      final nextData = dataIndex + 1 >= 0 && dataIndex + 1 < result.length
          ? result[dataIndex + 1]
          : null;

      final prevCoordinate = <String, double>{'x': prevX};
      final currentCoordinate = <String, double>{'x': x};
      final nextCoordinate = <String, double>{'x': nextX};
      for (final figure in indicator.figures) {
        final pv = prevData?[figure.key];
        if (pv is num && pv.isFinite) {
          prevCoordinate[figure.key] = yAxis.convertToPixel(pv.toDouble());
        }
        final cv = currentData?[figure.key];
        if (cv is num && cv.isFinite) {
          currentCoordinate[figure.key] = yAxis.convertToPixel(cv.toDouble());
        }
        final nv = nextData?[figure.key];
        if (nv is num && nv.isFinite) {
          nextCoordinate[figure.key] = yAxis.convertToPixel(nv.toDouble());
        }
      }

      eachFigures(indicator, dataIndex, barSpace, defaultStyles,
          (figure, figureStyles, figureIndex) {
        final currentValue = currentData?[figure.key];
        if (!isValid(currentValue)) return;
        final valueY = currentCoordinate[figure.key];

        Map<String, dynamic>? attrs;
        if (figure.attrs != null) {
          attrs = figure.attrs!(IndicatorFigureAttrsCallbackParams(
            data: NeighborData<Map<String, dynamic>?>(
                prev: prevData, current: currentData, next: nextData),
            coordinate: NeighborData<Map<String, dynamic>>(
                prev: prevCoordinate, current: currentCoordinate, next: nextCoordinate),
            bounding: bounding,
            barSpace: barSpace,
            xAxis: xAxis,
            yAxis: yAxis,
          ));
        }

        switch (figure.type) {
          case 'text':
            if (valueY != null) {
              drawText(
                  ctx,
                  TextAttrs(
                    x: x,
                    y: valueY,
                    text: '$currentValue',
                    align: 'center',
                    baseline: 'middle',
                  ),
                  figureStyles);
            }
            break;
          case 'circle':
            if (valueY != null) {
              drawCircle(
                  ctx,
                  CircleAttrs(x: x, y: valueY, r: math.max(1, halfGapBar)),
                  figureStyles);
            }
            break;
          case 'rect':
          case 'bar':
            if (valueY != null) {
              final baseValue =
                  (figure.baseValue ?? yAxis.getRange().from).toDouble();
              final baseValueY = yAxis.convertToPixel(baseValue);
              var height = (baseValueY - valueY).abs();
              if (baseValue != currentValue) {
                height = math.max(1, height);
              }
              final y = valueY > baseValueY ? baseValueY : valueY;
              final barWidth = asDoubleOrNull(attrs?['width']) ?? halfGapBar * 2;
              drawRect(
                  ctx,
                  RectAttrs(
                    x: x - barWidth / 2,
                    y: y,
                    width: math.max(1, barWidth),
                    height: height,
                  ),
                  figureStyles);
            }
            break;
          case 'line':
            final cy = currentCoordinate[figure.key];
            final ny = nextCoordinate[figure.key];
            if (cy != null && ny != null) {
              lines.putIfAbsent(figureIndex, () => <_LineSeg>[]).add(_LineSeg(
                    <Coordinate>[
                      Coordinate(x: currentCoordinate['x']!, y: cy),
                      Coordinate(x: nextCoordinate['x']!, y: ny),
                    ],
                    figureStyles,
                  ));
            }
            break;
        }
      });
    }

    // merge and render lines
    lines.forEach((_, items) {
      if (items.length > 1) {
        final mergeLines = <_LineSeg>[
          _LineSeg(<Coordinate>[items[0].coordinates[0], items[0].coordinates[1]],
              items[0].styles)
        ];
        for (var i = 1; i < items.length; i++) {
          final lastMerge = mergeLines.last;
          final current = items[i];
          final lastCoord = lastMerge.coordinates.last;
          if (lastCoord.x == current.coordinates[0].x &&
              lastCoord.y == current.coordinates[0].y &&
              lastMerge.styles['style'] == current.styles['style'] &&
              lastMerge.styles['color'] == current.styles['color'] &&
              lastMerge.styles['size'] == current.styles['size'] &&
              lastMerge.styles['smooth'] == current.styles['smooth']) {
            lastMerge.coordinates.add(current.coordinates[1]);
          } else {
            mergeLines.add(_LineSeg(
                <Coordinate>[current.coordinates[0], current.coordinates[1]],
                current.styles));
          }
        }
        for (final seg in mergeLines) {
          drawLine(ctx, LineAttrs(seg.coordinates), seg.styles);
        }
      }
    });
  }
}
