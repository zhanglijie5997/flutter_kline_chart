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

import '../common/coordinate.dart';
import '../common/ctx.dart';
import '../common/utils/style.dart';
import '../extension/figure/line.dart';
import 'render_context.dart';

/// Port of `view/GridView.ts`.
void drawGrid(Ctx ctx, PaneRenderContext c) {
  final styles = asMap(c.styles['grid']);
  if (!asBool(styles['show'], true)) {
    return;
  }
  final width = c.content.width;
  final height = c.content.height;

  final horizontalStyles = asMap(styles['horizontal']);
  if (asBool(horizontalStyles['show'], true)) {
    final attrs = c.yAxis
        .getTicks()
        .map((tick) => LineAttrs(<Coordinate>[
              Coordinate(x: 0, y: tick.coord),
              Coordinate(x: width, y: tick.coord),
            ]))
        .toList();
    drawLine(ctx, attrs, horizontalStyles);
  }

  final verticalStyles = asMap(styles['vertical']);
  if (asBool(verticalStyles['show'], true)) {
    final attrs = c.xAxis
        .getTicks()
        .map((tick) => LineAttrs(<Coordinate>[
              Coordinate(x: tick.coord, y: 0),
              Coordinate(x: tick.coord, y: height),
            ]))
        .toList();
    drawLine(ctx, attrs, verticalStyles);
  }
}
