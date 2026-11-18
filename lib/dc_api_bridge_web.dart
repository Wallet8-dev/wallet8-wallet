// SPDX-License-Identifier: Apache-2.0

@JS()
library dc_api_bridge_web;

import 'package:js/js.dart';

@JS('window.__wallet8ResolveDcApi')
external bool _resolve(String state, Object? response, String? error);

/// The DC API shim bridge (the WEB arm): resolves the pending
/// credential promise through the shim's callback registry. The
/// response is the vp_token presentation object the holder's
/// present call returned (App. A.4 - the response rides the
/// promise); a non-null error rejects it.
void resolveDcApiOutcome(String state, String? error, Map<String, Object?>? response) {
  final body = error != null ? null : (response ?? const <String, Object?>{});
  _resolve(state, body, error);
}
