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

import 'utils/color.dart';

/// Port of `common/Styles.ts`. Styles are represented as nested
/// `Map<String, dynamic>` (matching the JS object model) so that the
/// deep-partial merge semantics port verbatim.

// ---- style enum string constants -------------------------------------------

typedef LineType = String;

class LineTypes {
  static const String dashed = 'dashed';
  static const String solid = 'solid';
}

typedef PathType = String;

class PathTypes {
  static const String stroke = 'stroke';
  static const String fill = 'fill';
}

typedef PolygonType = String;

class PolygonTypes {
  static const String stroke = 'stroke';
  static const String fill = 'fill';
  static const String strokeFill = 'stroke_fill';
}

typedef TooltipShowRule = String;

class TooltipShowRules {
  static const String always = 'always';
  static const String followCross = 'follow_cross';
  static const String none = 'none';
}

typedef TooltipShowType = String;

class TooltipShowTypes {
  static const String standard = 'standard';
  static const String rect = 'rect';
}

typedef FeatureType = String;

class FeatureTypes {
  static const String path = 'path';
  static const String iconFont = 'icon_font';
}

typedef TooltipFeaturePosition = String;

class TooltipFeaturePositions {
  static const String left = 'left';
  static const String middle = 'middle';
  static const String right = 'right';
}

typedef CandleType = String;

class CandleTypes {
  static const String candleSolid = 'candle_solid';
  static const String candleStroke = 'candle_stroke';
  static const String candleUpStroke = 'candle_up_stroke';
  static const String candleDownStroke = 'candle_down_stroke';
  static const String ohlc = 'ohlc';
  static const String area = 'area';
}

typedef CandleTooltipRectPosition = String;

class CandleTooltipRectPositions {
  static const String fixed = 'fixed';
  static const String pointer = 'pointer';
}

class CandleColorCompareRules {
  static const String currentOpen = 'current_open';
  static const String previousClose = 'previous_close';
}

// ---- palette ----------------------------------------------------------------

class KColor {
  static const String red = '#F92855';
  static const String green = '#2DC08E';
  static const String white = '#FFFFFF';
  static const String grey = '#76808F';
  static const String blue = '#1677FF';
}

Map<String, dynamic> _gridStyle() => <String, dynamic>{
      'show': true,
      'horizontal': <String, dynamic>{
        'show': true,
        'size': 1,
        'color': '#EDEDED',
        'style': 'dashed',
        'dashedValue': <num>[2, 2],
      },
      'vertical': <String, dynamic>{
        'show': true,
        'size': 1,
        'color': '#EDEDED',
        'style': 'dashed',
        'dashedValue': <num>[2, 2],
      },
    };

