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

import 'dart:ui' show Color;

/// Port of `common/utils/color.ts`, extended with [parseColor] which converts
/// CSS colour strings (as used throughout the style config) into `dart:ui`
/// [Color] values for the canvas adapter.

final RegExp _rgbaRegExp = RegExp(
  r'^[rR][gG][Bb][Aa]?\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*([\d.]+)\s*)?\)$',
);

bool isRgba(String color) => _rgbaRegExp.hasMatch(color);

bool isHsla(String color) {
  return RegExp(
    r'^[hH][Ss][Ll][Aa]\(',
  ).hasMatch(color);
}

bool isTransparent(String color) {
  if (color == 'transparent' || color == 'none') {
    return true;
  }
  final m = _rgbaRegExp.firstMatch(color);
  if (m != null) {
    final a = m.group(4);
    if (a != null && (double.tryParse(a) ?? 1) == 0) {
      return true;
    }
  }
  return false;
}

String rgbToHex(String rgb) {
  if (!isRgba(rgb)) {
    return rgb;
  }
  final match = _rgbaRegExp.firstMatch(rgb);
  if (match == null) {
    throw ArgumentError('Invalid RGB string format');
  }
  final r = int.parse(match.group(1)!).toRadixString(16);
  final g = int.parse(match.group(2)!).toRadixString(16);
  final b = int.parse(match.group(3)!).toRadixString(16);
  String p(String v) => v.length == 1 ? '0$v' : v;
  return '#${p(r)}${p(g)}${p(b)}';
}

String hexToRgb(String hex, [double? alpha]) {
  final h = hex.replaceFirst(RegExp('^#'), '');
  final i = int.parse(h, radix: 16);
  final r = (i >> 16) & 255;
  final g = (i >> 8) & 255;
  final b = i & 255;
  return 'rgba($r, $g, $b, ${alpha ?? 1})';
}

const Color _transparent = Color(0x00000000);

const Map<String, int> _namedColors = <String, int>{
  'transparent': 0x00000000,
  'none': 0x00000000,
  'black': 0xFF000000,
  'white': 0xFFFFFFFF,
  'red': 0xFFFF0000,
  'green': 0xFF008000,
  'blue': 0xFF0000FF,
  'gray': 0xFF808080,
  'grey': 0xFF808080,
  'yellow': 0xFFFFFF00,
  'orange': 0xFFFFA500,
};

int _clamp255(num v) => v.round().clamp(0, 255);

/// Parse a CSS colour string into a `dart:ui` [Color].
///
/// Supports `#rgb`, `#rgba`, `#rrggbb`, `#rrggbbaa`, `rgb()`, `rgba()`,
/// `hsl()`, `hsla()`, named colours and `transparent`/`none`.
Color parseColor(String? input) {
  if (input == null) {
    return _transparent;
  }
  final color = input.trim();
  if (color.isEmpty) {
    return _transparent;
  }

  final named = _namedColors[color.toLowerCase()];
  if (named != null) {
    return Color(named);
  }

  if (color.startsWith('#')) {
    return _parseHex(color.substring(1));
  }

  final lower = color.toLowerCase();
  if (lower.startsWith('rgb')) {
    final m = _rgbaRegExp.firstMatch(color);
    if (m != null) {
      final r = int.parse(m.group(1)!);
      final g = int.parse(m.group(2)!);
      final b = int.parse(m.group(3)!);
      final a = m.group(4) != null ? (double.tryParse(m.group(4)!) ?? 1) : 1.0;
      return Color.fromARGB(_clamp255(a * 255), r, g, b);
    }
  }

  if (lower.startsWith('hsl')) {
    final parsed = _parseHsl(color);
    if (parsed != null) {
      return parsed;
    }
  }

  // Unknown format: fall back to opaque black.
  return const Color(0xFF000000);
}

Color _parseHex(String hex) {
  var h = hex;
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  } else if (h.length == 4) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length == 6) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) {
      return Color(0xFF000000 | v);
    }
  } else if (h.length == 8) {
    // CSS is #rrggbbaa; dart:ui Color wants aarrggbb.
    final rgb = int.tryParse(h.substring(0, 6), radix: 16);
    final a = int.tryParse(h.substring(6, 8), radix: 16);
    if (rgb != null && a != null) {
      return Color((a << 24) | rgb);
    }
  }
  return const Color(0xFF000000);
}

Color? _parseHsl(String color) {
  final m = RegExp(
    r'^[hH][Ss][Ll][Aa]?\(\s*([\d.]+)\s*,\s*([\d.]+)%\s*,\s*([\d.]+)%\s*(?:,\s*([\d.]+)\s*)?\)$',
  ).firstMatch(color);
  if (m == null) {
    return null;
  }
  final h = (double.tryParse(m.group(1)!) ?? 0) / 360.0;
  final s = (double.tryParse(m.group(2)!) ?? 0) / 100.0;
  final l = (double.tryParse(m.group(3)!) ?? 0) / 100.0;
  final a = m.group(4) != null ? (double.tryParse(m.group(4)!) ?? 1) : 1.0;

  double hue2rgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  double r;
  double g;
  double b;
  if (s == 0) {
    r = g = b = l;
  } else {
    final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
    final p = 2 * l - q;
    r = hue2rgb(p, q, h + 1 / 3);
    g = hue2rgb(p, q, h);
    b = hue2rgb(p, q, h - 1 / 3);
  }
  return Color.fromARGB(_clamp255(a * 255), _clamp255(r * 255),
      _clamp255(g * 255), _clamp255(b * 255));
}
