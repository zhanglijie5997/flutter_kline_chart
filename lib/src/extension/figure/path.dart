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

import '../../common/ctx.dart';
import '../../common/utils/style.dart';
import '../../component/figure.dart';
import 'rect.dart';

/// Port of `extension/figure/path.ts`.

class PathAttrs {
  final double x;
  final double y;
  final double width;
  final double height;
  final String path;
  const PathAttrs({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.path,
  });
}

List<PathAttrs> _toPaths(dynamic attrs) {
  if (attrs is PathAttrs) return <PathAttrs>[attrs];
  if (attrs is List) return attrs.cast<PathAttrs>();
  return <PathAttrs>[];
}

void _drawEllipticalArc(Ctx ctx, double x1, double y1, List<double> args,
    double offsetX, double offsetY, bool isRelative) {
  final rx0 = args[0];
  final ry0 = args[1];
  final rotation = args[2];
  final largeArcFlag = args[3];
  final sweepFlag = args[4];
  final x2 = args[5];
  final y2 = args[6];

  final targetX = isRelative ? x1 + x2 : x2 + offsetX;
  final targetY = isRelative ? y1 + y2 : y2 + offsetY;

  final segments = _ellipticalArcToBeziers(
      x1, y1, rx0, ry0, rotation, largeArcFlag, sweepFlag, targetX, targetY);
  for (final s in segments) {
    ctx.bezierCurveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
  }
}

List<List<double>> _ellipticalArcToBeziers(double x1, double y1, double rx,
    double ry, double rotation, double largeArcFlag, double sweepFlag,
    double x2, double y2) {
  final params = _computeEllipticalArcParameters(
      x1, y1, rx, ry, rotation, largeArcFlag, sweepFlag, x2, y2);
  final cx = params[0];
  final cy = params[1];
  final startAngle = params[2];
  final deltaAngle = params[3];
  final segments = <List<double>>[];
  final numSegments = (deltaAngle.abs() / (math.pi / 2)).ceil();
  for (var i = 0; i < numSegments; i++) {
    final start = startAngle + (i * deltaAngle) / numSegments;
    final end = startAngle + ((i + 1) * deltaAngle) / numSegments;
    segments.add(_ellipticalArcToBezier(cx, cy, rx, ry, rotation, start, end));
  }
  return segments;
}

List<double> _computeEllipticalArcParameters(double x1, double y1, double rx,
    double ry, double rotation, double largeArcFlag, double sweepFlag,
    double x2, double y2) {
  final phi = (rotation * math.pi) / 180;
  final dx = (x1 - x2) / 2;
  final dy = (y1 - y2) / 2;
  final x1p = math.cos(phi) * dx + math.sin(phi) * dy;
  final y1p = -math.sin(phi) * dx + math.cos(phi) * dy;

  final lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
  if (lambda > 1) {
    rx *= math.sqrt(lambda);
    ry *= math.sqrt(lambda);
  }

  final sign = largeArcFlag == sweepFlag ? -1.0 : 1.0;
  final numerator = (rx * rx) * (ry * ry) -
      (rx * rx) * (y1p * y1p) -
      (ry * ry) * (x1p * x1p);
  final denominator = (rx * rx) * (y1p * y1p) + (ry * ry) * (x1p * x1p);
  final cxp =
      sign * math.sqrt((numerator / denominator).abs()) * (rx * y1p / ry);
  final cyp =
      sign * math.sqrt((numerator / denominator).abs()) * (-ry * x1p / rx);

  final cx = math.cos(phi) * cxp - math.sin(phi) * cyp + (x1 + x2) / 2;
  final cy = math.sin(phi) * cxp + math.cos(phi) * cyp + (y1 + y2) / 2;

  final startAngle = math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx);
  var deltaAngle =
      math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx) - startAngle;
  if (deltaAngle < 0 && sweepFlag == 1) {
    deltaAngle += 2 * math.pi;
  } else if (deltaAngle > 0 && sweepFlag == 0) {
    deltaAngle -= 2 * math.pi;
  }
  return <double>[cx, cy, startAngle, deltaAngle];
}

List<double> _ellipticalArcToBezier(double cx, double cy, double rx, double ry,
    double rotation, double startAngle, double endAngle) {
  final alpha = math.sin(endAngle - startAngle) *
      (math.sqrt(4 + 3 * math.pow(math.tan((endAngle - startAngle) / 2), 2)) -
          1) /
      3;
  final cosPhi = math.cos(rotation);
  final sinPhi = math.sin(rotation);

  final x1 = cx +
      rx * math.cos(startAngle) * cosPhi -
      ry * math.sin(startAngle) * sinPhi;
  final y1 = cy +
      rx * math.cos(startAngle) * sinPhi +
      ry * math.sin(startAngle) * cosPhi;
  final x2 =
      cx + rx * math.cos(endAngle) * cosPhi - ry * math.sin(endAngle) * sinPhi;
  final y2 =
      cy + rx * math.cos(endAngle) * sinPhi + ry * math.sin(endAngle) * cosPhi;

  final cp1x = x1 +
      alpha *
          (-rx * math.sin(startAngle) * cosPhi -
              ry * math.cos(startAngle) * sinPhi);
  final cp1y = y1 +
      alpha *
          (-rx * math.sin(startAngle) * sinPhi +
              ry * math.cos(startAngle) * cosPhi);
  final cp2x = x2 -
      alpha *
          (-rx * math.sin(endAngle) * cosPhi -
              ry * math.cos(endAngle) * sinPhi);
  final cp2y = y2 -
      alpha *
          (-rx * math.sin(endAngle) * sinPhi +
              ry * math.cos(endAngle) * cosPhi);
  return <double>[cp1x, cp1y, cp2x, cp2y, x2, y2];
}

