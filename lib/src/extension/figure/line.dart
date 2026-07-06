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

/// Port of `extension/figure/line.ts`.

class LineAttrs {
  final List<Coordinate> coordinates;
  const LineAttrs(this.coordinates);
}

List<LineAttrs> _toLines(dynamic attrs) {
  if (attrs is LineAttrs) return <LineAttrs>[attrs];
  if (attrs is List) return attrs.cast<LineAttrs>();
  return <LineAttrs>[];
}

bool checkCoordinateOnLine(Coordinate coordinate, dynamic attrs, [dynamic _]) {
  final lines = _toLines(attrs);
  for (final line in lines) {
    final coordinates = line.coordinates;
    if (coordinates.length > 1) {
      for (var i = 1; i < coordinates.length; i++) {
        final prev = coordinates[i - 1];
        final current = coordinates[i];
        if (prev.x == current.x) {
          if ((prev.y - coordinate.y).abs() +
                      (current.y - coordinate.y).abs() -
                      (prev.y - current.y).abs() <
                  deviation + deviation &&
              (coordinate.x - prev.x).abs() < deviation) {
            return true;
          }
        } else {
          final kb = getLinearSlopeIntercept(prev, current)!;
          final y = getLinearYFromSlopeIntercept(kb, coordinate);
          final yDif = (y - coordinate.y).abs();
          if ((prev.x - coordinate.x).abs() +
                      (current.x - coordinate.x).abs() -
                      (prev.x - current.x).abs() <
                  deviation + deviation &&
              yDif * yDif / (kb[0] * kb[0] + 1) < deviation * deviation) {
            return true;
          }
        }
      }
    }
  }
  return false;
}

double getLinearYFromSlopeIntercept(List<double>? kb, Coordinate coordinate) {
  if (kb != null) {
    return coordinate.x * kb[0] + kb[1];
  }
  return coordinate.y;
}

double getLinearYFromCoordinates(
    Coordinate c1, Coordinate c2, Coordinate target) {
  final kb = getLinearSlopeIntercept(c1, c2);
  return getLinearYFromSlopeIntercept(kb, target);
}

List<double>? getLinearSlopeIntercept(Coordinate c1, Coordinate c2) {
  final difX = c1.x - c2.x;
  if (difX != 0) {
    final k = (c1.y - c2.y) / difX;
    final b = c1.y - k * c1.x;
    return <double>[k, b];
  }
  return null;
}

void lineTo(Ctx ctx, List<Coordinate> coordinates, dynamic smooth) {
  final length = coordinates.length;
  final smoothParam = smooth is num
      ? (smooth > 0 && smooth < 1 ? smooth.toDouble() : 0.0)
      : (smooth == true ? 0.5 : 0.0);
  if (smoothParam > 0 && length > 2) {
    var cpx0 = coordinates[0].x;
    var cpy0 = coordinates[0].y;
    for (var i = 1; i < length - 1; i++) {
      final prev = coordinates[i - 1];
      final coordinate = coordinates[i];
      final next = coordinates[i + 1];
      final dx01 = coordinate.x - prev.x;
      final dy01 = coordinate.y - prev.y;
      final dx12 = next.x - coordinate.x;
      final dy12 = next.y - coordinate.y;
      var dx02 = next.x - prev.x;
      var dy02 = next.y - prev.y;
      final prevSegmentLength = math.sqrt(dx01 * dx01 + dy01 * dy01);
      final nextSegmentLength = math.sqrt(dx12 * dx12 + dy12 * dy12);
      final segmentLengthRatio =
          nextSegmentLength / (nextSegmentLength + prevSegmentLength);

      var nextCpx = coordinate.x + dx02 * smoothParam * segmentLengthRatio;
      var nextCpy = coordinate.y + dy02 * smoothParam * segmentLengthRatio;
      nextCpx = math.min(nextCpx, math.max(next.x, coordinate.x));
      nextCpy = math.min(nextCpy, math.max(next.y, coordinate.y));
      nextCpx = math.max(nextCpx, math.min(next.x, coordinate.x));
      nextCpy = math.max(nextCpy, math.min(next.y, coordinate.y));

      dx02 = nextCpx - coordinate.x;
      dy02 = nextCpy - coordinate.y;

      var cpx1 = coordinate.x - dx02 * prevSegmentLength / nextSegmentLength;
      var cpy1 = coordinate.y - dy02 * prevSegmentLength / nextSegmentLength;

      cpx1 = math.min(cpx1, math.max(prev.x, coordinate.x));
      cpy1 = math.min(cpy1, math.max(prev.y, coordinate.y));
      cpx1 = math.max(cpx1, math.min(prev.x, coordinate.x));
      cpy1 = math.max(cpy1, math.min(prev.y, coordinate.y));

      dx02 = coordinate.x - cpx1;
      dy02 = coordinate.y - cpy1;
      nextCpx = coordinate.x + dx02 * nextSegmentLength / prevSegmentLength;
      nextCpy = coordinate.y + dy02 * nextSegmentLength / prevSegmentLength;

      ctx.bezierCurveTo(cpx0, cpy0, cpx1, cpy1, coordinate.x, coordinate.y);

      cpx0 = nextCpx;
      cpy0 = nextCpy;
    }
    final last = coordinates[length - 1];
    ctx.bezierCurveTo(cpx0, cpy0, last.x, last.y, last.x, last.y);
  } else {
    for (var i = 1; i < length; i++) {
      ctx.lineTo(coordinates[i].x, coordinates[i].y);
    }
  }
}

