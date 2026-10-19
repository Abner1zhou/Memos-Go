import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  /// Center (in global coordinates) of the first occurrence of [span] inside
  /// the paragraph whose plain text contains [paragraphNeedle]. Needed when
  /// the span is not the paragraph's whole RichText — the standalone-`[n]`
  /// pattern above only covers links alone in their paragraph — so the range
  /// is located via caret offsets and tapped at its middle.
  Offset spanCenter(WidgetTester tester, String paragraphNeedle, String span) {
    final para = tester.renderObject<RenderParagraph>(
        find.textContaining(paragraphNeedle, findRichText: true).first);
    final plain = para.text.toPlainText();
    final start = plain.indexOf(span);
    expect(start, isNonNegative, reason: '"$span" not found in "$plain"');
    final x1 =
        para.getOffsetForCaret(TextPosition(offset: start), Rect.zero).dx;
    final x2 = para
        .getOffsetForCaret(TextPosition(offset: start + span.length), Rect.zero)
        .dx;
    return para.localToGlobal(Offset((x1 + x2) / 2, para.size.height / 2));
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

  testWidgets('code spans keep their [n]; only the real cite is linked',
      (tester) async {
    final tapped = <int>[];
    await pumpMd(
        tester,
        MemoMarkdown(
          // The rewrite used to restore code before citifying, corrupting
          // `arr[1]` into `arr[[1]](#cite:1)` inside the span.
          content: '见 `arr[1]` 与 [2]。',
          onCiteTap: tapped.add,
        ));
    // The code span renders verbatim — no rewritten cite link inside it.
    expect(find.textContaining('arr[1]', findRichText: true), findsOneWidget);
    // Tapping inside the code span fires no cite; the real `[2]` does.
    await tester.tapAt(spanCenter(tester, 'arr[1]', 'arr[1]'));
    await tester.pump();
    await tester.tapAt(spanCenter(tester, 'arr[1]', '[2]'));
    await tester.pump();
    expect(tapped, [2]);
  });

  testWidgets('existing markdown links survive the cite rewrite',
      (tester) async {
    final tapped = <int>[];
    final opened = <String>[];
    final prevDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      const prefix = 'open url: ';
      if (message != null && message.startsWith(prefix)) {
        opened.add(message.substring(prefix.length));
      }
    };
    // Restored before the body ends: the framework's foundation-var
    // invariant check runs before addTearDown.
    try {
      await pumpMd(
          tester,
          MemoMarkdown(
            content: '[文档](https://x.example) 和 [3]',
            onCiteTap: tapped.add,
          ));
      // The plain link text renders unchanged.
      expect(find.textContaining('文档', findRichText: true), findsOneWidget);
      // The real cite still fires…
      await tester.tapAt(spanCenter(tester, '文档', '[3]'));
      await tester.pump();
      expect(tapped, [3]);
      // …and `[文档](…)` remains a genuine url link.
      await tester.tapAt(spanCenter(tester, '文档', '文档'));
      await tester.pump();
      expect(opened, ['https://x.example']);
    } finally {
      debugPrint = prevDebugPrint;
    }
  });

  testWidgets('fenced code keeps its [n]; the real cite still links',
      (tester) async {
    final tapped = <int>[];
    await pumpMd(
        tester,
        MemoMarkdown(
          content: '```\nmatrix[4] = 1\n```\n\n参考 [1]',
          onCiteTap: tapped.add,
        ));
    // The fence keeps its literal content — no cite rewrite inside it.
    expect(
        find.textContaining('matrix[4]', findRichText: true), findsOneWidget);
    // Tapping the fence region fires no cite; the real `[1]` does (not alone
    // in its paragraph, so aim at the span).
    await tester.tapAt(spanCenter(tester, 'matrix[4]', 'matrix[4]'));
    await tester.pump();
    await tester.tapAt(spanCenter(tester, '参考', '[1]'));
    await tester.pump();
    expect(tapped, [1]);
  });
}
