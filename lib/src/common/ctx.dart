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
import 'dart:ui' as ui;

import 'utils/canvas.dart';
import 'utils/color.dart';

/// Result of [Ctx.measureText], mirroring `TextMetrics`.
class TextMetrics {
  final double width;
  const TextMetrics(this.width);
}

/// A linear gradient paint source, mirroring `CanvasGradient`.
class CtxGradient {
  final double x0;
  final double y0;
  final double x1;
  final double y1;
  final List<double> _stops = <double>[];
  final List<ui.Color> _colors = <ui.Color>[];

  CtxGradient(this.x0, this.y0, this.x1, this.y1);

  void addColorStop(double offset, String color) {
    _stops.add(offset);
    _colors.add(parseColor(color));
  }

  ui.Shader? toShader() {
    if (_colors.isEmpty) {
      return null;
    }
    if (_colors.length == 1) {
      return ui.Gradient.linear(
        ui.Offset(x0, y0),
        ui.Offset(x1, y1),
        <ui.Color>[_colors.first, _colors.first],
      );
    }
    return ui.Gradient.linear(
      ui.Offset(x0, y0),
      ui.Offset(x1, y1),
      _colors,
      _stops,
    );
  }
}

class _CtxState {
  Object fillStyle;
  Object strokeStyle;
  double lineWidth;
  ui.StrokeCap lineCap;
  ui.StrokeJoin lineJoin;
  double miterLimit;
  double fontSize;
  Object? fontWeight;
  String? fontFamily;
  String textAlign;
  String textBaseline;
  double globalAlpha;
  List<double> lineDash;

  _CtxState({
    required this.fillStyle,
    required this.strokeStyle,
    required this.lineWidth,
    required this.lineCap,
    required this.lineJoin,
    required this.miterLimit,
    required this.fontSize,
    required this.fontWeight,
    required this.fontFamily,
    required this.textAlign,
    required this.textBaseline,
    required this.globalAlpha,
    required this.lineDash,
  });

  _CtxState copy() => _CtxState(
        fillStyle: fillStyle,
        strokeStyle: strokeStyle,
        lineWidth: lineWidth,
        lineCap: lineCap,
        lineJoin: lineJoin,
        miterLimit: miterLimit,
        fontSize: fontSize,
        fontWeight: fontWeight,
        fontFamily: fontFamily,
        textAlign: textAlign,
        textBaseline: textBaseline,
        globalAlpha: globalAlpha,
        lineDash: List<double>.from(lineDash),
      );
}

/// Adapter that exposes a `CanvasRenderingContext2D`-like API on top of a
/// `dart:ui` [ui.Canvas], so the ported drawing code can stay close to the
/// original TypeScript.
class Ctx {
  final ui.Canvas canvas;
  final ui.Size size;

  _CtxState _state = _CtxState(
    fillStyle: const ui.Color(0xFF000000),
    strokeStyle: const ui.Color(0xFF000000),
    lineWidth: 1,
    lineCap: ui.StrokeCap.butt,
    lineJoin: ui.StrokeJoin.miter,
    miterLimit: 10,
    fontSize: 12,
    fontWeight: 'normal',
    fontFamily: defaultFontFamily,
    textAlign: 'left',
    textBaseline: 'alphabetic',
    globalAlpha: 1,
    lineDash: const <double>[],
  );

  final List<_CtxState> _stack = <_CtxState>[];

  ui.Path _path = ui.Path();
  bool _hasCurrentPoint = false;

  Ctx(this.canvas, this.size);

  // ---- style properties -----------------------------------------------------

  set fillStyle(Object value) {
    _state.fillStyle = value is String ? parseColor(value) : value;
  }

  Object get fillStyle => _state.fillStyle;

  set strokeStyle(Object value) {
    _state.strokeStyle = value is String ? parseColor(value) : value;
  }

  Object get strokeStyle => _state.strokeStyle;

  set lineWidth(double value) => _state.lineWidth = value;
  double get lineWidth => _state.lineWidth;

  set lineCap(String value) {
    switch (value) {
      case 'round':
        _state.lineCap = ui.StrokeCap.round;
        break;
      case 'square':
        _state.lineCap = ui.StrokeCap.square;
        break;
      default:
        _state.lineCap = ui.StrokeCap.butt;
    }
  }

  set lineJoin(String value) {
    switch (value) {
      case 'round':
        _state.lineJoin = ui.StrokeJoin.round;
        break;
      case 'bevel':
        _state.lineJoin = ui.StrokeJoin.bevel;
        break;
      default:
        _state.lineJoin = ui.StrokeJoin.miter;
    }
  }

