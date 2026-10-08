import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:memos_go/app.dart';

/// End-to-end flow against a LAN Memos server (10.0.117.23:5230) with the
/// seed user abner/test12345. Override by editing here or spinning up a local
/// docker instance instead.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // LAN address: reachable from both the iOS simulator and the Android
  // emulator without the 10.0.2.2 loopback alias.
  const serverAddress = 'http://10.0.117.23:5230';

  Finder i18n(String zh, String en) =>
      find.text(zh).evaluate().isNotEmpty ? find.text(zh) : find.text(en);

  Future<void> waitFor(WidgetTester tester, Finder finder,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 300));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('waitFor timed out: $finder');
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    // Dismiss the on-screen keyboard first, otherwise it covers buttons on
    // Android and taps land on the IME instead of the target.
    await SystemChannels.textInput.invokeMethod('TextInput.hide');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(finder);
  }

  testWidgets('password login -> create memo -> list shows it',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MemosGoApp()));

    // Wait for routing to settle: the login page flashes briefly during
    // auth restore even when an account exists, so prefer waiting for the
    // home page (hamburger menu in the app bar) and only fall back to the
    // login form when it never comes.
    final loginTitle = find.text('Sign in to Memos');
    final homeMenu = find.byIcon(Icons.menu);
    await tester.pump(const Duration(seconds: 1));
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (homeMenu.evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    if (homeMenu.evaluate().isEmpty) {
      await waitFor(tester, loginTitle);
      final serverField = find.byType(TextFormField).first;
      await tester.enterText(serverField, serverAddress);
      await tester.pump();
      await tapVisible(tester, i18n('下一步', 'Next'));
      await waitFor(tester, find.byType(SegmentedButton<int>));

      // --- password tab ---
      final fields = find.byType(TextFormField);
      expect(fields, findsAtLeastNWidgets(3));
      await tester.enterText(fields.at(1), 'abner');
      await tester.enterText(fields.at(2), 'test12345');
      await tester.pump();
      await tapVisible(tester, i18n('登录', 'Sign in'));
    }
    debugPrint('SCREEN-B: ${tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toSet()
        .join(' | ')}');
    await waitFor(tester, homeMenu, timeout: const Duration(seconds: 20));

    // --- open editor via the green "+" composer button ---
    await tapVisible(tester, find.byIcon(Icons.add));
    await waitFor(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).first,
        '集成测试笔记 #e2e ${DateTime.now().millisecondsSinceEpoch}');
    await tester.pump();
    await tapVisible(tester, i18n('保存', 'Save'));
    await waitFor(tester, find.textContaining('集成测试笔记'),
        timeout: const Duration(seconds: 20));
  });
}
