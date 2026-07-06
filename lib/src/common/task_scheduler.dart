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

// Port of `common/TaskScheduler.ts`.

typedef TaskFinishedCallback = void Function();

class TaskScheduler {
  Map<String, Future<Object?>>? _holdingTasks;
  bool _running = false;
  final TaskFinishedCallback? _callback;

  TaskScheduler(this._callback);

  void add(Map<String, Future<Object?>> tasks) {
    if (!_running) {
      _runTask(tasks);
    } else {
      if (_holdingTasks != null) {
        _holdingTasks = <String, Future<Object?>>{..._holdingTasks!, ...tasks};
      } else {
        _holdingTasks = tasks;
      }
    }
  }

  Future<void> _runTask(Map<String, Future<Object?>> tasks) async {
    _running = true;
    try {
      await Future.wait(tasks.values);
    } finally {
      _running = false;
      _callback?.call();
      if (_holdingTasks != null) {
        final next = _holdingTasks!;
        _holdingTasks = null;
        _runTask(next);
      }
    }
  }

  void clear() {
    _holdingTasks = null;
  }
}
