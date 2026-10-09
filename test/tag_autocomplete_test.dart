import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/formatters.dart';
import 'package:memos_go/features/memo_editor/memo_editor_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/memo_providers.dart';

void main() {
  group('tagTokenAt', () {
    test('finds the token being typed at end of text', () {
      expect(tagTokenAt('hello #re', 9), (start: 6, end: 9, query: 're'));
    });

    test('empty query right after #', () {
      expect(tagTokenAt('#', 1), (start: 0, end: 1, query: ''));
      expect(tagTokenAt('hi #', 4), (start: 3, end: 4, query: ''));
    });

    test('token mid-text stops at following whitespace', () {
      expect(tagTokenAt('#work rest', 5), (start: 0, end: 5, query: 'work'));
    });

    test('nested tag with slash stays one token', () {
      expect(tagTokenAt('#a/b ', 4), (start: 0, end: 4, query: 'a/b'));
    });

    test('caret inside a token does not trigger', () {
      expect(tagTokenAt('#work rest', 3), isNull);
    });

    test('hash glued to a word does not trigger', () {
      expect(tagTokenAt('a#b', 3), isNull);
    });

    test('double hash does not trigger', () {
      expect(tagTokenAt('##', 2), isNull);
    });

    test('plain text without hash returns null', () {
      expect(tagTokenAt('plain words', 11), isNull);
    });

    test('caret at text start or beyond returns null', () {
      expect(tagTokenAt('#work', 0), isNull);
      expect(tagTokenAt('#work', 99), isNull);
    });
  });

  group('editor tag autocomplete', () {
    const knownTags = <String, int>{
      'work': 5,
      'work/life': 1,
      'reading': 2,
      '旅行': 3,
    };

    Future<void> pumpEditor(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          userTagsProvider.overrideWith((ref) async => knownTags),
        ],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const MemoEditorPage(),
        ),
      ));
      await tester.pump();
    }

    TextField editor(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField));

    /// One pump for the text-change rebuild, one for the tag directory
    /// (a FutureProvider) to resolve and notify.
    Future<void> typeAndWait(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.pump();
    }

    testWidgets('suggests matching tags while typing #query', (tester) async {
      await pumpEditor(tester);
      await typeAndWait(tester, 'hello #re');
      expect(find.text('#reading'), findsOneWidget);
      expect(find.text('#work'), findsNothing);
    });

    testWidgets('empty query after # ranks by usage', (tester) async {
      await pumpEditor(tester);
      await typeAndWait(tester, 'note #');

      final chips = tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .map((c) => (c.label as Text).data)
          .toList();
      expect(chips, ['#work', '#旅行', '#reading', '#work/life']);
    });

    testWidgets('tapping a suggestion completes the tag', (tester) async {
      await pumpEditor(tester);
      await typeAndWait(tester, 'hello #re');

      await tester.tap(find.text('#reading'));
      await tester.pump();

      final field = editor(tester);
      expect(field.controller!.text, 'hello #reading ');
      expect(field.controller!.selection.baseOffset,
          'hello #reading '.length);
      // The suggestion row collapses; the tag now surfaces as the regular
      // (deletable) chip below the composer.
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(Chip), findsOneWidget);
    });

    testWidgets('no suggestions outside a tag token', (tester) async {
      await pumpEditor(tester);
      await typeAndWait(tester, 'plain words');
      expect(find.byType(ActionChip), findsNothing);
    });
  });
}
