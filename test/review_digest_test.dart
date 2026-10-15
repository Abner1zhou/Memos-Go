import 'dart:convert' as convert;

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/features/review/review_digest.dart';
import 'package:shared_preferences/shared_preferences.dart';

Memo _memo(
  String name,
  String content, {
  DateTime? created,
  DateTime? updated,
}) =>
    Memo(
      name: name,
      content: content,
      createTime: created,
      updateTime: updated,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('user prompt lists today memos then past-year groups', () {
    final input = ReviewDigestInput(
      today: [
        _memo('memos/a', '部署了 k8s 滚动更新'),
        _memo('memos/b', '读完《卡片笔记》第三章'),
      ],
      onThisDay: {
        2025: [_memo('memos/c', '去年今天在纠结选型')],
      },
    );

    final prompt = buildReviewDigestUserPrompt(input,
        now: DateTime(2026, 10, 14), language: 'zh');

    expect(prompt, contains('今天是 2026-10-14'));
    expect(prompt, contains('以下是用户今天的笔记'));
    expect(prompt, contains('1. 部署了 k8s 滚动更新'));
    expect(prompt, contains('2. 读完《卡片笔记》第三章'));
    expect(prompt, contains('往年的今天'));
    expect(prompt, contains('- [2025] 去年今天在纠结选型'));
  });

  test('english labels when language is en', () {
    final input = ReviewDigestInput(
      today: [_memo('memos/a', 'shipped the release')],
      onThisDay: const {},
    );
    final prompt = buildReviewDigestUserPrompt(input,
        now: DateTime(2026, 10, 14), language: 'en');
    expect(prompt, contains('Today is 2026-10-14'));
    expect(prompt, contains('1. shipped the release'));
    expect(prompt, isNot(contains('往年的今天')));
  });

  test('long memos are clipped and groups capped', () {
    final long = 'x' * 1000;
    final many = List.generate(
        30, (i) => _memo('memos/t$i', i == 0 ? long : 'memo $i'));
    final input = ReviewDigestInput(today: many, onThisDay: const {});

    final prompt = buildReviewDigestUserPrompt(input,
        now: DateTime(2026, 10, 14));

    expect(prompt, isNot(contains('memo 20\n')));
    expect(prompt, contains('memo 19'));
    final longest = prompt
        .split('\n')
        .reduce((a, b) => a.length >= b.length ? a : b);
    expect(longest.length, lessThanOrEqualTo(400 + 2 + '20. '.length));
  });

  test('fingerprint changes when a memo is edited', () {
    final a = ReviewDigestInput(today: [
      _memo('memos/a', 'v1', updated: DateTime(2026, 10, 14, 10)),
    ], onThisDay: const {});
    final b = ReviewDigestInput(today: [
      _memo('memos/a', 'v2', updated: DateTime(2026, 10, 14, 11)),
    ], onThisDay: const {});
    final c = ReviewDigestInput(today: [
      _memo('memos/a', 'v1', updated: DateTime(2026, 10, 14, 10)),
    ], onThisDay: const {});
    // Same content but a bumped timestamp alone also invalidates.
    final d = ReviewDigestInput(today: [
      _memo('memos/a', 'v1', updated: DateTime(2026, 10, 14, 12)),
    ], onThisDay: const {});

    expect(a.fingerprint(), c.fingerprint());
    expect(a.fingerprint(), isNot(b.fingerprint()));
    expect(a.fingerprint(), isNot(d.fingerprint()));
  });

  test('fingerprint changes when content changes but timestamp does not', () {
    final a = ReviewDigestInput(today: [
      _memo('memos/a', 'v1', updated: DateTime(2026, 10, 14, 10)),
    ], onThisDay: const {});
    final b = ReviewDigestInput(today: [
      _memo('memos/a', 'v2', updated: DateTime(2026, 10, 14, 10)),
    ], onThisDay: const {});

    expect(a.fingerprint(), isNot(b.fingerprint()));
  });

  test('system prompts name the two sections', () {
    expect(reviewDigestSystemPrompt('zh'), contains('今日要点'));
    expect(reviewDigestSystemPrompt('zh'), contains('记忆呼应'));
    expect(reviewDigestSystemPrompt('en'), contains('Today'));
    expect(reviewDigestSystemPrompt('en'), contains('Echoes'));
  });

  test('cache roundtrips an entry and prunes old day keys', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = ReviewDigestCache();
    final entry = ReviewDigestEntry(
      content: '## 今日要点\n- ok',
      fingerprint: 'fp-1',
      generatedAt: DateTime(2026, 10, 14, 21),
    );
    await cache.save('acc-1', '2026-10-14', entry);

    final loaded = await cache.load('acc-1', '2026-10-14');
    expect(loaded!.content, '## 今日要点\n- ok');
    expect(loaded.fingerprint, 'fp-1');
    expect(loaded.generatedAt, DateTime(2026, 10, 14, 21));

    // Older day keys get pruned once more than 7 pile up; another
    // account's keys are untouched.
    await cache.save('acc-2', '2026-10-13', entry);
    for (var i = 1; i <= 8; i++) {
      await cache.save('acc-1', '2026-09-${i.toString().padLeft(2, '0')}', entry);
    }
    final prefs = await SharedPreferences.getInstance();
    expect(await cache.load('acc-2', '2026-10-13'), isNotNull);
    final acc1Keys = prefs
        .getKeys()
        .where((k) => k.startsWith('memos_go.reviewDigest.acc-1.'));
    expect(acc1Keys.length, 7);
  });

  test('cache returns null on corrupt or missing data', () async {
    SharedPreferences.setMockInitialValues({
      'memos_go.reviewDigest.acc-1.2026-10-14': '{not json',
    });
    final cache = ReviewDigestCache();
    expect(await cache.load('acc-1', '2026-10-14'), isNull);
    expect(await cache.load('acc-1', '2026-10-13'), isNull);
    expect(await cache.load('acc-2', '2026-10-14'), isNull);
  });

  test('entry json roundtrip', () {
    final entry = ReviewDigestEntry(
      content: 'c',
      fingerprint: 'f',
      generatedAt: DateTime(2026, 10, 14, 21, 30),
    );
    final back =
        ReviewDigestEntry.fromJson(convert.jsonDecode(convert.jsonEncode(entry.toJson())) as Map<String, dynamic>);
    expect(back.content, 'c');
    expect(back.generatedAt, DateTime(2026, 10, 14, 21, 30));
  });
}
