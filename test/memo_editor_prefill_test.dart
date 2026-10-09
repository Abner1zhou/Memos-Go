import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/features/memo_editor/memo_editor_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';

void main() {
  Future<void> pumpEditor(WidgetTester tester, MemoEditorPage page) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ));
    await tester.pump();
  }

  testWidgets('initialTag prefills the composer with a removable #tag',
      (tester) async {
    await pumpEditor(
        tester, const MemoEditorPage(initialTag: '读书/笔记'));

    // Composer opens in create mode with `#tag ` prefilled, cursor at the end
    // so typing continues outside the tag.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '#读书/笔记 ');
    expect(field.controller!.selection.baseOffset, '#读书/笔记 '.length);

    // The prefilled tag surfaces as a removable chip.
    expect(find.byType(Chip), findsOneWidget);
    expect(find.text('#读书/笔记'), findsOneWidget);

    // Deleting the chip strips the tag from the content.
    await tester.tap(find.byIcon(Icons.cancel));
    await tester.pump();
    final cleared = tester.widget<TextField>(find.byType(TextField));
    expect(cleared.controller!.text, '');
  });

  testWidgets('without initialTag the composer starts empty', (tester) async {
    await pumpEditor(tester, const MemoEditorPage());

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '');
    expect(find.byType(Chip), findsNothing);
  });
}
