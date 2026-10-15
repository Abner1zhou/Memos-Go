import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/vector_math.dart';
import '../data/local/memo_codec.dart' show MemoRecord;
import 'auth_providers.dart';
import 'llm_providers.dart';
import 'sync_providers.dart' show appDatabaseProvider;

/// Semantic top-12 for a query, ranked by cosine similarity against the
/// account's stored vectors. Degrades to an empty list when the LLM layer
/// is unconfigured, has no embedding model, holds no vectors, or the
/// endpoint fails — keyword search never breaks because of it.
final semanticSearchProvider =
    FutureProvider.autoDispose.family<List<MemoRecord>, String>(
        (ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];

  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return const [];

  final repo = ref.watch(llmRepositoryProvider);
  final settings = await repo.load();
  if (!settings.embeddingsConfigured) return const [];

  final db = ref.watch(appDatabaseProvider);
  final model = settings.embeddingModel.trim();
  final vectors = await db.embeddingDao.vectorsForModel(account.id, model);
  if (vectors.isEmpty) return const [];

  final List<List<double>> queryVectors;
  try {
    queryVectors = await repo.embeddings(settings, inputs: [trimmed]);
  } catch (_) {
    return const [];
  }
  if (queryVectors.isEmpty || queryVectors.first.isEmpty) return const [];

  final top = await topKSimilar(
      Float32List.fromList(queryVectors.first),
      {for (final row in vectors) row.uid: row.bytes},
      12);
  return db.memoDao.recordsByUids(
      account.id, [for (final scored in top) scored.uid]);
});
