// SPDX-FileCopyrightText: Copyright Logically Magic Inc. <hello@logicallymagic.com>
// SPDX-FileCopyrightText: Copyright Hamid Jahanzad <Hamid@Jahanzad.com>
// SPDX-License-Identifier: Apache-2.0

/// The Wallet8 app's pages - the certification surfaces
/// (DESIGN.md §11.7): the vault list, the scan intake, the consent
/// preview, the error screen, and the presentation outcome. Every
/// screen renders the state the OIDF wallet-role suites drive.
library;

import 'package:flutter/material.dart';

import 'package:wallet8_flutter/wallet8_flutter.dart';

/// The BFF base (the platform rule: bff.{app_domain}).
const kDefaultBffBaseUrl =
    'https://bff.wallet8.ops.sys.local.sentin8.dev';

/// The shared wallet context (the services + the drivers).
class WalletContext extends InheritedWidget {
  final WalletServices services;

  const WalletContext({super.key, required this.services, required super.child});

  static WalletContext of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WalletContext>()!;

  @override
  bool updateShouldNotify(WalletContext oldWidget) =>
      oldWidget.services != services;
}

/// The vault page - the credential list (the wallet's home).
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
    try {
      final rows = await CredentialStore(
        WalletContext.of(context).services,
      ).list();
      setState(() => _rows = rows);
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Wallet8'),
          actions: [
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: 'Scan a QR',
              onPressed: () => Navigator.of(context)
                  .push<void>(MaterialPageRoute(builder: (_) => const ScanPage())),
            ),
          ],
        ),
        body: _error != null
            ? ErrorPage(error: 'vault error', description: _error!)
            : _rows.isEmpty
                ? const Center(
                    child: Text('No credentials yet - scan an offer QR.'),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
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
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context)
              .push<void>(MaterialPageRoute(builder: (_) => const ScanPage())),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan'),
        ),
      );
}

/// The scan page - the QR/URI intake (the web deep-link form: the
/// scanned payload lands via the route arguments; the camera lands
/// with the mobile targets).
class ScanPage extends StatefulWidget {
  const ScanPage({super.key, this.initialUri});

  /// The deep-linked payload (the certification's QR round).
  final Uri? initialUri;

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    if (widget.initialUri != null) {
      _controller.text = widget.initialUri.toString();
      // Auto-intake on the deep link (the QR round).
      WidgetsBinding.instance.addPostFrameCallback((_) => _intake());
    }
  }

  bool get _isOffer =>
      _controller.text.startsWith('openid-credential-offer://');

  Future<void> _intake() async {
    final uri = Uri.tryParse(_controller.text.trim());
    if (uri == null) {
      setState(() => _error = 'the scanned value is not a URI');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final wallet = WalletContext.of(context);
      if (_isOffer) {
        final result = await WalletOid4vci(
          CredentialStore(wallet.services),
        ).intakeOffer(uri, onProgress: (stage) => setState(() => _info = stage));
        if (!mounted) return;
        if (result is IssuancePending) {
          setState(() => _info =
              'deferred - poll after ${result.interval}s (tx ${result.transactionId})');
        } else if (result is StoredCredentialView) {
          Navigator.of(context)
              .pushReplacement<void, void>(MaterialPageRoute(builder: (_) => const VaultPage()));
          return;
        }
      } else {
        // The presentation round: resolve -> the consent screen.
        final preview = await WalletOid4vp(
          CredentialStore(wallet.services),
        ).resolveRequest(uri);
        if (!mounted) return;
        Navigator.of(context).pushReplacement<void, void>(
          MaterialPageRoute(builder: (_) => ConsentPage(preview: preview)),
        );
        return;
      }
    } catch (e) {
      setState(() => _error = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Scan')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'The scanned URI (the offer or the request)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              if (_info != null) ...[
                Text(_info!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
              ],
              if (_error != null) ...[
                ErrorPage(error: 'intake error', description: _error!),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _busy ? null : _intake,
                child: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Proceed'),
              ),
            ],
          ),
        ),
      );
}

/// The consent page - the pre-disclosure preview (§15.1): the
/// verifier identity + every requested claim BEFORE any release;
/// approve/decline. The decline answers access_denied (§8.5).
class ConsentPage extends StatelessWidget {
  const ConsentPage({super.key, required this.preview});

  final ConsentPreview preview;

  @override
  Widget build(BuildContext context) {
    final wallet = WalletContext.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Consent')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Verifier', style: Theme.of(context).textTheme.titleMedium),
            Text(preview.verifierHost.isEmpty
                ? preview.verifierClientId
                : preview.verifierHost),
            Text(preview.verifierClientId,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Text('Requested claims',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final credential in preview.requested) ...[
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: Text(credential.typeLabel ?? credential.format),
                      subtitle: Text(credential.claims.join(', ')),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final outcome = await WalletOid4vp(
                        CredentialStore(wallet.services),
                      ).present(session: preview.session, approved: false);
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement<void, void>(
                          MaterialPageRoute(
                              builder: (_) => OutcomePage(outcome: outcome)),
                        );
                      }
                    },
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final outcome = await WalletOid4vp(
                        CredentialStore(wallet.services),
                      ).present(session: preview.session, approved: true);
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement<void, void>(
                          MaterialPageRoute(
                              builder: (_) => OutcomePage(outcome: outcome)),
                        );
                      }
                    },
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The outcome page - the post-presentation landing: the redirect
/// the browser MUST open (§8.2) or the visible error (§8.5 - the
/// negative surface the suites screenshot).
class OutcomePage extends StatelessWidget {
  const OutcomePage({super.key, required this.outcome});

  final PresentationOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final error = outcome.error;
    return Scaffold(
      appBar: AppBar(
          title: Text(error == null ? 'Presented' : 'Presentation failed')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(error == null ? Icons.check_circle : Icons.error_outline,
                  size: 64,
                  color: error == null ? Colors.green : Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              if (error == null) ...[
                const Text('The credentials were shared to the verifier.'),
                if (outcome.redirectUrl != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      // §8.2: the redirect_uri MUST open in the
                      // browser (the web bridge; the dc_api promise
                      // resolves in the shim).
                      _openRedirect(context, outcome.redirectUrl!);
                    },
                    child: const Text('Continue'),
                  ),
                ],
              ] else ...[
                Text(error,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center),
                if (outcome.errorDescription != null) ...[
                  const SizedBox(height: 8),
                  Text(outcome.errorDescription!,
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openRedirect(BuildContext context, String url) {
    // The web bridge (dart:js via the shim) - the platform's
    // url_launcher lands with the mobile targets.
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('The verifier redirected'),
        content: Text(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// The error page - the negative surface (the prescribed §8.5
/// error code + description rendered visibly; the suites' screenshot
/// upload reads this).
class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key, required this.error, required this.description});

  final String error;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(error,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.error)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(description,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
}
