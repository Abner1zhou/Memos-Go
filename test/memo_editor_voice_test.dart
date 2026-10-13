import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/features/memo_editor/memo_editor_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMemoRepository extends MemoRepository {
  _FakeMemoRepository()
      : super(ServerAccount(
          id: 'http://x|tester',
          baseUrl: 'http://x',
          token: 'tok',
          user: const User(name: 'users/1', username: 'tester'),
        ));

  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async =>
      const MemoListPage(memos: []);

  @override
  Future<Memo> getMemo(String uid) async =>
      const Memo(name: 'memos/x', content: '');

  @override
  Future<Memo> updateMemo(Memo memo) async => memo;

  @override
  Future<void> deleteMemo(String uid) async {}

  @override
  Future<UserStats> userStats() async => const UserStats(tagCounts: {});
}

void main() {
  testWidgets('mic button shows setup dialog when ASR is not configured',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const MemoEditorPage(),
      ),
    ));
    await tester.pump();

    expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_none_rounded));
    await tester.pump();

    expect(find.text('未配置语音识别'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });
}