  set miterLimit(double value) => _state.miterLimit = value;

  set globalAlpha(double value) => _state.globalAlpha = value;
  double get globalAlpha => _state.globalAlpha;

  /// Accepts a CSS font string such as `bold 12px Helvetica Neue`.
  set font(String value) {
    final match =
        RegExp(r'^\s*(\S+)?\s*(\d+(?:\.\d+)?)px\s+(.+)\s*$').firstMatch(value);
    if (match != null) {
      final weight = match.group(1);
      _state.fontWeight = weight;
      _state.fontSize = double.tryParse(match.group(2)!) ?? 12;
      _state.fontFamily = match.group(3);
    }
  }

  set textAlign(String value) => _state.textAlign = value;
  set textBaseline(String value) => _state.textBaseline = value;

  void setLineDash(List<num> segments) {
    _state.lineDash = segments.map((e) => e.toDouble()).toList();
  }

  // ---- state ----------------------------------------------------------------

  void save() {
    canvas.save();
    _stack.add(_state.copy());
  }

  void restore() {
    canvas.restore();
    if (_stack.isNotEmpty) {
      _state = _stack.removeLast();
    }
  }

  void translate(double x, double y) => canvas.translate(x, y);
  void rotate(double angle) => canvas.rotate(angle);
  void scale(double x, double y) => canvas.scale(x, y);

  // ---- path construction ----------------------------------------------------

  void beginPath() {
    _path = ui.Path();
    _hasCurrentPoint = false;
  }

  void closePath() {
    _path.close();
  }

  void moveTo(double x, double y) {
    _path.moveTo(x, y);
    _hasCurrentPoint = true;
  }

  void lineTo(double x, double y) {
    if (!_hasCurrentPoint) {
      _path.moveTo(x, y);
    } else {
      _path.lineTo(x, y);
    }
    _hasCurrentPoint = true;
  }

  void bezierCurveTo(
      double cp1x, double cp1y, double cp2x, double cp2y, double x, double y) {
    if (!_hasCurrentPoint) {
      _path.moveTo(cp1x, cp1y);
    }
    _path.cubicTo(cp1x, cp1y, cp2x, cp2y, x, y);
    _hasCurrentPoint = true;
  }

  void quadraticCurveTo(double cpx, double cpy, double x, double y) {
    if (!_hasCurrentPoint) {
      _path.moveTo(cpx, cpy);
    }
    _path.quadraticBezierTo(cpx, cpy, x, y);
    _hasCurrentPoint = true;
  }

  void arc(double x, double y, double r, double startAngle, double endAngle,
      [bool anticlockwise = false]) {
    var sweep = endAngle - startAngle;
    if (anticlockwise && sweep > 0) {
      sweep -= math.pi * 2;
    } else if (!anticlockwise && sweep < 0) {
      sweep += math.pi * 2;
    }
    final rect = ui.Rect.fromCircle(center: ui.Offset(x, y), radius: r);
    if (sweep.abs() >= math.pi * 2 - 1e-6) {
      _path.addOval(rect);
      _hasCurrentPoint = false;
    } else {
      _path.arcTo(rect, startAngle, sweep, !_hasCurrentPoint);
      _hasCurrentPoint = true;
    }
  }

  void rect(double x, double y, double w, double h) {
    _path.addRect(ui.Rect.fromLTWH(x, y, w, h));
    _hasCurrentPoint = false;
  }

  void roundRect(double x, double y, double w, double h, [num r = 0]) {
    final radius = r.toDouble();
    if (radius <= 0) {
      _path.addRect(ui.Rect.fromLTWH(x, y, w, h));
    } else {
      _path.addRRect(ui.RRect.fromLTRBR(
          x, y, x + w, y + h, ui.Radius.circular(radius)));
    }
    _hasCurrentPoint = false;
  }

  // ---- painting -------------------------------------------------------------

  ui.Paint _fillPaint() {
    final paint = ui.Paint()..style = ui.PaintingStyle.fill;
    final fs = _state.fillStyle;
    if (fs is CtxGradient) {
      paint.shader = fs.toShader();
      if (_state.globalAlpha < 1) {
        paint.color = ui.Color.fromRGBO(0, 0, 0, _state.globalAlpha);
      }
    } else if (fs is ui.Color) {
      paint.color = _applyAlpha(fs);
    }
    return paint;
  }

  ui.Paint _strokePaint() {
    final paint = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = _state.lineWidth
      ..strokeCap = _state.lineCap
      ..strokeJoin = _state.lineJoin
      ..strokeMiterLimit = _state.miterLimit;
    final ss = _state.strokeStyle;
    if (ss is CtxGradient) {
      paint.shader = ss.toShader();
    } else if (ss is ui.Color) {
      paint.color = _applyAlpha(ss);
    }
    return paint;
  }

