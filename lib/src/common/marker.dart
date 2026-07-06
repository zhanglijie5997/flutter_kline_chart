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

/// Buy / sell side of a [TradeMarker].
enum TradeSide { buy, sell }

/// A buy/sell trade-signal marker anchored to a bar ([timestamp]) and [price].
///
/// Rendered on the candle pane as a small triangle (buy points up below the
/// point, sell points down above it) with an optional [text] label pill. It
/// scrolls and zooms together with the chart.
class TradeMarker {
  /// Timestamp of the bar to anchor to (matched to the nearest bar).
  final int timestamp;

  /// Price (y value) the marker points at.
  final double price;

  final TradeSide side;

  /// Optional label text (e.g. `'Buy'`, `'B'`, a price or quantity).
  final String? text;

  /// Overrides the default colour (green for buy, red for sell).
  final Color? color;

  const TradeMarker({
    required this.timestamp,
    required this.price,
    required this.side,
    this.text,
    this.color,
  });
}
