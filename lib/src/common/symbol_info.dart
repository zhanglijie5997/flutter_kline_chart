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

import 'utils/indexable.dart';

/// Port of `common/SymbolInfo.ts`.
class SymbolInfo implements Indexable {
  String ticker;
  int? pricePrecision;
  int? volumePrecision;
  final Map<String, Object?> extras;

  SymbolInfo({
    required this.ticker,
    this.pricePrecision,
    this.volumePrecision,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  @override
  Object? operator [](String key) {
    switch (key) {
      case 'ticker':
        return ticker;
      case 'pricePrecision':
        return pricePrecision;
      case 'volumePrecision':
        return volumePrecision;
    }
    return extras[key];
  }
}

class SymbolDefaultPrecisionConstants {
  static const int price = 2;
  static const int volume = 0;
}
