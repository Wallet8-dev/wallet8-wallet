// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-License-Identifier: Apache-2.0

/**
 * The DC API shim (OID4VP App. A) - the wallet8 web app's
 * `navigator.credentials.get` handler.
 *
 * The real Browser API lands with the platform's web target (the
 * W3C Digital Credentials API); this shim bridges the conformance
 * suite's dc_api cells TODAY: the verifier pages call
 * `navigator.credentials.get({digital: {...}})`, the shim dispatches
 * the OpenID4VP request to the wallet app's `/request` route, and
 * the wallet's post-consent response resolves the promise (App.
 * A.4: the response rides the promise - NO back-channel).
 *
 * The Origin (A.5/A.2): the shim asserts the browser's own origin -
 * the platform-provided value the holder's expected_origins check
 * compares against.
 */
(function () {
  'use strict';

  if (typeof navigator === 'undefined') return;
  if (navigator.credentials && navigator.credentials.get &&
      navigator.credentials.get.__wallet8Shim) return;

  var walletBaseUrl = document.querySelector('meta[name="wallet8-base"]')?.content ||
    (window.location.origin + '/');

  var pending = new Map(); // state -> resolve callback

  function originOf() {
    return window.location.origin;
  }

  function dispatchToWallet(request) {
    // The wallet round: the request rides the app's /request route
    // (the scan page auto-intakes); the outcome page posts the
    // user's consent decision and resolves this promise via
    // window.__wallet8ResolveDcApi(state, response).
    var state = 'dc-' + Math.random().toString(36).slice(2, 10);
    var endpoint = walletBaseUrl + '#/request?dc_state=' + encodeURIComponent(state);
    pending.set(state, request);
    // The platform's app invocation: the suite drives the wallet
    // window - the shim surfaces the request through the deep link.
    try {
      window.open(endpoint, '_blank');
    } catch (e) {
      // The popup blocked - the promise stays pending (the §8.5
      // wallet_unavailable semantics).
      return Promise.reject({ code: 'wallet_unavailable' });
    }
    return new Promise(function (resolve, reject) {
      pending.set('__resolve__' + state, { resolve: resolve, reject: reject });
    });
  }

  // The wallet's outcome page calls this (the shim's postMessage
  // bridge) with the resolved response.
  window.__wallet8ResolveDcApi = function (state, response, error) {
    var entry = pending.get('__resolve__' + state);
    if (!entry) return false;
    pending.delete('__resolve__' + state);
    pending.delete(state);
    if (error) {
      entry.reject({ code: error });
    } else {
      entry.resolve({ data: response });
    }
    return true;
  };

  // The platform-provided Origin (the A.2 comparison's input) -
  // exposed for the wallet app to carry on the holder calls.
  window.__wallet8Origin = originOf;

  var realGet = navigator.credentials && navigator.credentials.get;
  var shimmedGet = function (options) {
    // The DC API request shape: options.digital carries the protocol
    // + the OpenID4VP request members (App. A.2's `data`).
    var digital = options && (options.digital || options);
    var protocol = digital && (digital.providers ? options.protocol : digital.protocol);
    if (!protocol || String(protocol).indexOf('openid4vp-v1-') !== 0) {
      if (realGet) return realGet.call(navigator.credentials, options);
      return Promise.reject({ code: 'invalid_request' });
    }
    // The exchange protocol versions (App. A.1): v1-unsigned /
    // v1-signed / v1-multisigned - the wallet accepts all three;
    // the request params ride `data` (the unsigned form) or
    // `request` (the JWS).
    var request = digital.data || digital.request || {};
    return dispatchToWallet(request);
  };
  shimmedGet.__wallet8Shim = true;

  Object.defineProperty(navigator, 'credentials', {
    value: {
      get: shimmedGet,
      store: (realGet && realGet.store) || undefined,
      create: (realGet && realGet.create) || undefined,
      preventSilentAccess: (realGet && realGet.preventSilentAccess) || (function () { return Promise.resolve(); }),
    },
    configurable: true,
  });
})();
