import '../local/app_database.dart';
import 'ai_activity_guard.dart';
import 'vectorization_engine.dart';

/// Deletes locally stored AI artifacts that were produced with the LLM
/// config. The config itself is global (one key for every account), so this
/// clears embeddings, chats, and suggestion caches for every account.
/// [clearDigests] removes the review-summary cache (kept outside this
/// library so the data layer does not depend on feature code). Memos and
/// their tags stay.
///
/// [vectorization], when the active account has a running engine, is told
/// to drop its in-flight pass first so that pass cannot write vectors back.
/// [guard] does the same for suggestion and chat completions.
Future<void> wipeLocalAiArtifacts({
  required AppDatabase db,
  required Future<void> Function() clearDigests,
  VectorizationEngine? vectorization,
  AiActivityGuard? guard,
}) async {
  guard?.invalidate();
  vectorization?.abandonInFlight();
  await db.embeddingDao.deleteAll();
  await db.chatDao.deleteAll();
  await db.suggestionDao.deleteAll();
  await clearDigests();
}
