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

/// Port of `common/Coordinate.ts`.
class Coordinate {
  double x;
  double y;
  Coordinate({this.x = 0, this.y = 0});
}

double getDistance(Coordinate c1, Coordinate c2) {
  final xDif = c1.x - c2.x;
  final yDif = c1.y - c2.y;
  return math.sqrt(xDif * xDif + yDif * yDif);
}
