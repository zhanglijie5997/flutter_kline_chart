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

import '../common/coordinate.dart';
import '../common/ctx.dart';
import '../common/symbol_info.dart';
import '../common/utils/canvas.dart';
import '../common/utils/format.dart';
import '../common/utils/style.dart';
import '../extension/figure/line.dart';
import '../extension/figure/rect.dart';
import '../extension/figure/text.dart';
import 'render_context.dart';

/// Port of `view/CandleBarView.ts` — candlesticks / bars / OHLC.
void drawCandleBar(Ctx ctx, PaneRenderContext c) {
  final candleStyles = asMap(c.styles['candle']);
  final type = asString(candleStyles['type'], 'candle_solid');
  if (type == 'area') {
    return;
  }
  final barStyles = asMap(candleStyles['bar']);
  final barSpace = c.store.getBarSpace();
  final yAxis = c.yAxis;

  var ohlcSize = 0.0;
  var halfOhlcSize = 0.0;
  if (type == 'ohlc') {
    final gapBar = barSpace.gapBar;
    ohlcSize = math.min(math.max((gapBar * 0.2).round(), 1), 8).toDouble();
    if (ohlcSize > 2 && ohlcSize % 2 == 1) {
      ohlcSize--;
    }
    halfOhlcSize = (ohlcSize / 2).floorToDouble();
  }

  for (final visibleData in c.store.getVisibleRangeDataList()) {
    final current = visibleData.data.current;
    final prev = visibleData.data.prev;
    if (current == null) continue;
    final x = visibleData.x;
    final open = current.open;
    final high = current.high;
    final low = current.low;
    final close = current.close;
    final comparePrice = asString(barStyles['compareRule'], 'current_open') ==
            'current_open'
        ? open
        : (prev?.close ?? close);
    final colors = <String>['', '', ''];
    if (close > comparePrice) {
      colors[0] = asString(barStyles['upColor']);
      colors[1] = asString(barStyles['upBorderColor']);
      colors[2] = asString(barStyles['upWickColor']);
    } else if (close < comparePrice) {
      colors[0] = asString(barStyles['downColor']);
      colors[1] = asString(barStyles['downBorderColor']);
      colors[2] = asString(barStyles['downWickColor']);
    } else {
      colors[0] = asString(barStyles['noChangeColor']);
      colors[1] = asString(barStyles['noChangeBorderColor']);
      colors[2] = asString(barStyles['noChangeWickColor']);
    }
    final openY = yAxis.convertToPixel(open);
    final closeY = yAxis.convertToPixel(close);
    final priceY = <double>[
      openY,
      closeY,
      yAxis.convertToPixel(high),
      yAxis.convertToPixel(low),
    ]..sort();

    final correction = barSpace.gapBar % 2 == 0 ? 1.0 : 0.0;

    void rectFig(dynamic attrs, Map<String, dynamic> styles) {
      drawRect(ctx, attrs, styles);
    }

    switch (type) {
      case 'candle_solid':
        _solidBar(rectFig, x, priceY, barSpace, colors, correction);
        break;
      case 'candle_stroke':
        _strokeBar(rectFig, x, priceY, barSpace, colors, correction);
        break;
      case 'candle_up_stroke':
        if (close > open) {
          _strokeBar(rectFig, x, priceY, barSpace, colors, correction);
        } else {
          _solidBar(rectFig, x, priceY, barSpace, colors, correction);
        }
        break;
      case 'candle_down_stroke':
        if (open > close) {
          _strokeBar(rectFig, x, priceY, barSpace, colors, correction);
        } else {
          _solidBar(rectFig, x, priceY, barSpace, colors, correction);
        }
        break;
      case 'ohlc':
        rectFig(<RectAttrs>[
          RectAttrs(
              x: x - halfOhlcSize,
              y: priceY[0],
              width: ohlcSize,
              height: priceY[3] - priceY[0]),
          RectAttrs(
              x: x - barSpace.halfGapBar,
              y: openY + ohlcSize > priceY[3] ? priceY[3] - ohlcSize : openY,
              width: barSpace.halfGapBar - halfOhlcSize,
              height: ohlcSize),
          RectAttrs(
              x: x + halfOhlcSize,
              y: closeY + ohlcSize > priceY[3] ? priceY[3] - ohlcSize : closeY,
              width: barSpace.halfGapBar - halfOhlcSize,
              height: ohlcSize),
        ], <String, dynamic>{'color': colors[0]});
        break;
    }
  }
}