void drawPath(Ctx ctx, dynamic attrs, Map<String, dynamic> styles) {
  final paths = _toPaths(attrs);
  final lineWidth = asDouble(styles['lineWidth'], 1);
  final color = asString(styles['color'], 'currentColor');
  ctx.lineWidth = lineWidth;
  ctx.strokeStyle = color;
  ctx.setLineDash(<double>[]);
  for (final p in paths) {
    final commands =
        RegExp('[MLHVCSQTAZ][^MLHVCSQTAZ]*', caseSensitive: false)
            .allMatches(p.path)
            .map((m) => m.group(0)!)
            .toList();
    if (commands.isEmpty) {
      continue;
    }
    final offsetX = p.x;
    final offsetY = p.y;
    ctx.beginPath();
    var currentX = 0.0;
    var currentY = 0.0;
    var startX = 0.0;
    var startY = 0.0;
    for (final command in commands) {
      final type = command[0];
      final args = command
          .substring(1)
          .trim()
          .split(RegExp(r'[\s,]+'))
          .where((s) => s.isNotEmpty)
          .map((s) => double.tryParse(s) ?? 0.0)
          .toList();
      switch (type) {
        case 'M':
          currentX = args[0] + offsetX;
          currentY = args[1] + offsetY;
          ctx.moveTo(currentX, currentY);
          startX = currentX;
          startY = currentY;
          break;
        case 'm':
          currentX += args[0];
          currentY += args[1];
          ctx.moveTo(currentX, currentY);
          startX = currentX;
          startY = currentY;
          break;
        case 'L':
          currentX = args[0] + offsetX;
          currentY = args[1] + offsetY;
          ctx.lineTo(currentX, currentY);
          break;
        case 'l':
          currentX += args[0];
          currentY += args[1];
          ctx.lineTo(currentX, currentY);
          break;
        case 'H':
          currentX = args[0] + offsetX;
          ctx.lineTo(currentX, currentY);
          break;
        case 'h':
          currentX += args[0];
          ctx.lineTo(currentX, currentY);
          break;
        case 'V':
          currentY = args[0] + offsetY;
          ctx.lineTo(currentX, currentY);
          break;
        case 'v':
          currentY += args[0];
          ctx.lineTo(currentX, currentY);
          break;
        case 'C':
          ctx.bezierCurveTo(args[0] + offsetX, args[1] + offsetY,
              args[2] + offsetX, args[3] + offsetY, args[4] + offsetX,
              args[5] + offsetY);
          currentX = args[4] + offsetX;
          currentY = args[5] + offsetY;
          break;
        case 'c':
          ctx.bezierCurveTo(currentX + args[0], currentY + args[1],
              currentX + args[2], currentY + args[3], currentX + args[4],
              currentY + args[5]);
          currentX += args[4];
          currentY += args[5];
          break;
        case 'S':
          ctx.bezierCurveTo(currentX, currentY, args[0] + offsetX,
              args[1] + offsetY, args[2] + offsetX, args[3] + offsetY);
          currentX = args[2] + offsetX;
          currentY = args[3] + offsetY;
          break;
        case 's':
          ctx.bezierCurveTo(currentX, currentY, currentX + args[0],
              currentY + args[1], currentX + args[2], currentY + args[3]);
          currentX += args[2];
          currentY += args[3];
          break;
        case 'Q':
          ctx.quadraticCurveTo(
              args[0] + offsetX, args[1] + offsetY, args[2] + offsetX,
              args[3] + offsetY);
          currentX = args[2] + offsetX;
          currentY = args[3] + offsetY;
          break;
        case 'q':
          ctx.quadraticCurveTo(currentX + args[0], currentY + args[1],
              currentX + args[2], currentY + args[3]);
          currentX += args[2];
          currentY += args[3];
          break;
        case 'T':
          ctx.quadraticCurveTo(
              currentX, currentY, args[0] + offsetX, args[1] + offsetY);
          currentX = args[0] + offsetX;
          currentY = args[1] + offsetY;
          break;
        case 't':
          ctx.quadraticCurveTo(
              currentX, currentY, currentX + args[0], currentY + args[1]);
          currentX += args[0];
          currentY += args[1];
          break;
        case 'A':
          _drawEllipticalArc(ctx, currentX, currentY, args, offsetX, offsetY,
              false);
          currentX = args[5] + offsetX;
          currentY = args[6] + offsetY;
          break;
        case 'a':
          _drawEllipticalArc(
              ctx, currentX, currentY, args, offsetX, offsetY, true);
          currentX += args[5];
          currentY += args[6];
          break;
        case 'Z':
        case 'z':
          ctx.closePath();
          currentX = startX;
          currentY = startY;
          break;
        default:
          break;
      }
    }
    if (styles['style'] == 'fill') {
      ctx.fill();
    } else {
      ctx.stroke();
    }
  }
}

final FigureTemplate path = FigureTemplate(
  name: 'path',
  checkEventOn: (coordinate, attrs, styles) =>
      checkCoordinateOnRect(coordinate, attrs),
  draw: drawPath,
);
