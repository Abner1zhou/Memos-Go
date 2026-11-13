import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/llm/suggestion_engine.dart';
import 'ai_privacy_providers.dart';
import 'auth_providers.dart';
import 'llm_providers.dart';
import 'retrieval_providers.dart';
import 'settings_providers.dart';
import 'sync_providers.dart' show appDatabaseProvider;

/// Save-time suggestion engine bound to the active account (null signed
/// out). A settings save re-arms nothing special: the corpus watcher and
/// per-run settings load pick config changes up naturally.
///
/// Locale is read when a drain runs, not watched here: watching it would
/// rebuild the engine and re-seed the corpus snapshot, which skips
/// suggestions for memos already in that snapshot.
final suggestionEngineProvider = Provider<SuggestionEngine?>((ref) {
  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return null;
  final engine = SuggestionEngine(
    accountId: account.id,
    db: ref.watch(appDatabaseProvider),
    repository: ref.watch(llmRepositoryProvider),
    retrieval: ref.watch(retrievalServiceProvider),
    language: () => resolveSuggestionLanguage(
      localeCode: ref.read(settingsProvider).localeCode,
      platformLocales: WidgetsBinding.instance.platformDispatcher.locales,
    ),
    guard: ref.watch(aiActivityGuardProvider),
  );
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});
