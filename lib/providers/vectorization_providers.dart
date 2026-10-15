import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/llm/vectorization_engine.dart';
import '../data/repositories/llm_repository.dart';
import 'auth_providers.dart';
import 'llm_providers.dart';
import 'sync_providers.dart' show appDatabaseProvider;

/// The vectorization engine bound to the active account (null signed out).
/// A settings save re-triggers a pass so a newly configured embedding model
/// starts indexing without waiting for a corpus change.
final vectorizationEngineProvider = Provider<VectorizationEngine?>((ref) {
  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return null;
  final engine = VectorizationEngine(
    accountId: account.id,
    db: ref.watch(appDatabaseProvider),
    repository: ref.watch(llmRepositoryProvider),
  );
  ref.listen<LlmSettings>(llmProvider, (_, _) => engine.schedule());
  engine.start();
  ref.onDispose(engine.dispose);
  return engine;
});

/// What the settings page progress section shows.
final vectorizationStateProvider = StreamProvider<VectorizationState>((ref) {
  final engine = ref.watch(vectorizationEngineProvider);
  if (engine == null) return Stream.value(const VectorizationState());
  final controller = StreamController<VectorizationState>();
  void listener() => controller.add(engine.state.value);
  engine.state.addListener(listener);
  // Seed with the current progress so a fresh subscriber (e.g. the settings
  // page opened mid-pass or after indexing) doesn't start at zero.
  controller.add(engine.state.value);
  controller.onCancel = () {
    engine.state.removeListener(listener);
    controller.close();
  };
  return controller.stream;
});
