import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/llm/suggestion_engine.dart';
import 'auth_providers.dart';
import 'llm_providers.dart';
import 'retrieval_providers.dart';
import 'sync_providers.dart' show appDatabaseProvider;

/// Save-time suggestion engine bound to the active account (null signed
/// out). A settings save re-arms nothing special: the corpus watcher and
/// per-run settings load pick config changes up naturally.
final suggestionEngineProvider = Provider<SuggestionEngine?>((ref) {
  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return null;
  final engine = SuggestionEngine(
    accountId: account.id,
    db: ref.watch(appDatabaseProvider),
    repository: ref.watch(llmRepositoryProvider),
    retrieval: ref.watch(retrievalServiceProvider),
  );
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});
