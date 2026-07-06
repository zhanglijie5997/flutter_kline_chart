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

import '../common/bounding.dart';
import '../common/marker.dart';
import '../component/axis.dart';
import '../store.dart';

/// Per-pane render context handed to the view drawing functions.
///
/// All drawing happens in content-local coordinates: the painter translates the
/// canvas so `(0, 0)` is the top-left of [content] before invoking a view.
class PaneRenderContext {
  final ChartStore store;
  final String paneId;
  final bool isCandle;

  /// Size of the content (candles / indicators) drawing area.
  final Bounding content;

  /// Size of the y-axis gutter.
  final Bounding yAxisBounding;

  final YAxisImp yAxis;
  final XAxisImp xAxis;

  /// Buy/sell markers (only meaningful on the candle pane).
  final List<TradeMarker> markers;

  const PaneRenderContext({
    required this.store,
    required this.paneId,
    required this.isCandle,
    required this.content,
    required this.yAxisBounding,
    required this.yAxis,
    required this.xAxis,
    this.markers = const <TradeMarker>[],
  });

  Map<String, dynamic> get styles => store.getStyles();
}
