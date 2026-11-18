// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';

import 'package:wallet8_wallet/main.dart';

void main() {
  testWidgets('the app boots to the vault page', (WidgetTester tester) async {
    await tester.pumpWidget(const Wallet8App());
    await tester.pumpAndSettle();
    // The vault is the landing surface (the empty-state prompt).
    expect(find.textContaining('credentials'), findsWidgets);
  });
}
