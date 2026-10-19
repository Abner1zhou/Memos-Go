import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/widgets/memo_markdown.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpMd(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ));
  }

  testWidgets('[n] markers become tappable cite links when requested',
      (tester) async {
    final tapped = <int>[];
    // Each `[n]` sits alone in its paragraph: flutter_markdown renders a
    // paragraph as one RichText, so a span is findable/tappable by text only
    // when it is the paragraph's whole content (see markdown_tag_tap_test).
    await pumpMd(
        tester,
        MemoMarkdown(
          content: '[1]\n\n[2]',
          onCiteTap: tapped.add,
        ));
    await tester.tap(find.text('[1]', findRichText: true));
    await tester.tap(find.text('[2]', findRichText: true));
    expect(tapped, [1, 2]);
  });

  testWidgets('without onCiteTap, [n] stays plain text', (tester) async {
    await pumpMd(tester, const MemoMarkdown(content: '见 [1]'));
    // The paragraph keeps its literal text; no standalone `[n]` link is built.
    expect(find.text('见 [1]', findRichText: true), findsOneWidget);
    expect(find.text('[1]', findRichText: true), findsNothing);
  });
}
