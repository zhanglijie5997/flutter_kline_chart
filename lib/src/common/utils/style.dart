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

// Coercion helpers for reading values out of the `Map<String, dynamic>`
// style / options objects.

double asDouble(Object? v, [double def = 0]) =>
    v is num ? v.toDouble() : def;

double? asDoubleOrNull(Object? v) => v is num ? v.toDouble() : null;

int asInt(Object? v, [int def = 0]) => v is num ? v.toInt() : def;

String asString(Object? v, [String def = '']) => v is String ? v : def;

bool asBool(Object? v, [bool def = false]) => v is bool ? v : def;

List<double> asDoubleList(Object? v, [List<double> def = const <double>[]]) {
  if (v is List) {
    return v.map((e) => (e is num ? e.toDouble() : 0.0)).toList();
  }
  return def;
}

List<T> asList<T>(Object? v, [List<T> def = const <Never>[]]) {
  if (v is List) {
    return v.cast<T>();
  }
  return def;
}

Map<String, dynamic> asMap(Object? v) {
  if (v is Map) {
    return v.cast<String, dynamic>();
  }
  return <String, dynamic>{};
}
