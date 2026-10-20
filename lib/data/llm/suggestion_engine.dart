import 'dart:async';
import 'dart:convert' show JsonDecoder;

import 'package:flutter/foundation.dart';

import '../../core/utils/stable_hash.dart';
import '../../core/utils/text_clip.dart';
import '../api/llm_api.dart';
import '../local/app_database.dart';
import '../local/memo_codec.dart' show MemoRecord;
import '../local/suggestion_dao.dart';
import '../repositories/llm_repository.dart';
import 'retrieval.dart';

/// Parses the model's suggestion output: strips ```json fences, extracts
/// the first balanced {...} block, then validates against the retrieval
/// candidates. Tags: ≤3, deduped, '#' stripped, non-empty, clipped to 24
/// chars. Related: ≤3, must reference a candidate (by 1-based number or
/// full name), self excluded, deduped, order preserved. Returns null on
/// any malformed output.
MemoSuggestion? parseSuggestion(String raw,
    {required List<String> candidateUids, required String selfName}) {
  var text = raw.trim();
  final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
  final m = fence.firstMatch(text);
  if (m != null) text = m.group(1)!.trim();
  final start = text.indexOf('{');
  if (start < 0) return null;
  var depth = 0;
  var end = -1;
  for (var i = start; i < text.length; i++) {
    final ch = text[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  if (end < 0) return null;
  final json = _decodeJson(text.substring(start, end + 1));
  if (json is! Map) return null;

  final tags = <String>[];
  final rawTags = json['tags'];
  if (rawTags is List) {
    for (final t in rawTags) {
      if (t is! String) continue;
      final tag = clipText(t.trim().replaceFirst(RegExp('^#+'), ''), 24);
      if (tag.isEmpty || tags.contains(tag) || tags.length >= 3) continue;
      tags.add(tag);
    }
  }

  final byNumber = {
    for (var i = 0; i < candidateUids.length; i++) i + 1: candidateUids[i]
  };
  final related = <String>[];
  final rawRelated = json['related'];
  if (rawRelated is List) {
    for (final r in rawRelated) {
      String? name;
      if (r is int) name = byNumber[r];
      if (r is String && candidateUids.contains(r)) name = r;
      if (name == null || name == selfName || related.contains(name)) continue;
      if (related.length >= 3) break;
      related.add(name);
    }
  }
  return MemoSuggestion(tags: tags, relatedUids: related);
}

Object? _decodeJson(String src) {
  try {
    return _jsonDecode(src);
  } catch (_) {
    return null;
  }
}

Object? _jsonDecode(String src) => _decoder.convert(src);
const _decoder = JsonDecoder();

/// Save-time suggestions per spec §7: watches the corpus stream with a
/// uid→contentHash snapshot; the FIRST emission only seeds the snapshot
/// (no backfill of the existing corpus), later new/changed memos are
/// queued, debounced, and each gets one retrieval + one JSON completion.
/// Failures are silent (lastError), never blocking, never retried.
class SuggestionEngine {
  SuggestionEngine({
    required this.accountId,
    required this._db,
    required this._repository,
    required this._retrieval,
  });

  static const debounce = Duration(seconds: 5);
  static const candidateCount = 6;
  static const excerptChars = 400;

  final String accountId;
  final AppDatabase _db;
  final LlmRepository _repository;
  final RetrievalService _retrieval;

  final lastError = ValueNotifier<String?>(null);

  final Map<String, int> _snapshot = {};
  final Set<String> _pending = {};
  bool _seeded = false;
  bool _running = false;
  Timer? _timer;
  StreamSubscription<List<MemoRecord>>? _corpusSub;

  void start() {
    _corpusSub = _db.memoDao.watchAll(accountId).listen(_onCorpus);
  }

  void _onCorpus(List<MemoRecord> records) {
    final next = <String, int>{
      for (final r in records) r.memo.uid: stableHash(r.memo.content),
    };
    if (!_seeded) {
      _seeded = true;
      _snapshot.addAll(next);
      return; // 首帧只建快照：存量语料不回填（spec：保存后触发）。
    }
    var changed = false;
    for (final uid in {..._snapshot.keys}..removeAll(next.keys)) {
      _snapshot.remove(uid);
      _pending.remove(uid);
      _db.suggestionDao.deleteForMemo(accountId, uid);
    }
    next.forEach((uid, hash) {
      if (_snapshot[uid] != hash) {
        _snapshot[uid] = hash;
        _pending.add(uid);
        changed = true;
      }
    });
    if (changed) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer(debounce, run);
  }

  /// Runs one drain of the queue. Never throws.
  Future<void> run({String language = 'zh'}) async {
    if (_running) return;
    _running = true;
    try {
      final settings = await _repository.load();
      if (!settings.isConfigured ||
          !settings.suggestOnSave ||
          !settings.embeddingsConfigured) {
        _pending.clear();
        return;
      }
      while (_pending.isNotEmpty) {
        final uid = _pending.first;
        _pending.remove(uid);
        try {
          final record = await _db.memoDao.getMemo(accountId, uid);
          if (record == null) continue;
          final content = record.memo.content;
          final contentHash = stableHash(content);
          final existing =
              await _db.suggestionDao.watchSuggestion(accountId, uid).first;
          if (existing != null && existing.contentHash == contentHash) {
            continue;
          }

          var hits = await _retrieval.retrieve(accountId, content,
              k: candidateCount);
          hits = [
            for (final h in hits)
              if (h.record.memo.name != record.memo.name) h
          ];
          final candidateUids = [
            for (final h in hits) h.record.memo.name
          ];
          if (candidateUids.isEmpty) continue;

          final tags = await _db.suggestionDao.distinctTags(accountId);
          final answer = await _repository.chat(
            settings,
            messages: [
              LlmChatMessage(role: 'system', content: _systemPrompt(language)),
              LlmChatMessage(
                  role: 'user',
                  content: _userPrompt(
                      content,
                      tags,
                      [for (final h in hits) h.record],
                      language)),
            ],
            maxTokens: 256,
          );
          final suggestion = parseSuggestion(answer,
              candidateUids: candidateUids, selfName: record.memo.name);
          // 无论建议是否为空都落库：空建议行也是"这一版内容已算过"的缓存标记，
          // 否则每次语料变动都会把同一条重算一遍（重试风暴的反面教材）。
          if (suggestion == null) continue;
          await _db.suggestionDao.upsert(
            accountId,
            uid,
            contentHash: contentHash,
            suggestion: suggestion,
            now: DateTime.now(),
          );
        } on LlmApiException catch (e) {
          lastError.value = e.message;
        } catch (e) {
          lastError.value = e.toString();
        }
      }
    } catch (e) {
      // Last resort: settings load must never crash the caller (this also
      // runs off the debounce Timer).
      lastError.value = e.toString();
    } finally {
      _running = false;
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _corpusSub?.cancel();
  }

  static String _systemPrompt(String language) => language == 'en'
      ? 'You suggest metadata for a just-saved note. Answer with JSON ONLY, '
        'no prose: {"tags": [up to 3 strings], "related": [up to 3 numbers]} '
        '-- tags prefer the listed existing tags; related picks the most '
        'relevant numbered candidates (or omit both arrays when nothing fits).'
      : '你为刚保存的笔记建议元数据。只输出 JSON，不要任何其他文字：'
        '{"tags": [最多 3 个字符串], "related": [最多 3 个编号]}'
        '——tags 优先从列出的已有标签中选；related 选最相关的编号候选；都不合适可为空数组。';

  static String _userPrompt(String content, List<String> tags,
      List<MemoRecord> records, String language) {
    final b = StringBuffer();
    b.writeln(language == 'en'
        ? 'Existing tags: ${tags.join(', ')}'
        : '已有标签：${tags.join('、')}');
    b.writeln();
    b.writeln(language == 'en' ? 'Candidate related memos:' : '候选相关记忆：');
    for (var i = 0; i < records.length; i++) {
      b.writeln('[${i + 1}] ${clipText(records[i].memo.content, excerptChars)}');
    }
    b.writeln();
    b.writeln(language == 'en' ? 'New note:' : '新笔记：');
    b.writeln(clipText(content, excerptChars));
    return b.toString();
  }
}
