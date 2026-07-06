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

import '../../common/coordinate.dart';
import '../../common/ctx.dart';
import '../../common/utils/color.dart';
import '../../common/utils/style.dart';
import '../../component/figure.dart';

/// Port of `extension/figure/polygon.ts`.

class PolygonAttrs {
  final List<Coordinate> coordinates;
  const PolygonAttrs(this.coordinates);
}

List<PolygonAttrs> _toPolygons(dynamic attrs) {
  if (attrs is PolygonAttrs) return <PolygonAttrs>[attrs];
  if (attrs is List) return attrs.cast<PolygonAttrs>();
  return <PolygonAttrs>[];
}

bool checkCoordinateOnPolygon(Coordinate coordinate, dynamic attrs,
    [dynamic _]) {
  final polygons = _toPolygons(attrs);
  for (final polygon in polygons) {
    var on = false;
    final coordinates = polygon.coordinates;
    for (var i = 0, j = coordinates.length - 1;
        i < coordinates.length;
        j = i++) {
      if ((coordinates[i].y > coordinate.y) !=
              (coordinates[j].y > coordinate.y) &&
          (coordinate.x <
              (coordinates[j].x - coordinates[i].x) *
                      (coordinate.y - coordinates[i].y) /
                      (coordinates[j].y - coordinates[i].y) +
                  coordinates[i].x)) {
        on = !on;
      }
    }
    if (on) {
      return true;
    }
  }
  return false;
}

void drawPolygon(Ctx ctx, dynamic attrs, Map<String, dynamic> styles) {
  final polygons = _toPolygons(attrs);
  final style = asString(styles['style'], 'fill');
  final color = styles['color'] ?? 'currentColor';
  final borderSize = asDouble(styles['borderSize'], 1);
  final borderColor = asString(styles['borderColor'], 'currentColor');
  final borderStyle = asString(styles['borderStyle'], 'solid');
  final borderDashedValue =
      asDoubleList(styles['borderDashedValue'], <double>[2, 2]);

  if ((style == 'fill' || style == 'stroke_fill') &&
      (color is! String || !isTransparent(color))) {
    ctx.fillStyle = color is String ? color : (color as Object);
    for (final polygon in polygons) {
      final coordinates = polygon.coordinates;
      ctx.beginPath();
      ctx.moveTo(coordinates[0].x, coordinates[0].y);
      for (var i = 1; i < coordinates.length; i++) {
        ctx.lineTo(coordinates[i].x, coordinates[i].y);
      }
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
    for (final polygon in polygons) {
      final coordinates = polygon.coordinates;
      ctx.beginPath();
      ctx.moveTo(coordinates[0].x, coordinates[0].y);
      for (var i = 1; i < coordinates.length; i++) {
        ctx.lineTo(coordinates[i].x, coordinates[i].y);
      }
      ctx.closePath();
      ctx.stroke();
    }
  }
}

final FigureTemplate polygon = FigureTemplate(
  name: 'polygon',
  checkEventOn: (coordinate, attrs, styles) =>
      checkCoordinateOnPolygon(coordinate, attrs),
  draw: drawPolygon,
);
