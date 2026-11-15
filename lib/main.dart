// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-FileCopyrightText: Copyright Contributors to the Wallet8 Wallet
// SPDX-License-Identifier: Apache-2.0

/// The Wallet8 reference wallet app.
library;

import 'package:flutter/material.dart';

import 'package:wallet8_flutter/wallet8_flutter.dart';

void main() {
  runApp(const Wallet8App());
}

/// The app shell.
class Wallet8App extends StatelessWidget {
  const Wallet8App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Wallet8',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF0B57D0),
        ),
        home: const VaultPage(),
      );
}

/// The credential list (the vault view).
class VaultPage extends StatefulWidget {
  const VaultPage({super.key});

  @override
  State<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends State<VaultPage> {
  List<StoredCredentialView> _rows = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // The BFF base derives from the app's own domain (the platform
    // rule: bff.{app_domain}); the dev-tree default is the bootstrap
    // config's.
    try {
      final services = WalletServices.create(
        bffBaseUrl:
            'https://bff.wallet8.ops.sys.local.sentin8.dev',
      );
      final rows = await CredentialStore(services).list();
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Wallet8')),
        body: _error != null
            ? Center(child: Text(_error!))
            : _rows.isEmpty
                ? const Center(
                    child: Text('No credentials yet - scan an offer QR.'),
                  )
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, i) {
                      final row = _rows[i];
                      return ListTile(
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(row.displayName),
                        subtitle: Text(
                            '${row.format} - ${row.doctype ?? row.issuer}'),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            // The QR scan (the offer intake + the verifier request) -
            // the camera surface lands with the mobile targets; the
            // web flow deep-links the QR payload.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Scan: the QR camera surface')),
            );
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan'),
        ),
      );
}
