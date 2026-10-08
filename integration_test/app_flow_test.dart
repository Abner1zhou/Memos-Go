import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:memos_go/app.dart';

/// End-to-end flow against the local docker Memos server (localhost:5230).
/// Requires: docker run -p 5230:5230 neosmemo/memos:stable with the seed
/// user abner/test12345 already created.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    await tester.ensureVisible(finder);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(finder);
  }

  testWidgets('password login -> create memo -> list shows it',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MemosGoApp()));

    // Wait for routing to settle: the login page flashes briefly during
    // auth restore even when an account exists, so prefer waiting for the
    // home shell and only fall back to the login form when it never comes.
    final loginTitle = find.text('Sign in to Memos');
    final homeShell = find.byType(NavigationBar);
    await tester.pump(const Duration(seconds: 1));
    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (homeShell.evaluate().isEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    if (homeShell.evaluate().isEmpty) {
      await waitFor(tester, loginTitle);
      final serverField = find.byType(TextFormField).first;
      await tester.enterText(serverField, 'http://localhost:5230');
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
    await waitFor(tester, i18n('新建笔记', 'New memo'),
        timeout: const Duration(seconds: 20));

    // --- open editor ---
    await tapVisible(tester, i18n('新建笔记', 'New memo'));
    await waitFor(tester, find.byType(TextField));
    await tester.enterText(find.byType(TextField).first,
        '集成测试笔记 #e2e ${DateTime.now().millisecondsSinceEpoch}');
    await tester.pump();
    await tapVisible(tester, i18n('保存', 'Save'));
    await waitFor(tester, find.textContaining('集成测试笔记'),
        timeout: const Duration(seconds: 20));

    await binding.takeScreenshot('after-create');
  });
}