Map<String, dynamic> _candleStyle() {
  Map<String, dynamic> highLow() => <String, dynamic>{
        'show': true,
        'color': KColor.grey,
        'textOffset': 5,
        'textSize': 10,
        'textFamily': 'Helvetica Neue',
        'textWeight': 'normal',
      };
  return <String, dynamic>{
    'type': 'candle_solid',
    'bar': <String, dynamic>{
      'compareRule': 'current_open',
      'upColor': KColor.green,
      'downColor': KColor.red,
      'noChangeColor': KColor.grey,
      'upBorderColor': KColor.green,
      'downBorderColor': KColor.red,
      'noChangeBorderColor': KColor.grey,
      'upWickColor': KColor.green,
      'downWickColor': KColor.red,
      'noChangeWickColor': KColor.grey,
    },
    'area': <String, dynamic>{
      'lineSize': 2,
      'lineColor': KColor.blue,
      'smooth': false,
      'value': 'close',
      'backgroundColor': <Map<String, dynamic>>[
        <String, dynamic>{'offset': 0, 'color': hexToRgb(KColor.blue, 0.01)},
        <String, dynamic>{'offset': 1, 'color': hexToRgb(KColor.blue, 0.2)},
      ],
      'point': <String, dynamic>{
        'show': true,
        'color': KColor.blue,
        'radius': 4,
        'rippleColor': hexToRgb(KColor.blue, 0.3),
        'rippleRadius': 8,
        'animation': true,
        'animationDuration': 1000,
      },
    },
    'priceMark': <String, dynamic>{
      'show': true,
      'high': highLow(),
      'low': highLow(),
      'last': <String, dynamic>{
        'show': true,
        'compareRule': 'current_open',
        'upColor': KColor.green,
        'downColor': KColor.red,
        'noChangeColor': KColor.grey,
        'line': <String, dynamic>{
          'show': true,
          'style': 'dashed',
          'dashedValue': <num>[4, 4],
          'size': 1,
        },
        'text': <String, dynamic>{
          'show': true,
          'style': 'fill',
          'size': 12,
          'paddingLeft': 4,
          'paddingTop': 4,
          'paddingRight': 4,
          'paddingBottom': 4,
          'borderColor': 'transparent',
          'borderStyle': 'solid',
          'borderSize': 0,
          'borderDashedValue': <num>[2, 2],
          'color': KColor.white,
          'family': 'Helvetica Neue',
          'weight': 'normal',
          'borderRadius': 2,
        },
        'extendTexts': <dynamic>[],
      },
    },
    'tooltip': <String, dynamic>{
      'offsetLeft': 4,
      'offsetTop': 6,
      'offsetRight': 4,
      'offsetBottom': 6,
      'showRule': 'always',
      'showType': 'standard',
      'rect': <String, dynamic>{
        'position': 'fixed',
        'paddingLeft': 4,
        'paddingRight': 4,
        'paddingTop': 4,
        'paddingBottom': 4,
        'offsetLeft': 4,
        'offsetTop': 4,
        'offsetRight': 4,
        'offsetBottom': 4,
        'borderRadius': 4,
        'borderSize': 1,
        'borderColor': '#F2F3F5',
        'color': '#FEFEFE',
      },
      'title': <String, dynamic>{
        'show': true,
        'size': 14,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'color': KColor.grey,
        'marginLeft': 8,
        'marginTop': 4,
        'marginRight': 8,
        'marginBottom': 4,
        'template': '{ticker} · {period}',
      },
      'legend': <String, dynamic>{
        'size': 12,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'color': KColor.grey,
        'marginLeft': 8,
        'marginTop': 4,
        'marginRight': 8,
        'marginBottom': 4,
        'defaultValue': 'n/a',
        'template': <Map<String, dynamic>>[
          <String, dynamic>{'title': 'time', 'value': '{time}'},
          <String, dynamic>{'title': 'open', 'value': '{open}'},
          <String, dynamic>{'title': 'high', 'value': '{high}'},
          <String, dynamic>{'title': 'low', 'value': '{low}'},
          <String, dynamic>{'title': 'close', 'value': '{close}'},
          <String, dynamic>{'title': 'volume', 'value': '{volume}'},
        ],
      },
      'features': <dynamic>[],
    },
  };
}

