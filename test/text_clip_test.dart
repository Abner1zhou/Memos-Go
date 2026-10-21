import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/text_clip.dart';

void main() {
  test('short text passes through trimmed', () {
    expect(clipText('  hello  ', 10), 'hello');
  });

  test('clips at grapheme boundaries (emoji safe)', () {
    expect(clipText('a😀b', 2), 'a😀…');
    // ZWJ 组合的家庭 emoji 是一个 grapheme cluster；旧的 UTF-16 substring
    // 会把它劈成孤立代理对。截 2 个 cluster 应保住完整 emoji + 下一个字。
    expect(clipText('👨‍👩‍👧家庭', 2), '👨‍👩‍👧家…');
  });

  test('exactly-at-limit text is unchanged', () {
    expect(clipText('四个', 2), '四个');
    expect(clipText('ab', 2), 'ab');
  });
}
