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

import '../common/bounding.dart';
import '../common/coordinate.dart';
import '../common/ctx.dart';
import '../common/utils/style.dart';
import '../component/axis.dart';
import '../extension/figure/line.dart';
import '../extension/figure/text.dart';

/// Port of `view/YAxisView.ts` — drawn translated to the gutter origin.
void drawYAxis(Ctx ctx, YAxisImp yAxis, Bounding bounding,
    Map<String, dynamic> styles) {
  final yAxisStyles = asMap(styles['yAxis']);
  if (!asBool(yAxisStyles['show'], true)) {
    return;
  }
  final axisLine = asMap(yAxisStyles['axisLine']);
  final tickLine = asMap(yAxisStyles['tickLine']);
  final tickText = asMap(yAxisStyles['tickText']);
  final fromZero = yAxis.isFromZero();
  final axisLineSize = asDouble(axisLine['size'], 1);

  if (asBool(axisLine['show'], true)) {
    final x = fromZero ? 0.0 : bounding.width - axisLineSize;
    drawLine(
        ctx,
        LineAttrs(<Coordinate>[
          Coordinate(x: x, y: 0),
          Coordinate(x: x, y: bounding.height),
        ]),
        axisLine);
  }

  final ticks = yAxis.getTicks();
  if (asBool(tickLine['show'], true)) {
    final tickLength = asDouble(tickLine['length'], 3);
    double startX;
    double endX;
    if (fromZero) {
      startX = asBool(axisLine['show'], true) ? axisLineSize : 0;
      endX = startX + tickLength;
    } else {
      startX = bounding.width - (asBool(axisLine['show'], true) ? axisLineSize : 0);
      endX = startX - tickLength;
    }
    final lines = ticks
        .map((tick) => LineAttrs(<Coordinate>[
              Coordinate(x: startX, y: tick.coord),
              Coordinate(x: endX, y: tick.coord),
            ]))
        .toList();
    for (final l in lines) {
      drawLine(ctx, l, tickLine);
    }
  }

  if (asBool(tickText['show'], true)) {
    final marginStart = asDouble(tickText['marginStart'], 4);
    final marginEnd = asDouble(tickText['marginEnd'], 6);
    final tickLength = asDouble(tickLine['length'], 3);
    double x;
    if (fromZero) {
      x = marginStart +
          (asBool(axisLine['show'], true) ? axisLineSize : 0) +
          (asBool(tickLine['show'], true) ? tickLength : 0);
    } else {
      x = bounding.width -
          marginEnd -
          (asBool(axisLine['show'], true) ? axisLineSize : 0) -
          (asBool(tickLine['show'], true) ? tickLength : 0);
    }
    final align = fromZero ? 'left' : 'right';
    final texts = ticks
        .map((tick) => TextAttrs(
            x: x, y: tick.coord, text: tick.text, align: align, baseline: 'middle'))
        .toList();
    drawText(ctx, texts, tickText);
  }
}

/// Port of `view/XAxisView.ts` — drawn translated to the x-axis pane origin.
void drawXAxis(
    Ctx ctx, XAxisImp xAxis, Bounding bounding, Map<String, dynamic> styles) {
  final xAxisStyles = asMap(styles['xAxis']);
  if (!asBool(xAxisStyles['show'], true)) {
    return;
  }
  final axisLine = asMap(xAxisStyles['axisLine']);
  final tickLine = asMap(xAxisStyles['tickLine']);
  final tickText = asMap(xAxisStyles['tickText']);
  final axisLineSize = asDouble(axisLine['size'], 1);

  if (asBool(axisLine['show'], true)) {
    drawLine(
        ctx,
        LineAttrs(<Coordinate>[
          Coordinate(x: 0, y: 0),
          Coordinate(x: bounding.width, y: 0),
        ]),
        axisLine);
  }
  final ticks = xAxis.getTicks();
  if (asBool(tickLine['show'], true)) {
    final tickLength = asDouble(tickLine['length'], 3);
    final lines = ticks
        .map((tick) => LineAttrs(<Coordinate>[
              Coordinate(x: tick.coord, y: 0),
              Coordinate(x: tick.coord, y: axisLineSize + tickLength),
            ]))
        .toList();
    for (final l in lines) {
      drawLine(ctx, l, tickLine);
    }
  }
  if (asBool(tickText['show'], true)) {
    final tickLength = asDouble(tickLine['length'], 3);
    final marginStart = asDouble(tickText['marginStart'], 4);
    final texts = ticks
        .map((tick) => TextAttrs(
              x: tick.coord,
              y: axisLineSize + tickLength + marginStart,
              text: tick.text,
              align: 'center',
              baseline: 'top',
            ))
        .toList();
    drawText(ctx, texts, tickText);
  }
}