Map<String, dynamic> _indicatorStyle() {
  final alphaGreen = hexToRgb(KColor.green, 0.7);
  final alphaRed = hexToRgb(KColor.red, 0.7);
  return <String, dynamic>{
    'ohlc': <String, dynamic>{
      'compareRule': 'current_open',
      'upColor': alphaGreen,
      'downColor': alphaRed,
      'noChangeColor': KColor.grey,
    },
    'bars': <Map<String, dynamic>>[
      <String, dynamic>{
        'style': 'fill',
        'borderStyle': 'solid',
        'borderSize': 1,
        'borderDashedValue': <num>[2, 2],
        'upColor': alphaGreen,
        'downColor': alphaRed,
        'noChangeColor': KColor.grey,
      },
    ],
    'lines': <String>['#FF9600', '#935EBD', KColor.blue, '#E11D74', '#01C5C4']
        .map((color) => <String, dynamic>{
              'style': 'solid',
              'smooth': false,
              'size': 1,
              'dashedValue': <num>[2, 2],
              'color': color,
            })
        .toList(),
    'circles': <Map<String, dynamic>>[
      <String, dynamic>{
        'style': 'fill',
        'borderStyle': 'solid',
        'borderSize': 1,
        'borderDashedValue': <num>[2, 2],
        'upColor': alphaGreen,
        'downColor': alphaRed,
        'noChangeColor': KColor.grey,
      },
    ],
    'texts': <Map<String, dynamic>>[
      <String, dynamic>{
        'paddingLeft': 0,
        'paddingTop': 0,
        'paddingRight': 0,
        'paddingBottom': 0,
        'style': 'fill',
        'size': 12,
        'color': KColor.blue,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'borderStyle': 'solid',
        'borderDashedValue': <num>[2, 2],
        'borderSize': 0,
        'borderColor': 'transparent',
        'borderRadius': 0,
        'backgroundColor': 'transparent',
      },
    ],
    'lastValueMark': <String, dynamic>{
      'show': false,
      'text': <String, dynamic>{
        'show': false,
        'style': 'fill',
        'color': KColor.white,
        'size': 12,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'borderStyle': 'solid',
        'borderColor': 'transparent',
        'borderSize': 0,
        'borderDashedValue': <num>[2, 2],
        'paddingLeft': 4,
        'paddingTop': 4,
        'paddingRight': 4,
        'paddingBottom': 4,
        'borderRadius': 2,
      },
    },
    'tooltip': <String, dynamic>{
      'offsetLeft': 4,
      'offsetTop': 6,
      'offsetRight': 4,
      'offsetBottom': 6,
      'showRule': 'always',
      'showType': 'standard',
      'title': <String, dynamic>{
        'show': true,
        'showName': true,
        'showParams': true,
        'size': 12,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'color': KColor.grey,
        'marginLeft': 8,
        'marginTop': 4,
        'marginRight': 8,
        'marginBottom': 4,
      },
      'legend': <String, dynamic>{
        'size': 12,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'color': KColor.grey,
        'marginLeft': 8,
        'marginTop': 4,
        'marginRight': 8,
        'marginBottom': 4,
        'defaultValue': 'n/a',
      },
      'features': <dynamic>[],
    },
  };
}

Map<String, dynamic> _axisStyle() => <String, dynamic>{
      'show': true,
      'size': 'auto',
      'axisLine': <String, dynamic>{
        'show': true,
        'color': '#DDDDDD',
        'size': 1,
      },
      'tickText': <String, dynamic>{
        'show': true,
        'color': KColor.grey,
        'size': 12,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'marginStart': 4,
        'marginEnd': 6,
      },
      'tickLine': <String, dynamic>{
        'show': true,
        'size': 1,
        'length': 3,
        'color': '#DDDDDD',
      },
    };

Map<String, dynamic> _crosshairStyle() {
  Map<String, dynamic> line() => <String, dynamic>{
        'show': true,
        'style': 'dashed',
        'dashedValue': <num>[4, 2],
        'size': 1,
        'color': KColor.grey,
      };
  Map<String, dynamic> text() => <String, dynamic>{
        'show': true,
        'style': 'fill',
        'color': KColor.white,
        'size': 12,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'borderStyle': 'solid',
        'borderDashedValue': <num>[2, 2],
        'borderSize': 1,
        'borderColor': KColor.grey,
        'borderRadius': 2,
        'paddingLeft': 4,
        'paddingRight': 4,
        'paddingTop': 4,
        'paddingBottom': 4,
        'backgroundColor': KColor.grey,
      };
  return <String, dynamic>{
    'show': true,
    'horizontal': <String, dynamic>{
      'show': true,
      'line': line(),
      'text': text(),
      'features': <dynamic>[],
    },
    'vertical': <String, dynamic>{
      'show': true,
      'line': line(),
      'text': text(),
    },
  };
}

