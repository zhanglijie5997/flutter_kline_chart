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

import '../../common/coordinate.dart';
import '../../common/ctx.dart';
import '../../common/utils/color.dart';
import '../../common/utils/style.dart';
import '../../component/figure.dart';

/// Port of `extension/figure/circle.ts`.

class CircleAttrs {
  final double x;
  final double y;
  final double r;
  const CircleAttrs({required this.x, required this.y, required this.r});
}

List<CircleAttrs> _toCircles(dynamic attrs) {
  if (attrs is CircleAttrs) return <CircleAttrs>[attrs];
  if (attrs is List) return attrs.cast<CircleAttrs>();
  return <CircleAttrs>[];
}

bool checkCoordinateOnCircle(Coordinate coordinate, dynamic attrs, [dynamic _]) {
  final circles = _toCircles(attrs);
  for (final circle in circles) {
    final difX = coordinate.x - circle.x;
    final difY = coordinate.y - circle.y;
    if (!(difX * difX + difY * difY > circle.r * circle.r)) {
      return true;
    }
  }
  return false;
}

void drawCircle(Ctx ctx, dynamic attrs, Map<String, dynamic> styles) {
  final circles = _toCircles(attrs);
  final style = asString(styles['style'], 'fill');
  final color = styles['color'] ?? 'currentColor';
  final borderSize = asDouble(styles['borderSize'], 1);
  final borderColor = asString(styles['borderColor'], 'currentColor');
  final borderStyle = asString(styles['borderStyle'], 'solid');
  final borderDashedValue =
      asDoubleList(styles['borderDashedValue'], <double>[2, 2]);

  final solid = (style == 'fill' || style == 'stroke_fill') &&
      (color is! String || !isTransparent(color));
  if (solid) {
    ctx.fillStyle = color is String ? color : (color as Object);
    for (final c in circles) {
      ctx.beginPath();
      ctx.arc(c.x, c.y, c.r, 0, math.pi * 2);
      ctx.closePath();
      ctx.fill();
    }
  }
  if ((style == 'stroke' || style == 'stroke_fill') &&
      borderSize > 0 &&
      !isTransparent(borderColor)) {
    ctx.strokeStyle = borderColor;
    ctx.lineWidth = borderSize;
    if (borderStyle == 'dashed') {
      ctx.setLineDash(borderDashedValue);
    } else {
      ctx.setLineDash(<double>[]);
    }
    for (final c in circles) {
      if (!solid || c.r > borderSize) {
        ctx.beginPath();
        ctx.arc(c.x, c.y, c.r, 0, math.pi * 2);
        ctx.closePath();
        ctx.stroke();
      }
    }
  }
}

final FigureTemplate circle = FigureTemplate(
  name: 'circle',
  checkEventOn: (coordinate, attrs, styles) =>
      checkCoordinateOnCircle(coordinate, attrs),
  draw: drawCircle,
);
