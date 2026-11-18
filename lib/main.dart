// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-License-Identifier: Apache-2.0

/// The Wallet8 reference wallet app - the certification surfaces
/// (DESIGN.md §11.7): the deep-link routes (the offer intake, the
/// verifier request) + the pages.
library;

import 'package:flutter/material.dart';

import 'package:wallet8_flutter/wallet8_flutter.dart';

import 'pages.dart';

void main() {
  // The WEB entry's deep-link fragment (11.11-B): `#/offer=<uri>` /
  // `#/request=<uri>` (the suite's drive + the DC API shim's
  // dispatch land here; the mobile targets keep the custom-scheme
  // form through the same routes). The fragment routes BEFORE the
  // app boots - the initial route carries the payload.
  final initial = _webFragmentRoute();
  runApp(Wallet8App(initialRoute: initial?.route ?? '/', initialUri: initial?.uri));
}

/// The fragment form: `#/offer=<payload>` / `#/request=<payload>` /
/// `#/request?dc_state=<state>&<the verifier's request_uri>`.
({String route, Uri uri})? _webFragmentRoute() {
  final href = Uri.base.fragment;
  if (href.isEmpty) return null;
  if (href.startsWith('/offer=')) {
    final payload = Uri.decodeComponent(href.substring('/offer='.length));
    final uri = Uri.tryParse(payload);
    if (uri != null) return (route: '/offer', uri: uri);
  }
  if (href.startsWith('/request')) {
    // The DC API form: /request?dc_state=...&request_uri=... (the
    // shim's dispatch) OR /request=<uri> (the deep link).
    final rest = href.substring('/request'.length);
    if (rest.startsWith('=')) {
      final payload = Uri.decodeComponent(rest.substring(1));
      final uri = Uri.tryParse(payload);
      if (uri != null) return (route: '/request', uri: uri);
    }
    // The query form: keep the FULL fragment as the payload (the
    // ScanPage extracts the request_uri + the dc_state).
    if (rest.startsWith('?') || rest.isEmpty) {
      final full = Uri.tryParse(href);
      if (full != null) return (route: '/request', uri: full);
    }
  }
  return null;
}

/// The app shell - the route table the suites drive:
/// `/` the vault, `/scan` the intake, `/offer` + `/request` the
/// deep links, the consent + outcome routes ride the pages.
class Wallet8App extends StatelessWidget {
  const Wallet8App({super.key, this.initialRoute = '/', this.initialUri});

  /// The web fragment's resolved route (11.11-B).
  final String initialRoute;

  /// The deep-link payload riding the initial route.
  final Uri? initialUri;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wallet8',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0B57D0),
        ),
        initialRoute: initialRoute,
        routes: {
          '/': (context) => const _WithServices(child: VaultPage()),
          '/scan': (context) => const _WithServices(child: ScanPage()),
        },
        onGenerateRoute: (settings) {
          // The deep links: the offer (openid-credential-offer://...)
          // and the verifier request (the request_uri) - the
          // arguments ride the scanned payload.
          switch (settings.name) {
            case '/offer':
            case '/request':
              // The initial-route case: the payload rides the app
              // (the web fragment resolved it at boot); the pushed
              // route carries it in the settings arguments.
              final uri = settings.arguments is String
                  ? Uri.tryParse(settings.arguments as String)
                  : initialUri;
              return MaterialPageRoute<void>(
                builder: (_) =>
                    _WithServices(child: ScanPage(initialUri: uri)),
              );
            default:
              return null;
          }
        },
      );
}

/// The services wrapper (the BFF base derives from the app's own
/// domain; the dev-tree default is the bootstrap config's).
class _WithServices extends StatelessWidget {
  const _WithServices({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FutureBuilder<WalletServices>(
        future: _services(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return WalletContext(
              services: snapshot.data!,
              child: child,
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: ErrorPage(
                error: 'bootstrap error',
                description: '${snapshot.error}',
              ),
            );
          }
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        },
      );

  Future<WalletServices> _services() async =>
      WalletServices.create(bffBaseUrl: kDefaultBffBaseUrl);
}
