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

import 'dart:ui' as ui;

/// Port of `common/utils/canvas.ts`.
///
/// Text is measured with a [ui.Paragraph] (the Flutter equivalent of
/// `CanvasRenderingContext2D.measureText`).

const String defaultFontFamily = 'Helvetica Neue';

/// Mirrors the CSS font string produced by the original `createFont`.
String createFont([double? size, Object? weight, String? family]) {
  return '${weight ?? 'normal'} ${size ?? 12}px ${family ?? defaultFontFamily}';
}

ui.FontWeight fontWeightOf(Object? weight) {
  if (weight is num) {
    final w = weight.round();
    if (w >= 800) return ui.FontWeight.w800;
    if (w >= 700) return ui.FontWeight.w700;
    if (w >= 600) return ui.FontWeight.w600;
    if (w >= 500) return ui.FontWeight.w500;
    if (w >= 400) return ui.FontWeight.w400;
    if (w >= 300) return ui.FontWeight.w300;
    if (w >= 200) return ui.FontWeight.w200;
    return ui.FontWeight.w100;
  }
  if (weight is String && weight.toLowerCase() == 'bold') {
    return ui.FontWeight.w700;
  }
  return ui.FontWeight.w400;
}

final Map<String, double> _measureCache = <String, double>{};

/// Measure the width of [text] using the given font parameters.
double calcTextWidth(String text,
    [double? size, Object? weight, String? family]) {
  final key = '$text|$size|$weight|$family';
  final cached = _measureCache[key];
  if (cached != null) {
    return cached;
  }
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
    fontSize: size ?? 12,
    fontWeight: fontWeightOf(weight),
    fontFamily: family ?? defaultFontFamily,
  ))
    ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: double.infinity));
  final width = paragraph.maxIntrinsicWidth.roundToDouble();
  if (_measureCache.length > 4096) {
    _measureCache.clear();
  }
  _measureCache[key] = width;
  return width;
}
