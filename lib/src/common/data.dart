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

/// Port of `common/Data.ts`.

class NeighborData<D> {
  final D prev;
  final D current;
  final D next;
  const NeighborData({
    required this.prev,
    required this.current,
    required this.next,
  });
}

/// A single candlestick / bar of market data.
class KLineData implements Indexable {
  int timestamp;
  double open;
  double high;
  double low;
  double close;
  double? volume;
  double? turnover;

  /// Arbitrary extra fields carried on the data record.
  final Map<String, Object?> extras;

  KLineData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    this.turnover,
    Map<String, Object?>? extras,
  }) : extras = extras ?? <String, Object?>{};

  factory KLineData.fromMap(Map<String, Object?> map) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    final known = {
      'timestamp',
      'open',
      'high',
      'low',
      'close',
      'volume',
      'turnover',
    };
    final extras = <String, Object?>{};
    map.forEach((k, v) {
      if (!known.contains(k)) extras[k] = v;
    });
    return KLineData(
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      open: d(map['open']),
      high: d(map['high']),
      low: d(map['low']),
      close: d(map['close']),
      volume: (map['volume'] as num?)?.toDouble(),
      turnover: (map['turnover'] as num?)?.toDouble(),
      extras: extras,
    );
  }

  @override
  Object? operator [](String key) {
    switch (key) {
      case 'timestamp':
        return timestamp;
      case 'open':
        return open;
      case 'high':
        return high;
      case 'low':
        return low;
      case 'close':
        return close;
      case 'volume':
        return volume;
      case 'turnover':
        return turnover;
    }
    return extras[key];
  }

  void operator []=(String key, Object? value) {
    switch (key) {
      case 'timestamp':
        timestamp = (value as num).toInt();
        return;
      case 'open':
        open = (value as num).toDouble();
        return;
      case 'high':
        high = (value as num).toDouble();
        return;
      case 'low':
        low = (value as num).toDouble();
        return;
      case 'close':
        close = (value as num).toDouble();
        return;
      case 'volume':
        volume = (value as num?)?.toDouble();
        return;
      case 'turnover':
        turnover = (value as num?)?.toDouble();
        return;
    }
    extras[key] = value;
  }
}

class VisibleRangeData {
  final int dataIndex;
  final double x;
  final NeighborData<KLineData?> data;
  const VisibleRangeData({
    required this.dataIndex,
    required this.x,
    required this.data,
  });
}
