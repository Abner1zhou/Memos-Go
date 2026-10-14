import 'dart:convert' as convert;

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/models.dart';

/// Token guardrails: each memo is clipped and each group capped before the
/// prompt is assembled, so digest cost stays bounded on busy days.
const _maxMemosPerGroup = 20;
const _maxCharsPerMemo = 400;

/// Input bundle for the daily review digest: memos created today plus the
/// "on this day in past years" groups the review page already computed.
class ReviewDigestInput {
  const ReviewDigestInput({required this.today, required this.onThisDay});

  final List<Memo> today;

  /// Year -> same-day memos written that year.
  final Map<int, List<Memo>> onThisDay;

  /// Cheap fingerprint of the inputs; a changed fingerprint invalidates the
  /// cached digest (memos added or edited today -> offer regenerate).
  String fingerprint() {
    final parts = <String>[];
    void add(Memo m) => parts.add(
        '${m.name}:${m.updateTime?.millisecondsSinceEpoch ?? m.createTime?.millisecondsSinceEpoch ?? 0}');
    for (final m in today) {
      add(m);
    }
    for (final e in onThisDay.entries) {
      for (final m in e.value) {
        add(m);
      }
    }
    return parts.join('|');
  }
}

/// System prompt for the digest. [language] is an ISO code ('zh' / 'en').
String reviewDigestSystemPrompt(String language) => language == 'en'
    ? 'You are a warm, concise journaling assistant. Answer ONLY from the '
      'memories provided in the user message; do not invent facts. Reply in '
      'English using Markdown with two sections: "Today" (3-5 bullet key '
      'points from today\'s memos) and, when past-year memories are present, '
      '"Echoes" (connections between today and those memories).'
    : '你是一位温暖、简洁的日记助手。只依据用户消息中给出的记忆回答，不要编造事实。'
      '用中文以 Markdown 回复，包含两个小节："今日要点"（今天的笔记提炼 3-5 条要点）；'
      '若提供了往年今日的记忆，再加"记忆呼应"小节，点出今天的记录与往年记忆的关联。';

/// Renders the input memos into the user message: today's memos first, then
/// past-year groups, each memo clipped to [_maxCharsPerMemo] characters and
/// each group capped at [_maxMemosPerGroup] memos.
String buildReviewDigestUserPrompt(
  ReviewDigestInput input, {
  required DateTime now,
  String language = 'zh',
}) {
  final b = StringBuffer();
  final day =
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  if (language == 'en') {
    b.writeln('Today is $day. The memos written today:');
  } else {
    b.writeln('今天是 $day。以下是用户今天的笔记：');
  }
  var i = 0;
  for (final memo in input.today.take(_maxMemosPerGroup)) {
    b.writeln('${++i}. ${_clip(memo.content)}');
  }
  if (input.onThisDay.isNotEmpty) {
    if (language == 'en') {
      b.writeln('\nMemos written on this day in past years:');
    } else {
      b.writeln('\n往年的今天，用户写过：');
    }
    final years = input.onThisDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final year in years) {
      for (final memo in input.onThisDay[year]!.take(_maxMemosPerGroup)) {
        b.writeln('- [$year] ${_clip(memo.content)}');
      }
    }
  }
  return b.toString();
}

String _clip(String content) {
  final c = content.trim();
  return c.length <= _maxCharsPerMemo ? c : '${c.substring(0, _maxCharsPerMemo)}…';
}

/// One cached digest for a given local day.
class ReviewDigestEntry {
  const ReviewDigestEntry({
    required this.content,
    required this.fingerprint,
    required this.generatedAt,
  });

  final String content;

  /// Fingerprint of [ReviewDigestInput] at generation time.
  final String fingerprint;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'content': content,
        'fingerprint': fingerprint,
        'generatedAt': generatedAt.toIso8601String(),
      };

  factory ReviewDigestEntry.fromJson(Map<String, dynamic> json) =>
      ReviewDigestEntry(
        content: json['content'] as String? ?? '',
        fingerprint: json['fingerprint'] as String? ?? '',
        generatedAt:
            DateTime.tryParse(json['generatedAt'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Daily digest cache in shared preferences, one key per local day; only the
/// newest 7 day keys are kept so the cache cannot grow unboundedly.
class ReviewDigestCache {
  static const _prefix = 'memos_go.reviewDigest.';

  Future<ReviewDigestEntry?> load(String dayKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$dayKey');
    if (raw == null) return null;
    try {
      final json = convert.jsonDecode(raw);
      if (json is Map) {
        return ReviewDigestEntry.fromJson(json.cast<String, dynamic>());
      }
    } catch (_) {
      // Fall through to null on corrupt JSON.
    }
    return null;
  }

  Future<void> save(String dayKey, ReviewDigestEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_prefix$dayKey', convert.jsonEncode(entry.toJson()));
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()
      ..sort();
    while (keys.length > 7) {
      await prefs.remove(keys.removeAt(0));
    }
  }
}