Map<String, dynamic> _overlayStyle() {
  final pointBorderColor = hexToRgb(KColor.blue, 0.35);
  final alphaBg = hexToRgb(KColor.blue, 0.25);
  Map<String, dynamic> text() => <String, dynamic>{
        'style': 'fill',
        'color': KColor.white,
        'size': 12,
        'family': 'Helvetica Neue',
        'weight': 'normal',
        'borderStyle': 'solid',
        'borderDashedValue': <num>[2, 2],
        'borderSize': 1,
        'borderRadius': 2,
        'borderColor': KColor.blue,
        'paddingLeft': 4,
        'paddingRight': 4,
        'paddingTop': 4,
        'paddingBottom': 4,
        'backgroundColor': KColor.blue,
      };
  return <String, dynamic>{
    'point': <String, dynamic>{
      'color': KColor.blue,
      'borderColor': pointBorderColor,
      'borderSize': 1,
      'radius': 5,
      'activeColor': KColor.blue,
      'activeBorderColor': pointBorderColor,
      'activeBorderSize': 3,
      'activeRadius': 5,
    },
    'line': <String, dynamic>{
      'style': 'solid',
      'smooth': false,
      'color': KColor.blue,
      'size': 1,
      'dashedValue': <num>[2, 2],
    },
    'rect': <String, dynamic>{
      'style': 'fill',
      'color': alphaBg,
      'borderColor': KColor.blue,
      'borderSize': 1,
      'borderRadius': 0,
      'borderStyle': 'solid',
      'borderDashedValue': <num>[2, 2],
    },
    'polygon': <String, dynamic>{
      'style': 'fill',
      'color': KColor.blue,
      'borderColor': KColor.blue,
      'borderSize': 1,
      'borderStyle': 'solid',
      'borderDashedValue': <num>[2, 2],
    },
    'circle': <String, dynamic>{
      'style': 'fill',
      'color': alphaBg,
      'borderColor': KColor.blue,
      'borderSize': 1,
      'borderStyle': 'solid',
      'borderDashedValue': <num>[2, 2],
    },
    'arc': <String, dynamic>{
      'style': 'solid',
      'color': KColor.blue,
      'size': 1,
      'dashedValue': <num>[2, 2],
    },
    'text': text(),
  };
}

Map<String, dynamic> _separatorStyle() => <String, dynamic>{
      'size': 1,
      'color': '#DDDDDD',
      'fill': true,
      'activeBackgroundColor': hexToRgb(KColor.blue, 0.08),
    };

/// The complete default style object.
Map<String, dynamic> getDefaultStyles() => <String, dynamic>{
      'grid': _gridStyle(),
      'candle': _candleStyle(),
      'indicator': _indicatorStyle(),
      'xAxis': _axisStyle(),
      'yAxis': _axisStyle(),
      'separator': _separatorStyle(),
      'crosshair': _crosshairStyle(),
      'overlay': _overlayStyle(),
    };

// ---- theme overrides --------------------------------------------------------

