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

import 'dart:math' as math;

/// Port of `common/utils/number.ts`.
///
/// The original functions use `keyof T`; in Dart we accept an accessor closure
/// instead to keep call sites type-safe.

/// Binary search for the index whose [valueOf] is nearest to [targetValue].
int binarySearchNearest<T>(
  List<T> dataList,
  num Function(T) valueOf,
  num targetValue,
) {
  var left = 0;
  var right = 0;
  for (right = dataList.length - 1; left != right;) {
    final midIndex = ((right + left) / 2).floor();
    final mid = right - left;
    final midValue = valueOf(dataList[midIndex]);
    if (targetValue == valueOf(dataList[left])) {
      return left;
    }
    if (targetValue == valueOf(dataList[right])) {
      return right;
    }
    if (targetValue == midValue) {
      return midIndex;
    }
    if (targetValue > midValue) {
      left = midIndex;
    } else {
      right = midIndex;
    }
    if (mid <= 2) {
      break;
    }
  }
  return left;
}

/// Produce a "nice" rounded number close to [value].
double nice(double value) {
  final exponent = log10(value).floor();
  final exp10 = index10(exponent.toDouble());
  final f = value / exp10; // 1 <= f < 10
  double nf;
  if (f < 1.5) {
    nf = 1;
  } else if (f < 2.5) {
    nf = 2;
  } else if (f < 3.5) {
    nf = 3;
  } else if (f < 4.5) {
    nf = 4;
  } else if (f < 5.5) {
    nf = 5;
  } else if (f < 6.5) {
    nf = 6;
  } else {
    nf = 8;
  }
  value = nf * exp10;
  return double.parse(value.toStringAsFixed(exponent.abs()));
}

/// Round [value] to [precision] decimal places.
double round(double value, [int? precision]) {
  precision = math.max(0, precision ?? 0);
  final pow = math.pow(10, precision);
  return (value * pow).round() / pow;
}

/// Number of decimal places in [value].
int getPrecision(num value) {
  final str = value.toString();
  final eIndex = str.indexOf('e');
  if (eIndex > 0) {
    final precision = int.parse(str.substring(eIndex + 1));
    return precision < 0 ? -precision : 0;
  }
  final dotIndex = str.indexOf('.');
  return dotIndex < 0 ? 0 : str.length - 1 - dotIndex;
}

/// Returns `[max, min]` of the values produced by [maxOf]/[minOf].
List<double> getMaxMin<D>(
  List<D> dataList,
  num? Function(D) maxOf,
  num? Function(D) minOf,
) {
  // Number.MIN_SAFE_INTEGER / MAX_SAFE_INTEGER equivalents.
  const minSafe = -9007199254740991.0;
  const maxSafe = 9007199254740991.0;
  final maxMin = <double>[minSafe, maxSafe];
  final dataLength = dataList.length;
  var index = 0;
  while (index < dataLength) {
    final data = dataList[index];
    maxMin[0] = math.max((maxOf(data) ?? minSafe).toDouble(), maxMin[0]);
    maxMin[1] = math.min((minOf(data) ?? maxSafe).toDouble(), maxMin[1]);
    ++index;
  }
  return maxMin;
}

double log10(double value) {
  if (value == 0) {
    return 0;
  }
  return math.log(value) / math.ln10;
}

double index10(double value) => math.pow(10, value).toDouble();
