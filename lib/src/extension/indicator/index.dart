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

import '../../component/indicator.dart';
import 'indicators.dart' as builtin;

/// Port of `extension/indicator/index.ts`.

final Map<String, IndicatorTemplate> _indicators = <String, IndicatorTemplate>{};
bool _registeredBuiltin = false;

void _ensureBuiltin() {
  if (!_registeredBuiltin) {
    _registeredBuiltin = true;
    for (final t in builtin.builtinIndicators) {
      _indicators[t.name] = t;
    }
  }
}

List<String> getSupportedIndicators() {
  _ensureBuiltin();
  return _indicators.keys.toList();
}

void registerIndicator(IndicatorTemplate template) {
  _ensureBuiltin();
  _indicators[template.name] = template;
}

IndicatorTemplate? getIndicatorTemplate(String name) {
  _ensureBuiltin();
  return _indicators[name];
}

/// Returns a factory that constructs a fresh [IndicatorImp] for [name].
IndicatorConstructor? getIndicatorClass(String name) {
  _ensureBuiltin();
  final template = _indicators[name];
  if (template == null) {
    return null;
  }
  return () => IndicatorImp(template);
}
