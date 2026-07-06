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

// Port of `pane/types.ts`.

typedef PaneState = String; // 'normal' | 'maximize' | 'minimize'

class PaneOptions {
  String? id;
  double? height;
  double? minHeight;
  bool? dragEnabled;
  int? order;
  PaneState? state;
  PaneOptions({
    this.id,
    this.height,
    this.minHeight,
    this.dragEnabled,
    this.order,
    this.state,
  });
}

const double paneMinHeight = 30;
const double paneDefaultHeight = 100;

class PaneIdConstants {
  static const String candle = 'candle_pane';
  static const String indicator = 'indicator_pane_';
  static const String xAxis = 'x_axis_pane';
}
