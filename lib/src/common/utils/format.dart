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

import 'indexable.dart';
import 'type_checks.dart';

/// Port of `common/utils/format.ts`.

class DateTime6 {
  final String YYYY;
  final String MM;
  final String DD;
  final String HH;
  final String mm;
  final String ss;
  const DateTime6(this.YYYY, this.MM, this.DD, this.HH, this.mm, this.ss);

  String operator [](String key) {
    switch (key) {
      case 'YYYY':
        return YYYY;
      case 'MM':
        return MM;
      case 'DD':
        return DD;
      case 'HH':
        return HH;
      case 'mm':
        return mm;
      case 'ss':
        return ss;
    }
    return '';
  }
}

/// Stand-in for `Intl.DateTimeFormat`. Holds an optional timezone id.
///
/// Full IANA timezone support would require the `timezone` package; here we
/// support the local timezone (default) and `UTC`.
class DateTimeFormat {
  final String? timezone;
  const DateTimeFormat({this.timezone});

  DateTime resolve(int timestamp) {
    final utc = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    final tz = timezone;
    if (tz == null || tz.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    if (tz == 'UTC' || tz == 'Etc/UTC' || tz == 'Etc/GMT') {
      return utc;
    }
    // Fallback: treat unknown zones as the device-local zone.
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}

String _two(int v) => v < 10 ? '0$v' : '$v';

/// Access [data] at dot/bracket [key] path, returning [defaultValue] (or `--`)
/// when missing. Works on [Map], [List] and [Indexable] instances.
Object? formatValue(Object? data, String key, [Object? defaultValue]) {
  if (isValid(data)) {
    final path = _parsePath(key);
    Object? value = data;
    var index = 0;
    final length = path.length;
    while (isValid(value) && index < length) {
      value = _access(value, path[index++]);
    }
    return isValid(value) ? value : (defaultValue ?? '--');
  }
  return defaultValue ?? '--';
}

Object? _access(Object? value, String key) {
  if (value is Map) {
    return value[key];
  }
  if (value is Indexable) {
    return value[key];
  }
  if (value is List) {
    final i = int.tryParse(key);
    if (i != null && i >= 0 && i < value.length) {
      return value[i];
    }
  }
  return null;
}

List<String> _parsePath(String key) {
  // Split on `.` and `[...]` while stripping surrounding quotes/brackets.
  final result = <String>[];
  final buffer = StringBuffer();
  var i = 0;
  while (i < key.length) {
    final ch = key[i];
    if (ch == '.') {
      if (buffer.isNotEmpty) {
        result.add(buffer.toString());
        buffer.clear();
      }
      i++;
    } else if (ch == '[') {
      if (buffer.isNotEmpty) {
        result.add(buffer.toString());
        buffer.clear();
      }
      final end = key.indexOf(']', i);
      if (end < 0) {
        break;
      }
      var seg = key.substring(i + 1, end).trim();
      if ((seg.startsWith('"') && seg.endsWith('"')) ||
          (seg.startsWith("'") && seg.endsWith("'"))) {
        seg = seg.substring(1, seg.length - 1);
      }
      result.add(seg);
      i = end + 1;
    } else {
      buffer.write(ch);
      i++;
    }
  }
  if (buffer.isNotEmpty) {
    result.add(buffer.toString());
  }
  return result;
}

DateTime6 formatTimestampToDateTime(DateTimeFormat dateTimeFormat, int timestamp) {
  final d = dateTimeFormat.resolve(timestamp);
  return DateTime6(
    d.year.toString().padLeft(4, '0'),
    _two(d.month),
    _two(d.day),
    _two(d.hour),
    _two(d.minute),
    _two(d.second),
  );
}

String formatTimestampByTemplate(
  DateTimeFormat dateTimeFormat,
  int timestamp,
  String template,
) {
  final date = formatTimestampToDateTime(dateTimeFormat, timestamp);
  return template.replaceAllMapped(
    RegExp('YYYY|MM|DD|HH|mm|ss'),
    (m) => date[m.group(0)!],
  );
}

String formatPrecision(Object? value, [int? precision]) {
  final v = value is num ? value : num.tryParse('$value');
  if (v != null && v.isFinite) {
    return v.toStringAsFixed(precision ?? 2);
  }
  return '$value';
}

String formatBigNumber(Object? value) {
  final v = value is num ? value : num.tryParse('$value');
  if (v != null && v.isFinite) {
    if (v > 1000000000) {
      return '${_trim((v / 1000000000).toStringAsFixed(3))}B';
    }
    if (v > 1000000) {
      return '${_trim((v / 1000000).toStringAsFixed(3))}M';
    }
    if (v > 1000) {
      return '${_trim((v / 1000).toStringAsFixed(3))}K';
    }
  }
  return '$value';
}

// Emulates JS `+num.toFixed(3)` which drops trailing zeros.
String _trim(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceAll(RegExp(r'0+$'), '');
  s = s.replaceAll(RegExp(r'\.$'), '');
  return s;
}

String formatThousands(Object? value, String sign) {
  final vl = '$value';
  if (sign.isEmpty) {
    return vl;
  }
  if (vl.contains('.')) {
    final arr = vl.split('.');
    return '${arr[0].replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m.group(1)}$sign')}.${arr[1]}';
  }
  return vl.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m.group(1)}$sign');
}

String formatFoldDecimal(Object? value, int threshold) {
  final vl = '$value';
  final reg = RegExp('\\.0{$threshold,}[1-9][0-9]*\$');
  if (reg.hasMatch(vl)) {
    final result = vl.split('.');
    final lastIndex = result.length - 1;
    final v = result[lastIndex];
    final match = RegExp('0*').firstMatch(v);
    if (match != null) {
      final count = match.group(0)!.length;
      result[lastIndex] = v.replaceFirst(RegExp('0*'), '0{$count}');
      return result.join('.');
    }
  }
  return vl;
}

String formatTemplateString(String template, Map<String, Object?> params) {
  return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
    final key = m.group(1)!;
    final value = params[key];
    if (isValid(value)) {
      return '$value';
    }
    return '{$key}';
  });
}
