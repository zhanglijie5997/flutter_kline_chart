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

import '../../component/figure.dart';
import 'arc.dart';
import 'circle.dart';
import 'line.dart';
import 'path.dart';
import 'polygon.dart';
import 'rect.dart';
import 'text.dart';

/// Port of `extension/figure/index.ts`.

final Map<String, FigureTemplate> _figures = <String, FigureTemplate>{
  for (final f in <FigureTemplate>[circle, line, polygon, rect, text, arc, path])
    f.name: f,
};

List<String> getSupportedFigures() => _figures.keys.toList();

void registerFigure(FigureTemplate figure) {
  _figures[figure.name] = figure;
}

FigureTemplate? getInnerFigureClass(String name) => _figures[name];

FigureTemplate? getFigureClass(String name) => _figures[name];

/// Create a [FigureImp] from a registered figure name.
FigureImp? createFigureInstance(String name,
    {dynamic attrs, Map<String, dynamic>? styles}) {
  final t = _figures[name];
  if (t == null) {
    return null;
  }
  return FigureImp(t, attrs: attrs, styles: styles);
}
