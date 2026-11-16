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
  runApp(const Wallet8App());
}

/// The app shell - the route table the suites drive:
/// `/` the vault, `/scan` the intake, `/offer` + `/request` the
/// deep links, the consent + outcome routes ride the pages.
class Wallet8App extends StatelessWidget {
  const Wallet8App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wallet8',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0B57D0),
        ),
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
              final uri = settings.arguments is String
                  ? Uri.tryParse(settings.arguments as String)
                  : null;
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