void _solidBar(void Function(dynamic, Map<String, dynamic>) rectFig, double x,
    List<double> priceY, barSpace, List<String> colors, double correction) {
  rectFig(
      RectAttrs(x: x, y: priceY[0], width: 1, height: priceY[3] - priceY[0]),
      <String, dynamic>{'color': colors[2]});
  rectFig(
      RectAttrs(
          x: x - barSpace.halfGapBar,
          y: priceY[1],
          width: barSpace.gapBar + correction,
          height: math.max(1, priceY[2] - priceY[1])),
      <String, dynamic>{
        'style': 'stroke_fill',
        'color': colors[0],
        'borderColor': colors[1],
      });
}

void _strokeBar(void Function(dynamic, Map<String, dynamic>) rectFig, double x,
    List<double> priceY, barSpace, List<String> colors, double correction) {
  rectFig(<RectAttrs>[
    RectAttrs(x: x, y: priceY[0], width: 1, height: priceY[1] - priceY[0]),
    RectAttrs(x: x, y: priceY[2], width: 1, height: priceY[3] - priceY[2]),
  ], <String, dynamic>{'color': colors[2]});
  rectFig(
      RectAttrs(
          x: x - barSpace.halfGapBar,
          y: priceY[1],
          width: barSpace.gapBar + correction,
          height: math.max(1, priceY[2] - priceY[1])),
      <String, dynamic>{'style': 'stroke', 'borderColor': colors[1]});
}

/// Port of `view/CandleAreaView.ts` (without the ripple animation).
void drawCandleArea(Ctx ctx, PaneRenderContext c) {
  final candleStyles = asMap(c.styles['candle']);
  if (asString(candleStyles['type']) != 'area') {
    return;
  }
  final styles = asMap(candleStyles['area']);
  final valueKey = asString(styles['value'], 'close');
  final yAxis = c.yAxis;
  final height = c.content.height;
  final dataList = c.store.getDataList();
  final lastDataIndex = dataList.length - 1;
  final coordinates = <Coordinate>[];
  var minY = 9007199254740991.0;
  var areaStartX = -9007199254740991.0;
  Coordinate? ripplePoint;

  for (final data in c.store.getVisibleRangeDataList()) {
    final kLineData = data.data.current;
    final value = kLineData?[valueKey];
    if (value is num && value.isFinite) {
      final y = yAxis.convertToPixel(value.toDouble());
      if (areaStartX == -9007199254740991.0) {
        areaStartX = data.x;
      }
      coordinates.add(Coordinate(x: data.x, y: y));
      minY = math.min(minY, y);
      if (data.dataIndex == lastDataIndex) {
        ripplePoint = Coordinate(x: data.x, y: y);
      }
    }
  }

  if (coordinates.isNotEmpty) {
    drawLine(ctx, LineAttrs(coordinates), <String, dynamic>{
      'color': styles['lineColor'],
      'size': styles['lineSize'],
      'smooth': styles['smooth'],
    });

    final backgroundColor = styles['backgroundColor'];
    if (backgroundColor is List) {
      final gradient = ctx.createLinearGradient(0, height, 0, minY);
      for (final stop in backgroundColor) {
        final m = asMap(stop);
        gradient.addColorStop(asDouble(m['offset']), asString(m['color']));
      }
      ctx.fillStyle = gradient;
    } else if (backgroundColor is String) {
      ctx.fillStyle = backgroundColor;
    }
    ctx.beginPath();
    ctx.moveTo(areaStartX, height);
    ctx.lineTo(coordinates[0].x, coordinates[0].y);
    lineTo(ctx, coordinates, styles['smooth']);
    ctx.lineTo(coordinates[coordinates.length - 1].x, height);
    ctx.closePath();
    ctx.fill();
  }

  final pointStyles = asMap(styles['point']);
  if (asBool(pointStyles['show'], true) && ripplePoint != null) {
    final r = asDouble(pointStyles['radius'], 4);
    final circleStyles = <String, dynamic>{
      'style': 'fill',
      'color': pointStyles['color'],
    };
    ctx.fillStyle = asString(pointStyles['color']);
    ctx.beginPath();
    ctx.arc(ripplePoint.x, ripplePoint.y, r, 0, math.pi * 2);
    ctx.closePath();
    ctx.fill();
    // static ripple ring
    ctx.fillStyle = asString(pointStyles['rippleColor']);
    ctx.beginPath();
    ctx.arc(ripplePoint.x, ripplePoint.y, asDouble(pointStyles['rippleRadius'], 8),
        0, math.pi * 2);
    ctx.closePath();
    ctx.fill();
    circleStyles.clear();
  }
}

