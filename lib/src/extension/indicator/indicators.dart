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

import '../../component/indicator.dart';
import 'average_price.dart';
import 'awesome_oscillator.dart';
import 'bias.dart';
import 'bollinger_bands.dart';
import 'brar.dart';
import 'bull_and_bear_index.dart';
import 'commodity_channel_index.dart';
import 'current_ratio.dart';
import 'different_of_moving_average.dart';
import 'directional_movement_index.dart';
import 'ease_of_movement_value.dart';
import 'exponential_moving_average.dart';
import 'momentum.dart';
import 'moving_average.dart';
import 'moving_average_convergence_divergence.dart';
import 'on_balance_volume.dart';
import 'price_and_volume_trend.dart';
import 'psychological_line.dart';
import 'rate_of_change.dart';
import 'relative_strength_index.dart';
import 'simple_moving_average.dart';
import 'stoch.dart';
import 'stop_and_reverse.dart';
import 'triple_exponentially_smoothed_average.dart';
import 'volume.dart';
import 'volume_ratio.dart';
import 'williams_r.dart';

/// Built-in indicator templates. Each indicator lives in its own file and is
/// collected here — mirrors `extension/indicator/index.ts`.
List<IndicatorTemplate> get builtinIndicators => _builtin;

final List<IndicatorTemplate> _builtin = <IndicatorTemplate>[
  averagePrice,
  awesomeOscillator,
  bias,
  bollingerBands,
  brar,
  bullAndBearIndex,
  commodityChannelIndex,
  currentRatio,
  differentOfMovingAverage,
  directionalMovementIndex,
  easeOfMovementValue,
  exponentialMovingAverage,
  momentum,
  movingAverage,
  movingAverageConvergenceDivergence,
  onBalanceVolume,
  priceAndVolumeTrend,
  psychologicalLine,
  rateOfChange,
  relativeStrengthIndex,
  simpleMovingAverage,
  stoch,
  stopAndReverse,
  tripleExponentiallySmoothedAverage,
  volume,
  volumeRatio,
  williamsR,
];
