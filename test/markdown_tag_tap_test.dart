import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/widgets/memo_markdown.dart';

/// Regression for: tapping a Chinese `#tag` chip navigated to the
/// percent-encoded tag (`#%E4%B8%AD%E6%96%87`), so the tag page title showed
/// mojibake and its feed came back empty. The markdown parser normalizes link
/// destinations with `Uri.encodeFull` (CommonMark), so the synthetic
/// `(#tag:中文标签)` destination reaches `onTapLink` percent-encoded and must
/// be decoded before handing the tag on.
void main() {
  Future<List<String>> tapTag(WidgetTester tester, String content,
      String chipText) async {
    final tapped = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MemoMarkdown(content: content, onTagTap: tapped.add),
      ),
    ));

    // The chip renders as link text `#<tag>`; keep it alone in the content so
    // it is the paragraph's whole RichText and findable by text.
    await tester.tap(find.text(chipText, findRichText: true));
    return tapped;
  }

  testWidgets('chinese tag decodes round-trip', (tester) async {
    final tapped = await tapTag(tester, '#中文标签', '#中文标签');
    expect(tapped, ['中文标签']);
  });

  testWidgets('nested chinese tag decodes round-trip', (tester) async {
    final tapped = await tapTag(tester, '#读书/笔记', '#读书/笔记');
    expect(tapped, ['读书/笔记']);
  });

  testWidgets('ascii and special-char tags still work', (tester) async {
    for (final (chip, tag) in [
      ('#test', 'test'),
      ('#100%', '100%'),
      ('#C++', 'C++'),
    ]) {
      final tapped = await tapTag(tester, chip, chip);
      expect(tapped, [tag], reason: chip);
    }
  });
}
