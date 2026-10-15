import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/llm/retrieval.dart';
import 'llm_providers.dart';
import 'sync_providers.dart' show appDatabaseProvider;

/// Singleton (its query-embedding cache is process state).
final retrievalServiceProvider = Provider<RetrievalService>((ref) =>
    RetrievalService(
        db: ref.watch(appDatabaseProvider),
        repository: ref.watch(llmRepositoryProvider)));
