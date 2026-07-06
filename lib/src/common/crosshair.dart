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

import 'data.dart';

/// Port of `common/Crosshair.ts` (a partial Coordinate plus extra fields).
class Crosshair {
  double? x;
  double? y;
  String? paneId;
  double? realX;
  int? timestamp;
  KLineData? kLineData;
  int? dataIndex;
  int? realDataIndex;

  Crosshair({
    this.x,
    this.y,
    this.paneId,
    this.realX,
    this.timestamp,
    this.kLineData,
    this.dataIndex,
    this.realDataIndex,
  });

  Crosshair copy() => Crosshair(
        x: x,
        y: y,
        paneId: paneId,
        realX: realX,
        timestamp: timestamp,
        kLineData: kLineData,
        dataIndex: dataIndex,
        realDataIndex: realDataIndex,
      );
}
