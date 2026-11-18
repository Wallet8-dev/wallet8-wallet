// SPDX-License-Identifier: Apache-2.0

/// The DC API shim bridge - the NON-web form (the conditional
/// import's other arm): the DC API channel exists only in the
/// browser build; the mobile targets resolve nothing.
void resolveDcApiOutcome(String state, String? error, Map<String, Object?>? response) {
  // No-op off the web build.
}
