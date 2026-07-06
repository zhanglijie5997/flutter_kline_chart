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

import 'dart:ui' show Color;

import '../common/coordinate.dart';
import '../common/ctx.dart';
import '../common/marker.dart';
import '../extension/figure/polygon.dart';
import '../extension/figure/text.dart';
import 'render_context.dart';

String _toCss(Color c) =>
    'rgba(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()},${c.a})';

/// Draws buy/sell [markers] on the candle pane. They live in content-local
/// coordinates so they scroll and zoom with the chart.
void drawMarkers(Ctx ctx, PaneRenderContext c, List<TradeMarker> markers) {
  if (markers.isEmpty) return;
  final store = c.store;
  const s = 6.0; // half arrow width
  const h = 10.0; // arrow height

  for (final m in markers) {
    final dataIndex = store.timestampToDataIndex(m.timestamp);
    final x = store.dataIndexToCoordinate(dataIndex);
    final y = c.yAxis.convertToPixel(m.price);
    final buy = m.side == TradeSide.buy;
    final color =
        m.color != null ? _toCss(m.color!) : (buy ? '#2DC08E' : '#F92855');

    final triangle = buy
        ? <Coordinate>[
            Coordinate(x: x, y: y),
            Coordinate(x: x - s, y: y + h),
            Coordinate(x: x + s, y: y + h),
          ]
        : <Coordinate>[
            Coordinate(x: x, y: y),
            Coordinate(x: x - s, y: y - h),
            Coordinate(x: x + s, y: y - h),
          ];
    drawPolygon(ctx, PolygonAttrs(triangle),
        <String, dynamic>{'style': 'fill', 'color': color});

    final text = m.text;
    if (text != null && text.isNotEmpty) {
      // Attach the label pill directly to the triangle base (no gap): a 1px
      // overlap hides the seam so they read as one shape.
      final ty = buy ? y + h - 1 : y - h + 1;
      drawText(
        ctx,
        TextAttrs(
          x: x,
          y: ty,
          text: text,
          align: 'center',
          baseline: buy ? 'top' : 'bottom',
        ),
        <String, dynamic>{
          'style': 'fill',
          'color': '#FFFFFF',
          'size': 11,
          'paddingLeft': 5,
          'paddingRight': 5,
          'paddingTop': 3,
          'paddingBottom': 3,
          'borderRadius': 4,
          'backgroundColor': color,
        },
      );
    }
  }
}
