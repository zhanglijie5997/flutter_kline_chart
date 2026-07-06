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

// Port of `common/utils/typeChecks.ts`.
//
// In the original TypeScript "object" means anything with `typeof === 'object'`,
// which includes both plain objects and arrays. In this Dart port plain JS
// objects are represented as [Map] and arrays as [List], so [isObject] matches
// either, mirroring the JS behaviour used by [merge]/[clone].

bool isArray(Object? value) => value is List;

bool isFunction(Object? value) => value is Function;

// Matches JS `typeof value === 'object' && value != null` (arrays included).
bool isObject(Object? value) => value is Map || value is List;

bool isNumber(Object? value) => value is num && value.isFinite;

bool isValid(Object? value) => value != null;

bool isBoolean(Object? value) => value is bool;

bool isString(Object? value) => value is String;

// Deep-merge [source] into [target], mutating [target] in place.
//
// Both arguments are expected to be [Map] (or [List]) instances.
void merge(dynamic target, dynamic source) {
  if (!isObject(target) && !isObject(source)) {
    return;
  }
  if (source is Map) {
    source.forEach((key, sourceProp) {
      final dynamic targetProp = target is Map ? target[key] : null;
      if (isObject(sourceProp) && isObject(targetProp)) {
        merge(targetProp, sourceProp);
      } else if (target is Map) {
        target[key] = clone(sourceProp);
      }
    });
  } else if (source is List && target is List) {
    for (var i = 0; i < source.length; i++) {
      final dynamic sourceProp = source[i];
      final dynamic targetProp = i < target.length ? target[i] : null;
      if (isObject(sourceProp) && isObject(targetProp)) {
        merge(targetProp, sourceProp);
      } else if (i < target.length) {
        target[i] = clone(sourceProp);
      } else {
        target.add(clone(sourceProp));
      }
    }
  }
}

// Deep clone a value composed of [Map]s, [List]s and primitives.
T clone<T>(T target) {
  if (target is Map) {
    final copy = <String, dynamic>{};
    target.forEach((key, value) {
      copy[key.toString()] = clone<dynamic>(value);
    });
    return copy as T;
  }
  if (target is List) {
    return target.map<dynamic>((dynamic v) => clone<dynamic>(v)).toList() as T;
  }
  return target;
}
