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

import '../common/coordinate.dart';
import '../common/ctx.dart';

/// Port of `component/Figure.ts`.

const double deviation = 2;

typedef FigureDrawFn = void Function(
    Ctx ctx, dynamic attrs, Map<String, dynamic> styles);
typedef FigureCheckFn = bool Function(
    Coordinate coordinate, dynamic attrs, Map<String, dynamic> styles);

/// A registrable figure template: name + draw + hit-test.
class FigureTemplate {
  final String name;
  final FigureDrawFn draw;
  final FigureCheckFn checkEventOn;
  const FigureTemplate({
    required this.name,
    required this.draw,
    required this.checkEventOn,
  });
}

/// A concrete figure instance carrying attrs + styles.
class FigureImp {
  final FigureTemplate template;
  dynamic attrs;
  Map<String, dynamic> styles;

  FigureImp(this.template, {this.attrs, Map<String, dynamic>? styles})
      : styles = styles ?? <String, dynamic>{};

  String get name => template.name;

  FigureImp setAttrs(dynamic value) {
    attrs = value;
    return this;
  }

  FigureImp setStyles(Map<String, dynamic> value) {
    styles = value;
    return this;
  }

  void draw(Ctx ctx) => template.draw(ctx, attrs, styles);

  bool checkEventOn(Coordinate coordinate) =>
      template.checkEventOn(coordinate, attrs, styles);
}
