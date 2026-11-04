import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/llm/ai_activity_guard.dart';
import '../data/llm/ai_privacy.dart';
import '../features/review/review_digest.dart';
import 'sync_providers.dart' show appDatabaseProvider;
import 'vectorization_providers.dart';

/// Shared epoch for in-flight suggestion and chat writes. Lives for the
/// whole container so a wipe can invalidate an engine that is mid-request
/// even if its provider is no longer watched.
final aiActivityGuardProvider = Provider<AiActivityGuard>((ref) {
  return AiActivityGuard();
});

/// Deletes local AI artifacts, then the caller clears the LLM credentials.
final aiArtifactWiperProvider = Provider<Future<void> Function()>((ref) {
  return () => wipeLocalAiArtifacts(
    db: ref.read(appDatabaseProvider),
    vectorization: ref.read(vectorizationEngineProvider),
    guard: ref.read(aiActivityGuardProvider),
    clearDigests: ReviewDigestCache().clearAll,
  );
});
