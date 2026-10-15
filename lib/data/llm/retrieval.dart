import 'dart:typed_data';

import '../local/app_database.dart';
import '../local/memo_codec.dart' show MemoRecord;
import '../../core/utils/vector_math.dart';
import '../repositories/llm_repository.dart';

/// A retrieval hit: the memo record plus its cosine score.
class ScoredMemo {
  const ScoredMemo(this.record, this.score);

  final MemoRecord record;
  final double score;
}

/// Shared semantic retrieval for search and chat. Adds two P2-deferred
/// guardrails: a per-(model, query) embedding cache so repeated searches /
/// follow-up questions don't re-bill, and a minimum cosine threshold so
/// weakly-related hits stay out of both surfaces.
///
/// Transport failures propagate ([LlmApiException]); callers decide
/// degradation (search hides, chat reports).
class RetrievalService {
  RetrievalService({required this._db, required this._repository});

  static const double minScore = 0.30;
  static const int queryCacheLimit = 50;

  final AppDatabase _db;
  final LlmRepository _repository;
  final _queryCache = <String, List<double>>{};

  Future<List<ScoredMemo>> retrieve(String accountId, String query,
      {int k = 12}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final settings = await _repository.load();
    if (!settings.embeddingsConfigured) return const [];
    final model = settings.embeddingModel.trim();

    final vectors = await _db.embeddingDao.vectorsForModel(accountId, model);
    if (vectors.isEmpty) return const [];

    final queryVector = await _cachedQueryVector(model, trimmed, settings);
    if (queryVector == null) return const [];

    final top = await topKSimilar(Float32List.fromList(queryVector),
        {for (final row in vectors) row.uid: row.bytes}, k);
    final aboveThreshold = [
      for (final scored in top)
        if (scored.score >= minScore) scored
    ];
    final records = await _db.memoDao.recordsByUids(
        accountId, [for (final s in aboveThreshold) s.uid]);
    final byUid = {for (final r in records) r.memo.uid: r};
    return [
      for (final s in aboveThreshold)
        if (byUid[s.uid] != null) ScoredMemo(byUid[s.uid]!, s.score),
    ];
  }

  Future<List<double>?> _cachedQueryVector(
      String model, String query, LlmSettings settings) async {
    final key = '$model|$query';
    final hit = _queryCache[key];
    if (hit != null) return hit;
    final vectors = await _repository.embeddings(settings, inputs: [query]);
    if (vectors.isEmpty || vectors.first.isEmpty) return null;
    if (_queryCache.length >= queryCacheLimit) {
      _queryCache.remove(_queryCache.keys.first);
    }
    _queryCache[key] = vectors.first;
    return vectors.first;
  }
}