void drawLine(Ctx ctx, dynamic attrs, Map<String, dynamic> styles) {
  final lines = _toLines(attrs);
  final style = asString(styles['style'], 'solid');
  final smooth = styles['smooth'] ?? false;
  final size = asDouble(styles['size'], 1);
  final color = asString(styles['color'], 'currentColor');
  final dashedValue = asDoubleList(styles['dashedValue'], <double>[2, 2]);
  final lineCap = styles['lineCap'];
  final lineJoin = styles['lineJoin'];
  final isSmooth = smooth is num ? smooth > 0 : smooth == true;
  ctx.lineWidth = size;
  ctx.strokeStyle = color;
  if (lineCap is String) {
    ctx.lineCap = lineCap;
  } else if (isSmooth) {
    ctx.lineCap = 'round';
  } else {
    ctx.lineCap = 'butt';
  }
  if (lineJoin is String) {
    ctx.lineJoin = lineJoin;
  } else if (isSmooth) {
    ctx.lineJoin = 'round';
  } else {
    ctx.lineJoin = 'miter';
  }
  if (style == 'dashed') {
    ctx.setLineDash(dashedValue);
  } else {
    ctx.setLineDash(<double>[]);
  }
  final correction = size % 2 == 1 ? 0.5 : 0.0;
  for (final line in lines) {
    final coordinates = line.coordinates;
    if (coordinates.length > 1) {
      if (coordinates.length == 2 &&
          (coordinates[0].x == coordinates[1].x ||
              coordinates[0].y == coordinates[1].y)) {
        ctx.beginPath();
        if (coordinates[0].x == coordinates[1].x) {
          ctx.moveTo(coordinates[0].x + correction, coordinates[0].y);
          ctx.lineTo(coordinates[1].x + correction, coordinates[1].y);
        } else {
          ctx.moveTo(coordinates[0].x, coordinates[0].y + correction);
          ctx.lineTo(coordinates[1].x, coordinates[1].y + correction);
        }
        ctx.stroke();
        ctx.closePath();
      } else {
        ctx.save();
        if (size % 2 == 1) {
          ctx.translate(0.5, 0.5);
        }
        ctx.beginPath();
        ctx.moveTo(coordinates[0].x, coordinates[0].y);
        lineTo(ctx, coordinates, smooth);
        ctx.stroke();
        ctx.closePath();
        ctx.restore();
      }
    }
  }
}

final FigureTemplate line = FigureTemplate(
  name: 'line',
  checkEventOn: (coordinate, attrs, styles) =>
      checkCoordinateOnLine(coordinate, attrs),
  draw: drawLine,
);
