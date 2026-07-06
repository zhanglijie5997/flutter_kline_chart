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

import 'dart:async';

/// Port of `common/Animation.ts`. Drives frame callbacks using a periodic
/// timer (the Flutter analogue of `requestAnimationFrame`).
typedef AnimationDoFrameCallback = void Function(double frameTime);

class Animation {
  int _duration;
  int _iterationCount;

  AnimationDoFrameCallback? _doFrameCallback;

  int _currentIterationCount = 0;
  bool _running = false;
  int _time = 0;
  Timer? _timer;

  Animation({int duration = 500, int iterationCount = 1})
      : _duration = duration,
        _iterationCount = iterationCount;

  void _loop() {
    _running = true;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_running) {
        return;
      }
      final diffTime = DateTime.now().millisecondsSinceEpoch - _time;
      if (diffTime < _duration) {
        _doFrameCallback?.call(diffTime.toDouble());
      } else {
        stop();
        _currentIterationCount++;
        if (_currentIterationCount < _iterationCount) {
          start();
        }
      }
    });
  }

  Animation doFrame(AnimationDoFrameCallback callback) {
    _doFrameCallback = callback;
    return this;
  }

  Animation setDuration(int duration) {
    _duration = duration;
    return this;
  }

  Animation setIterationCount(int iterationCount) {
    _iterationCount = iterationCount;
    return this;
  }

  void start() {
    if (!_running) {
      _time = DateTime.now().millisecondsSinceEpoch;
      _loop();
    }
  }

  void stop() {
    if (_running) {
      _doFrameCallback?.call(_duration.toDouble());
    }
    _running = false;
    _timer?.cancel();
    _timer = null;
  }
}
