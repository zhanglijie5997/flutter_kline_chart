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

/// Port of `common/Bounding.ts`.
class Bounding {
  double width;
  double height;
  double left;
  double right;
  double top;
  double bottom;

  Bounding({
    this.width = 0,
    this.height = 0,
    this.left = 0,
    this.right = 0,
    this.top = 0,
    this.bottom = 0,
  });

  Bounding copy() => Bounding(
        width: width,
        height: height,
        left: left,
        right: right,
        top: top,
        bottom: bottom,
      );
}

Bounding createDefaultBounding([Bounding? bounding]) {
  final b = Bounding();
  if (bounding != null) {
    b
      ..width = bounding.width
      ..height = bounding.height
      ..left = bounding.left
      ..right = bounding.right
      ..top = bounding.top
      ..bottom = bounding.bottom;
  }
  return b;
}