/// Port of `view/CandleHighLowPriceView.ts`.
void drawCandleHighLow(Ctx ctx, PaneRenderContext c) {
  final priceMarkStyles = asMap(asMap(c.styles['candle'])['priceMark']);
  final highStyles = asMap(priceMarkStyles['high']);
  final lowStyles = asMap(priceMarkStyles['low']);
  if (!asBool(priceMarkStyles['show'], true) ||
      !(asBool(highStyles['show'], true) || asBool(lowStyles['show'], true))) {
    return;
  }
  final highLow = c.store.getVisibleRangeHighLowPrice();
  final precision = c.store.getSymbol()?.pricePrecision ??
      SymbolDefaultPrecisionConstants.price;
  final yAxis = c.yAxis;
  final high = highLow[0]['price']!;
  final highX = highLow[0]['x']!;
  final low = highLow[1]['price']!;
  final lowX = highLow[1]['x']!;
  final highY = yAxis.convertToPixel(high);
  final lowY = yAxis.convertToPixel(low);
  final decimalFold = c.store.getDecimalFold();
  final thousands = c.store.getThousandsSeparator();

  if (asBool(highStyles['show'], true) && high != -9007199254740991.0) {
    _drawHighLowMark(
        ctx,
        c,
        decimalFold.format(thousands.format(formatPrecision(high, precision))),
        Coordinate(x: highX, y: highY),
        highY < lowY ? <double>[-2, -5] : <double>[2, 5],
        highStyles);
  }
  if (asBool(lowStyles['show'], true) && low != 9007199254740991.0) {
    _drawHighLowMark(
        ctx,
        c,
        decimalFold.format(thousands.format(formatPrecision(low, precision))),
        Coordinate(x: lowX, y: lowY),
        highY < lowY ? <double>[2, 5] : <double>[-2, -5],
        lowStyles);
  }
}

void _drawHighLowMark(Ctx ctx, PaneRenderContext c, String text,
    Coordinate coordinate, List<double> offsets, Map<String, dynamic> styles) {
  final color = asString(styles['color']);
  final startX = coordinate.x;
  final startY = coordinate.y + offsets[0];
  drawLine(
      ctx,
      LineAttrs(<Coordinate>[
        Coordinate(x: startX - 2, y: startY + offsets[0]),
        Coordinate(x: startX, y: startY),
        Coordinate(x: startX + 2, y: startY + offsets[0]),
      ]),
      <String, dynamic>{'color': color});

  final width = c.content.width;
  double lineEndX;
  double textStartX;
  String textAlign;
  if (startX > width / 2) {
    lineEndX = startX - 5;
    textStartX = lineEndX - asDouble(styles['textOffset'], 5);
    textAlign = 'right';
  } else {
    lineEndX = startX + 5;
    textAlign = 'left';
    textStartX = lineEndX + asDouble(styles['textOffset'], 5);
  }
  final y = startY + offsets[1];
  drawLine(
      ctx,
      LineAttrs(<Coordinate>[
        Coordinate(x: startX, y: startY),
        Coordinate(x: startX, y: y),
        Coordinate(x: lineEndX, y: y),
      ]),
      <String, dynamic>{'color': color});
  drawText(
      ctx,
      TextAttrs(
          x: textStartX, y: y, text: text, align: textAlign, baseline: 'middle'),
      <String, dynamic>{
        'color': color,
        'size': styles['textSize'],
        'family': styles['textFamily'],
        'weight': styles['textWeight'],
      });
}

