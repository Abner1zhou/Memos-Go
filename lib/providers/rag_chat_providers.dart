import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/llm/rag_chat_engine.dart';
import 'auth_providers.dart';
import 'llm_providers.dart';
import 'retrieval_providers.dart';
import 'sync_providers.dart' show appDatabaseProvider;

/// RAG engine bound to the active account (null signed out).
final ragChatEngineProvider = Provider<RagChatEngine?>((ref) {
  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return null;
  return RagChatEngine(
    accountId: account.id,
    db: ref.watch(appDatabaseProvider),
    repository: ref.watch(llmRepositoryProvider),
    retrieval: ref.watch(retrievalServiceProvider),
  );
});
