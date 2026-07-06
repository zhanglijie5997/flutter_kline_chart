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

// Port of `common/Period.ts`.

typedef PeriodType = String; // 'second' | 'minute' | 'hour' | 'day' | 'week' | 'month' | 'year'

class Period {
  final PeriodType type;
  final int span;
  const Period({required this.type, required this.span});
}

const Map<PeriodType, String> periodTypeXAxisFormat = <PeriodType, String>{
  'second': 'HH:mm:ss',
  'minute': 'HH:mm',
  'hour': 'MM-DD HH:mm',
  'day': 'YYYY-MM-DD',
  'week': 'YYYY-MM-DD',
  'month': 'YYYY-MM',
  'year': 'YYYY',
};

const Map<PeriodType, String> periodTypeCrosshairTooltipFormat =
    <PeriodType, String>{
  'second': 'HH:mm:ss',
  'minute': 'YYYY-MM-DD HH:mm',
  'hour': 'YYYY-MM-DD HH:mm',
  'day': 'YYYY-MM-DD',
  'week': 'YYYY-MM-DD',
  'month': 'YYYY-MM',
  'year': 'YYYY',
};
