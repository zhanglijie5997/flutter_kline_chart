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

/// Port of `extension/figure/rect.ts`.

class RectAttrs {
  final double x;
  final double y;
  final double width;
  final double height;
  const RectAttrs({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
}

List<RectAttrs> _toRects(dynamic attrs) {
  if (attrs is RectAttrs) return <RectAttrs>[attrs];
  if (attrs is List) return attrs.cast<RectAttrs>();
  return <RectAttrs>[];
}

bool checkCoordinateOnRect(Coordinate coordinate, dynamic attrs, [dynamic _]) {
  final rects = _toRects(attrs);
  for (final rect in rects) {
    var x = rect.x;
    var width = rect.width;
    if (width < deviation * 2) {
      x -= deviation;
      width = deviation * 2;
    }
    var y = rect.y;
    var height = rect.height;
    if (height < deviation * 2) {
      y -= deviation;
      height = deviation * 2;
    }
    if (coordinate.x >= x &&
        coordinate.x <= x + width &&
        coordinate.y >= y &&
        coordinate.y <= y + height) {
      return true;
    }
  }
  return false;
}

void drawRect(Ctx ctx, dynamic attrs, Map<String, dynamic> styles) {
  final rects = _toRects(attrs);
  final style = asString(styles['style'], 'fill');
  final color = styles['color'] ?? 'transparent';
  final borderSize = asDouble(styles['borderSize'], 1);
  final borderColor = asString(styles['borderColor'], 'transparent');
  final borderStyle = asString(styles['borderStyle'], 'solid');
  final r = styles['borderRadius'] ?? 0;
  final rNum = r is List ? asDouble(r.isNotEmpty ? r.first : 0) : asDouble(r);
  final borderDashedValue =
      asDoubleList(styles['borderDashedValue'], <double>[2, 2]);

  final solid = (style == 'fill' || style == 'stroke_fill') &&
      (color is! String || !isTransparent(color));
  if (solid) {
    ctx.fillStyle = color is String ? color : (color as Object);
    for (final rect in rects) {
      ctx.beginPath();
      ctx.roundRect(rect.x, rect.y, rect.width, rect.height, rNum);
      ctx.closePath();
      ctx.fill();
    }
  }
  if ((style == 'stroke' || style == 'stroke_fill') &&
      borderSize > 0 &&
      !isTransparent(borderColor)) {
    ctx.strokeStyle = borderColor;
    ctx.fillStyle = borderColor;
    ctx.lineWidth = borderSize;
    if (borderStyle == 'dashed') {
      ctx.setLineDash(borderDashedValue);
    } else {
      ctx.setLineDash(<double>[]);
    }
    final correction = borderSize % 2 == 1 ? 0.5 : 0.0;
    final doubleCorrection = (correction * 2).round().toDouble();
    for (final rect in rects) {
      final w = rect.width;
      final h = rect.height;
      if (w > borderSize * 2 && h > borderSize * 2) {
        ctx.beginPath();
        ctx.roundRect(rect.x + correction, rect.y + correction,
            w - doubleCorrection, h - doubleCorrection, rNum);
        ctx.closePath();
        ctx.stroke();
      } else {
        if (!solid) {
          ctx.fillRect(rect.x, rect.y, w, h);
        }
      }
    }
  }
}

final FigureTemplate rect = FigureTemplate(
  name: 'rect',
  checkEventOn: (coordinate, attrs, styles) =>
      checkCoordinateOnRect(coordinate, attrs),
  draw: drawRect,
);