/// Port of `view/CandleLastPriceLineView.ts`.
void drawCandleLastPriceLine(Ctx ctx, PaneRenderContext c) {
  final priceMarkStyles = asMap(asMap(c.styles['candle'])['priceMark']);
  final last = asMap(priceMarkStyles['last']);
  final line = asMap(last['line']);
  if (!asBool(priceMarkStyles['show'], true) ||
      !asBool(last['show'], true) ||
      !asBool(line['show'], true)) {
    return;
  }
  final yAxis = c.yAxis;
  final dataList = c.store.getDataList();
  if (dataList.isEmpty) return;
  final data = dataList.last;
  final close = data.close;
  final open = data.open;
  final comparePrice = asString(last['compareRule'], 'current_open') ==
          'current_open'
      ? open
      : (dataList.length >= 2 ? dataList[dataList.length - 2].close : close);
  final priceY = yAxis.convertToNicePixel(close);
  String color;
  if (close > comparePrice) {
    color = asString(last['upColor']);
  } else if (close < comparePrice) {
    color = asString(last['downColor']);
  } else {
    color = asString(last['noChangeColor']);
  }
  drawLine(
      ctx,
      LineAttrs(<Coordinate>[
        Coordinate(x: 0, y: priceY),
        Coordinate(x: c.content.width, y: priceY),
      ]),
      <String, dynamic>{
        'style': line['style'],
        'color': color,
        'size': line['size'],
        'dashedValue': line['dashedValue'],
      });
}

/// Port of `view/CandleLastPriceLabelView.ts` — drawn in the y-axis gutter.
void drawCandleLastPriceLabel(Ctx ctx, PaneRenderContext c) {
  final priceMarkStyles = asMap(asMap(c.styles['candle'])['priceMark']);
  final last = asMap(priceMarkStyles['last']);
  final textStyles = asMap(last['text']);
  if (!asBool(priceMarkStyles['show'], true) ||
      !asBool(last['show'], true) ||
      !asBool(textStyles['show'], true)) {
    return;
  }
  final precision = c.store.getSymbol()?.pricePrecision ??
      SymbolDefaultPrecisionConstants.price;
  final yAxis = c.yAxis;
  final dataList = c.store.getDataList();
  if (dataList.isEmpty) return;
  final data = dataList.last;
  final close = data.close;
  final open = data.open;
  final comparePrice = asString(last['compareRule'], 'current_open') ==
          'current_open'
      ? open
      : (dataList.length >= 2 ? dataList[dataList.length - 2].close : close);
  final priceY = yAxis.convertToNicePixel(close);
  String backgroundColor;
  if (close > comparePrice) {
    backgroundColor = asString(last['upColor']);
  } else if (close < comparePrice) {
    backgroundColor = asString(last['downColor']);
  } else {
    backgroundColor = asString(last['noChangeColor']);
  }
  double x;
  String textAlign;
  if (yAxis.isFromZero()) {
    x = 0;
    textAlign = 'left';
  } else {
    x = c.yAxisBounding.width;
    textAlign = 'right';
  }
  var priceText = yAxis.displayValueToText(close, precision);
  priceText = c.store
      .getDecimalFold()
      .format(c.store.getThousandsSeparator().format(priceText));
  final paddingLeft = asDouble(textStyles['paddingLeft'], 4);
  final paddingRight = asDouble(textStyles['paddingRight'], 4);
  final paddingTop = asDouble(textStyles['paddingTop'], 4);
  final paddingBottom = asDouble(textStyles['paddingBottom'], 4);
  final size = asDouble(textStyles['size'], 12);
  final family = textStyles['family'] as String?;
  final weight = textStyles['weight'];
  final textWidth = paddingLeft +
      calcTextWidth(priceText, size, weight, family) +
      paddingRight;
  final priceTextHeight = paddingTop + size + paddingBottom;
  final st = <String, dynamic>{...textStyles, 'backgroundColor': backgroundColor};
  drawText(
      ctx,
      TextAttrs(
        x: x,
        y: priceY,
        width: textWidth,
        height: priceTextHeight,
        text: priceText,
        align: textAlign,
        baseline: 'middle',
      ),
      st);
}
