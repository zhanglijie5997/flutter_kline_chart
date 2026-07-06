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

import 'package:flutter/foundation.dart';

import '../../version.dart';

/// Port of `common/utils/logger.ts`. Logs only in debug (dev) builds.

void _log(String prefix, String api, String invalidParam, String append) {
  if (kDebugMode) {
    final apiStr = api.isNotEmpty
        ? 'Call api `$api`${invalidParam.isNotEmpty || append.isNotEmpty ? ', ' : '.'}'
        : '';
    final invalidParamStr = invalidParam.isNotEmpty
        ? 'invalid parameter `$invalidParam`${append.isNotEmpty ? ', ' : '.'}'
        : '';
    debugPrint('$prefix $apiStr$invalidParamStr$append');
  }
}

void logWarn(String api, String invalidParam, [String? append]) {
  _log('😑 klinecharts warning', api, invalidParam, append ?? '');
}

void logError(String api, String invalidParam, [String? append]) {
  _log('😟 klinecharts error', api, invalidParam, append ?? '');
}

void logTag() {
  if (kDebugMode) {
    debugPrint('❤️ Welcome to klinecharts. Version is $version');
  }
}
