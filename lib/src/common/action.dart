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

// Port of `common/Action.ts`.

typedef ActionCallback = void Function([Object? data]);

// Chart action names.
typedef ActionType = String;

class ActionTypes {
  static const String onZoom = 'onZoom';
  static const String onScroll = 'onScroll';
  static const String onVisibleRangeChange = 'onVisibleRangeChange';
  static const String onCandleTooltipFeatureClick =
      'onCandleTooltipFeatureClick';
  static const String onIndicatorTooltipFeatureClick =
      'onIndicatorTooltipFeatureClick';
  static const String onCrosshairFeatureClick = 'onCrosshairFeatureClick';
  static const String onCrosshairChange = 'onCrosshairChange';
  static const String onCandleBarClick = 'onCandleBarClick';
  static const String onPaneDrag = 'onPaneDrag';
}

class Action {
  List<ActionCallback> _callbacks = <ActionCallback>[];

  void subscribe(ActionCallback callback) {
    if (!_callbacks.contains(callback)) {
      _callbacks.add(callback);
    }
  }

  void unsubscribe([ActionCallback? callback]) {
    if (callback != null) {
      _callbacks.remove(callback);
    } else {
      _callbacks = <ActionCallback>[];
    }
  }

  void execute([Object? data]) {
    for (final callback in List<ActionCallback>.from(_callbacks)) {
      callback(data);
    }
  }

  bool isEmpty() => _callbacks.isEmpty;
}
