import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/local/embedding_dao.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/llm_repository.dart';
import 'package:memos_go/features/search/search_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/llm_providers.dart';
import 'package:memos_go/providers/sync_providers.dart';
import 'package:memos_go/providers/vectorization_providers.dart';

import 'helpers/offline_app.dart';

const _settings = LlmSettings(
  baseUrl: 'https://llm.example.com/v1',
  apiKey: 'sk-x',
  chatModel: 'c',
  embeddingModel: 'e-m',
);

class _EmbeddingRepo extends LlmRepository {
  @override
  Future<LlmSettings> load() async => _settings;

  @override
  Future<List<List<double>>> embeddings(LlmSettings s,
      {required List<String> inputs}) async => const [[1.0, 0.0]];
}

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
        status: AuthStatus.signedIn,
        accounts: [testAccount],
        activeAccount: testAccount,
      );
}

Memo _memo(String uid, String content) => Memo(
    name: 'memos/$uid', content: content, createTime: DateTime(2026, 10, 1));

void main() {
  testWidgets('semantic section surfaces related memos above keyword hits',
      (tester) async {
    final db = AppDatabase.forTests(NativeDatabase.memory());
    // 'k8s' matches the keyword query; '翻车' does not but is the closest
    // semantic neighbour of the embedded query direction.
    await db.memoDao.upsertLocalMemo(
        testAccount.id, _memo('hit', 'k8s 滚动更新'));
    await db.memoDao.upsertLocalMemo(
        testAccount.id, _memo('related', '那次发布翻车的复盘'));
    await db.embeddingDao.upsertAll(testAccount.id, 'e-m', [
      EmbeddingWrite(
          uid: 'hit',
          contentHash: 1,
          vector: Float32List.fromList([0.2, 0.8])),
      EmbeddingWrite(
          uid: 'related',
          contentHash: 1,
          vector: Float32List.fromList([0.95, 0.1])),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => offlineRepo(db)),
        appDatabaseProvider.overrideWithValue(db),
        syncEngineProvider.overrideWithValue(null),
        vectorizationEngineProvider.overrideWithValue(null),
        llmRepositoryProvider.overrideWith((ref) => _EmbeddingRepo()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SearchPage(),
      ),
    ));
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'k8s');
    await tester.pump();
    // Cross the 400ms semantic debounce before asserting.
    await tester.pump(const Duration(milliseconds: 500));
    // topKSimilar scores on a background isolate (Isolate.run): the result
    // only arrives as a real event-loop message, which fake async never
    // services. Yield to the real loop so the isolate result lands, then
    // flush the fake-async microtask chain so the provider completes and
    // the section draws.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('语义相关'), findsOneWidget);
    // Semantic-only hit renders although the keyword query misses it.
    expect(find.textContaining('翻车的复盘'), findsOneWidget);
    // The keyword feed already shows the k8s memo; the rail must not
    // duplicate it.
    expect(find.textContaining('k8s 滚动更新'), findsOneWidget);
  });
}