Map<String, dynamic> lightStyleOverrides() => <String, dynamic>{
      'grid': <String, dynamic>{
        'horizontal': <String, dynamic>{'color': '#EDEDED'},
        'vertical': <String, dynamic>{'color': '#EDEDED'},
      },
      'candle': <String, dynamic>{
        'priceMark': <String, dynamic>{
          'high': <String, dynamic>{'color': '#76808F'},
          'low': <String, dynamic>{'color': '#76808F'},
        },
        'tooltip': <String, dynamic>{
          'rect': <String, dynamic>{
            'color': '#FEFEFE',
            'borderColor': '#F2F3F5',
          },
          'title': <String, dynamic>{'color': '#76808F'},
          'legend': <String, dynamic>{'color': '#76808F'},
        },
      },
      'indicator': <String, dynamic>{
        'tooltip': <String, dynamic>{
          'title': <String, dynamic>{'color': '#76808F'},
          'legend': <String, dynamic>{'color': '#76808F'},
        },
      },
      'xAxis': <String, dynamic>{
        'axisLine': <String, dynamic>{'color': '#DDDDDD'},
        'tickText': <String, dynamic>{'color': '#76808F'},
        'tickLine': <String, dynamic>{'color': '#DDDDDD'},
      },
      'yAxis': <String, dynamic>{
        'axisLine': <String, dynamic>{'color': '#DDDDDD'},
        'tickText': <String, dynamic>{'color': '#76808F'},
        'tickLine': <String, dynamic>{'color': '#DDDDDD'},
      },
      'separator': <String, dynamic>{'color': '#DDDDDD'},
      'crosshair': <String, dynamic>{
        'horizontal': <String, dynamic>{
          'line': <String, dynamic>{'color': '#76808F'},
          'text': <String, dynamic>{
            'borderColor': '#686D76',
            'backgroundColor': '#686D76',
          },
        },
        'vertical': <String, dynamic>{
          'line': <String, dynamic>{'color': '#76808F'},
          'text': <String, dynamic>{
            'borderColor': '#686D76',
            'backgroundColor': '#686D76',
          },
        },
      },
    };

Map<String, dynamic> darkStyleOverrides() => <String, dynamic>{
      'grid': <String, dynamic>{
        'horizontal': <String, dynamic>{'color': '#292929'},
        'vertical': <String, dynamic>{'color': '#292929'},
      },
      'candle': <String, dynamic>{
        'priceMark': <String, dynamic>{
          'high': <String, dynamic>{'color': '#929AA5'},
          'low': <String, dynamic>{'color': '#929AA5'},
        },
        'tooltip': <String, dynamic>{
          'rect': <String, dynamic>{
            'color': 'rgba(10, 10, 10, .6)',
            'borderColor': 'rgba(10, 10, 10, .6)',
          },
          'title': <String, dynamic>{'color': '#929AA5'},
          'legend': <String, dynamic>{'color': '#929AA5'},
        },
      },
      'indicator': <String, dynamic>{
        'tooltip': <String, dynamic>{
          'title': <String, dynamic>{'color': '#929AA5'},
          'legend': <String, dynamic>{'color': '#929AA5'},
        },
      },
      'xAxis': <String, dynamic>{
        'axisLine': <String, dynamic>{'color': '#333333'},
        'tickText': <String, dynamic>{'color': '#929AA5'},
        'tickLine': <String, dynamic>{'color': '#333333'},
      },
      'yAxis': <String, dynamic>{
        'axisLine': <String, dynamic>{'color': '#333333'},
        'tickText': <String, dynamic>{'color': '#929AA5'},
        'tickLine': <String, dynamic>{'color': '#333333'},
      },
      'separator': <String, dynamic>{'color': '#333333'},
      'crosshair': <String, dynamic>{
        'horizontal': <String, dynamic>{
          'line': <String, dynamic>{'color': '#929AA5'},
          'text': <String, dynamic>{
            'borderColor': '#373a40',
            'backgroundColor': '#373a40',
          },
        },
        'vertical': <String, dynamic>{
          'line': <String, dynamic>{'color': '#929AA5'},
          'text': <String, dynamic>{
            'borderColor': '#373a40',
            'backgroundColor': '#373a40',
          },
        },
      },
    };

Map<String, Map<String, dynamic>> _themeStyles = <String, Map<String, dynamic>>{
  'light': lightStyleOverrides(),
  'dark': darkStyleOverrides(),
};

void registerStyles(String name, Map<String, dynamic> ss) {
  _themeStyles[name] = ss;
}

Map<String, dynamic>? getStyles(String name) => _themeStyles[name];
