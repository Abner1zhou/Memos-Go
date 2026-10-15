import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/api/llm_api.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/llm_providers.dart';
import 'package:memos_go/providers/semantic_search_providers.dart';
import 'package:memos_go/providers/sync_providers.dart' show appDatabaseProvider;
import 'package:memos_go/providers/vectorization_providers.dart';

import 'helpers/offline_app.dart';

const _settings = LlmSettings(
  baseUrl: 'https://llm.example.com/v1',
  apiKey: 'sk-x',
  chatModel: 'c',
  embeddingModel: 'e-m',
);

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.signedIn,
        accounts: [testAccount],
        activeAccount: testAccount,
      );
}

class _EmbeddingRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async {
    // The query always embeds to "due east".
    if (inputs.length == 1) return const [[1.0, 0.0]];
    throw LlmApiException('batch embedding not expected here');
  }
}

class _FailingRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async =>
      throw LlmApiException('Cannot reach server');
}

Memo _memo(String uid, String content) => Memo(
    name: 'memos/$uid', content: content, createTime: DateTime(2026, 10, 1));

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTests(NativeDatabase.memory());
    await db.memoDao.upsertLocalMemo(testAccount.id, _memo('same', 'east'));
    await db.memoDao.upsertLocalMemo(testAccount.id, _memo('off', 'north'));
    await db.embeddingDao.upsertAll(testAccount.id, 'e-m', [
      EmbeddingWrite(
          uid: 'same',
          contentHash: 1,
          vector: Float32List.fromList([0.9, 0.1])),
      // [0.5, 0.5] keeps the second hit above RetrievalService.minScore
      // (0.30) so the ranking assertion still exercises both records.
      EmbeddingWrite(
          uid: 'off',
          contentHash: 1,
          vector: Float32List.fromList([0.5, 0.5])),
    ]);
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authProvider.overrideWith(_StubAuthNotifier.new),
      llmRepositoryProvider.overrideWith((ref) => _EmbeddingRepo()),
      vectorizationEngineProvider.overrideWithValue(null),
    ]);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('returns similarity-ranked memo records', () async {
    final results =
        await container.read(semanticSearchProvider('方向').future);
    expect(results.map((r) => r.memo.uid), ['same', 'off']);
  });

  test('empty query yields nothing and hits no endpoint', () async {
    expect(await container.read(semanticSearchProvider('  ').future),
        isEmpty);
  });

  test('endpoint failures degrade to an empty result', () async {
    container.dispose();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
      authProvider.overrideWith(_StubAuthNotifier.new),
      llmRepositoryProvider.overrideWith((ref) => _FailingRepo()),
      vectorizationEngineProvider.overrideWithValue(null),
    ]);
    expect(await container.read(semanticSearchProvider('方向').future),
        isEmpty);
  });
}
