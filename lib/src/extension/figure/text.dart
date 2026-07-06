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
import '../../common/utils/canvas.dart';
import '../../common/utils/style.dart';
import '../../component/figure.dart';
import 'rect.dart';

/// Port of `extension/figure/text.ts`.

class TextAttrs {
  final double x;
  final double y;
  final String text;
  final double? width;
  final double? height;
  final String? align;
  final String? baseline;
  const TextAttrs({
    required this.x,
    required this.y,
    required this.text,
    this.width,
    this.height,
    this.align,
    this.baseline,
  });
}

List<TextAttrs> _toTexts(dynamic attrs) {
  if (attrs is TextAttrs) return <TextAttrs>[attrs];
  if (attrs is List) return attrs.cast<TextAttrs>();
  return <TextAttrs>[];
}

RectAttrs getTextRect(TextAttrs attrs, Map<String, dynamic> styles) {
  final size = asDouble(styles['size'], 12);
  final paddingLeft = asDouble(styles['paddingLeft']);
  final paddingTop = asDouble(styles['paddingTop']);
  final paddingRight = asDouble(styles['paddingRight']);
  final paddingBottom = asDouble(styles['paddingBottom']);
  final weight = styles['weight'] ?? 'normal';
  final family = styles['family'] as String?;
  final align = attrs.align ?? 'left';
  final baseline = attrs.baseline ?? 'top';
  final width = attrs.width ??
      (paddingLeft + calcTextWidth(attrs.text, size, weight, family) + paddingRight);
  final height = attrs.height ?? (paddingTop + size + paddingBottom);
  double startX;
  switch (align) {
    case 'left':
    case 'start':
      startX = attrs.x;
      break;
    case 'right':
    case 'end':
      startX = attrs.x - width;
      break;
    default:
      startX = attrs.x - width / 2;
  }
  double startY;
  switch (baseline) {
    case 'top':
    case 'hanging':
      startY = attrs.y;
      break;
    case 'bottom':
    case 'ideographic':
    case 'alphabetic':
      startY = attrs.y - height;
      break;
    default:
      startY = attrs.y - height / 2;
  }
  return RectAttrs(x: startX, y: startY, width: width, height: height);
}

bool checkCoordinateOnText(
    Coordinate coordinate, dynamic attrs, Map<String, dynamic> styles) {
  final texts = _toTexts(attrs);
  for (final text in texts) {
    final r = getTextRect(text, styles);
    if (coordinate.x >= r.x &&
        coordinate.x <= r.x + r.width &&
        coordinate.y >= r.y &&
        coordinate.y <= r.y + r.height) {
      return true;
    }
  }
  return false;
}

void drawText(Ctx ctx, dynamic attrs, Map<String, dynamic> styles) {
  final texts = _toTexts(attrs);
  final color = asString(styles['color'], 'currentColor');
  final size = asDouble(styles['size'], 12);
  final family = styles['family'] as String?;
  final weight = styles['weight'];
  final paddingLeft = asDouble(styles['paddingLeft']);
  final paddingTop = asDouble(styles['paddingTop']);
  final paddingRight = asDouble(styles['paddingRight']);

  final rects = texts.map((t) => getTextRect(t, styles)).toList();
  final bgStyles = <String, dynamic>{...styles, 'color': styles['backgroundColor']};
  drawRect(ctx, rects, bgStyles);

  ctx.textAlign = 'left';
  ctx.textBaseline = 'top';
  ctx.font = createFont(size, weight, family);
  ctx.fillStyle = color;

  for (var index = 0; index < texts.length; index++) {
    final text = texts[index];
    final r = rects[index];
    ctx.fillText(text.text, r.x + paddingLeft, r.y + paddingTop,
        r.width - paddingLeft - paddingRight);
  }
}

final FigureTemplate text = FigureTemplate(
  name: 'text',
  checkEventOn: checkCoordinateOnText,
  draw: drawText,
);