  ui.Color _applyAlpha(ui.Color c) {
    if (_state.globalAlpha >= 1) {
      return c;
    }
    return c.withValues(alpha: c.a * _state.globalAlpha);
  }

  void fill() {
    canvas.drawPath(_path, _fillPaint());
  }

  void stroke() {
    final paint = _strokePaint();
    if (_state.lineDash.isNotEmpty) {
      canvas.drawPath(_dashPath(_path, _state.lineDash), paint);
    } else {
      canvas.drawPath(_path, paint);
    }
  }

  void fillRect(double x, double y, double w, double h) {
    canvas.drawRect(ui.Rect.fromLTWH(x, y, w, h), _fillPaint());
  }

  void strokeRect(double x, double y, double w, double h) {
    final paint = _strokePaint();
    final path = ui.Path()..addRect(ui.Rect.fromLTWH(x, y, w, h));
    if (_state.lineDash.isNotEmpty) {
      canvas.drawPath(_dashPath(path, _state.lineDash), paint);
    } else {
      canvas.drawPath(path, paint);
    }
  }

  void clearRect(double x, double y, double w, double h) {
    canvas.drawRect(
      ui.Rect.fromLTWH(x, y, w, h),
      ui.Paint()..blendMode = ui.BlendMode.clear,
    );
  }

  void clip() {
    canvas.clipPath(_path);
  }

  // ---- text -----------------------------------------------------------------

  ui.Paragraph _buildParagraph(String text, ui.Color color) {
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontSize: _state.fontSize,
      fontWeight: fontWeightOf(_state.fontWeight),
      fontFamily: _state.fontFamily,
      textAlign: ui.TextAlign.left,
    ))
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: _state.fontSize,
        fontWeight: fontWeightOf(_state.fontWeight),
        fontFamily: _state.fontFamily,
      ))
      ..addText(text);
    return builder.build()
      ..layout(const ui.ParagraphConstraints(width: double.infinity));
  }

  void fillText(String text, double x, double y, [double? maxWidth]) {
    final color =
        _state.fillStyle is ui.Color ? _state.fillStyle as ui.Color : const ui.Color(0xFF000000);
    final paragraph = _buildParagraph(text, _applyAlpha(color));
    final w = paragraph.maxIntrinsicWidth;
    final h = paragraph.height;
    double dx;
    switch (_state.textAlign) {
      case 'center':
        dx = x - w / 2;
        break;
      case 'right':
      case 'end':
        dx = x - w;
        break;
      default:
        dx = x;
    }
    double dy;
    switch (_state.textBaseline) {
      case 'middle':
        dy = y - h / 2;
        break;
      case 'bottom':
      case 'ideographic':
      case 'alphabetic':
        dy = y - h;
        break;
      default: // top / hanging
        dy = y;
    }
    canvas.drawParagraph(paragraph, ui.Offset(dx, dy));
  }

  void strokeText(String text, double x, double y, [double? maxWidth]) {
    // Approximation: draw filled text using the stroke colour.
    final color =
        _state.strokeStyle is ui.Color ? _state.strokeStyle as ui.Color : const ui.Color(0xFF000000);
    final prev = _state.fillStyle;
    _state.fillStyle = color;
    fillText(text, x, y, maxWidth);
    _state.fillStyle = prev;
  }

  TextMetrics measureText(String text) {
    return TextMetrics(calcTextWidth(
      text,
      _state.fontSize,
      _state.fontWeight,
      _state.fontFamily,
    ));
  }

  // ---- gradients ------------------------------------------------------------

  CtxGradient createLinearGradient(double x0, double y0, double x1, double y1) {
    return CtxGradient(x0, y0, x1, y1);
  }

  // ---- helpers --------------------------------------------------------------

  static ui.Path _dashPath(ui.Path source, List<double> pattern) {
    if (pattern.isEmpty) {
      return source;
    }
    final dashes = pattern.length.isOdd ? <double>[...pattern, ...pattern] : pattern;
    final dest = ui.Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      var i = 0;
      while (distance < metric.length) {
        final len = dashes[i % dashes.length];
        if (len <= 0) {
          i++;
          draw = !draw;
          continue;
        }
        final next = math.min(distance + len, metric.length);
        if (draw) {
          dest.addPath(metric.extractPath(distance, next), ui.Offset.zero);
        }
        distance = next;
        draw = !draw;
        i++;
      }
    }
    return dest;
  }
}
