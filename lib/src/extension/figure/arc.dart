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
import '../../common/utils/style.dart';
import '../../component/figure.dart';

/// Port of `extension/figure/arc.ts`.

class ArcAttrs {
  final double x;
  final double y;
  final double r;
  final double startAngle;
  final double endAngle;
  const ArcAttrs({
    required this.x,
    required this.y,
    required this.r,
    required this.startAngle,
    required this.endAngle,
  });
}

List<ArcAttrs> _toArcs(dynamic attrs) {
  if (attrs is ArcAttrs) return <ArcAttrs>[attrs];
  if (attrs is List) return attrs.cast<ArcAttrs>();
  return <ArcAttrs>[];
}

bool checkCoordinateOnArc(Coordinate coordinate, dynamic attrs, [dynamic _]) {
  final arcs = _toArcs(attrs);
  for (final arc in arcs) {
    final distance =
        getDistance(coordinate, Coordinate(x: arc.x, y: arc.y));
    if ((distance - arc.r).abs() < deviation) {
      final r = arc.r;
      final startCoordinateX = r * math.cos(arc.startAngle) + arc.x;
      final startCoordinateY = r * math.sin(arc.startAngle) + arc.y;
      final endCoordinateX = r * math.cos(arc.endAngle) + arc.x;
      final endCoordinateY = r * math.sin(arc.endAngle) + arc.y;
      if (coordinate.x <= math.max(startCoordinateX, endCoordinateX) + deviation &&
          coordinate.x >= math.min(startCoordinateX, endCoordinateX) - deviation &&
          coordinate.y <= math.max(startCoordinateY, endCoordinateY) + deviation &&
          coordinate.y >= math.min(startCoordinateY, endCoordinateY) - deviation) {
        return true;
      }
    }
  }
  return false;
}

void drawArc(Ctx ctx, dynamic attrs, Map<String, dynamic> styles) {
  final arcs = _toArcs(attrs);
  final style = asString(styles['style'], 'solid');
  final size = asDouble(styles['size'], 1);
  final color = asString(styles['color'], 'currentColor');
  final dashedValue = asDoubleList(styles['dashedValue'], <double>[2, 2]);
  ctx.lineWidth = size;
  ctx.strokeStyle = color;
  if (style == 'dashed') {
    ctx.setLineDash(dashedValue);
  } else {
    ctx.setLineDash(<double>[]);
  }
  for (final arc in arcs) {
    ctx.beginPath();
    ctx.arc(arc.x, arc.y, arc.r, arc.startAngle, arc.endAngle);
    ctx.stroke();
    ctx.closePath();
  }
}

final FigureTemplate arc = FigureTemplate(
  name: 'arc',
  checkEventOn: (coordinate, attrs, styles) =>
      checkCoordinateOnArc(coordinate, attrs),
  draw: drawArc,
);
