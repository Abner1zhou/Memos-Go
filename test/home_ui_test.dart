import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/app.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/memo_repository.dart';
import 'package:memos_go/features/drawer/activity_heatmap.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    final account = ServerAccount(
      id: 'http://x|tester',
      baseUrl: 'http://x',
      token: 'tok',
      user: const User(name: 'users/1', username: 'tester'),
    );
    return AuthState(
      status: AuthStatus.signedIn,
      accounts: [account],
      activeAccount: account,
    );
  }
}

class _FakeMemoRepository extends MemoRepository {
  _FakeMemoRepository({List<Memo>? memos, List<Memo>? deleted})
      : _normal = memos ?? _defaultMemos,
        _deleted = deleted ?? _defaultDeleted,
        super(ServerAccount(
          id: 'http://x|tester',
          baseUrl: 'http://x',
          token: 'tok',
          user: const User(name: 'users/1', username: 'tester'),
        ));

  static Memo _memo(
    String uid,
    String content, {
    DateTime? created,
    List<String> tags = const [],
    MemoState state = MemoState.normal,
  }) =>
      Memo(
        name: 'memos/$uid',
        state: state,
        content: content,
        tags: tags,
        pinned: false,
        createTime: created ?? DateTime.now(),
      );

  static final List<Memo> _defaultMemos = [
    _memo('today', 'Morning note #work',
        created: DateTime.now(),
        tags: const ['work']),
    _memo(
      'long',
      List.filled(120, 'lorem').join(' '),
      created: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _memo('heat', 'heatmap seed #work #life',
        created: DateTime.now().subtract(const Duration(days: 3)),
        tags: const ['work', 'life']),
    _memo('heat2', 'another seed #life',
        created: DateTime.now().subtract(const Duration(days: 3)),
        tags: const ['life']),
    _memo(
      'oldyear',
      'One year ago today #life',
      created: DateTime(DateTime.now().year - 1, DateTime.now().month,
          DateTime.now().day, 9),
      tags: const ['life'],
    ),
  ];

  static final List<Memo> _defaultDeleted = [
    _memo('gone', 'Deleted memo',
        state: MemoState.deleted,
        created: DateTime.now().subtract(const Duration(days: 2))),
  ];

  final List<Memo> _normal;
  final List<Memo> _deleted;

  @override
  Future<MemoListPage> listMemos({
    int pageSize = 50,
    String pageToken = '',
    String? filter,
  }) async {
    await Future<void>.delayed(Duration.zero);
    final deleted = (filter ?? '').contains('DELETED');
    return MemoListPage(memos: deleted ? _deleted : _normal);
  }

  @override
  Future<Memo> updateMemo(Memo memo) async => memo;

  @override
  Future<Memo> getMemo(String uid) async =>
      _normal.firstWhere((m) => m.uid == uid);

  @override
  Future<void> deleteMemo(String uid) async {}

  @override
  Future<UserStats> userStats() async =>
      const UserStats(tagCounts: {'work': 2, 'life': 3});
}

void main() {
  testWidgets('home feed renders cards, pills and composer button',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    // App bar: menu + search; feature pills; green composer.
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.text('Daily review'), findsOneWidget);
    expect(find.text('Random walk'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    // Feed cards with content; long memo is collapsed behind Expand.
    expect(find.text('Morning note #work'), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);
    expect(find.text('Collapse'), findsNothing);

    await tester.tap(find.text('Expand'));
    await tester.pump();
    expect(find.text('Collapse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a card opens the editor instead of read-only detail',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tap the card body (not the #work link): the editor opens in edit mode.
    await tester.tap(find.textContaining('Morning note').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Edit memo'), findsOneWidget);
    expect(find.text('New memo'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'Morning note #work');
  });

  testWidgets('tag page FAB opens composer prefilled with the tag',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Drawer -> tag directory -> work.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('work'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Tag page shows its own composer FAB on top of the home one.
    expect(find.text('#work'), findsWidgets);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('New memo'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '#work ');
  });

  testWidgets('drawer shows stats, heatmap, menu and tag directory',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(ActivityHeatmap), findsOneWidget);
    expect(find.text('tester'), findsOneWidget); // user header
    expect(find.text('All memos'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    // Tag directory rows sorted by count (life first).
    expect(find.text('life'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
    expect(find.text('Pinned tags'), findsNothing); // nothing pinned yet

    // Pin "life" via its overflow menu.
    await tester.tap(find
        .descendant(
          of: find.ancestor(of: find.text('life'), matching: find.byType(Row)),
          matching: find.byIcon(Icons.more_horiz),
        )
        .last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin').last);
    await tester.pumpAndSettle();
    expect(find.text('Pinned tags'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag tree folds hierarchical tags by / separator', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository(
              memos: [
                _FakeMemoRepository._memo('a', 'one #level1',
                    tags: const ['level1']),
                _FakeMemoRepository._memo('b', 'two #level1',
                    tags: const ['level1']),
                _FakeMemoRepository._memo('c', 'three #level1/level2',
                    tags: const ['level1/level2']),
                _FakeMemoRepository._memo('d', 'four #level1/level2',
                    tags: const ['level1/level2']),
                _FakeMemoRepository._memo('e', 'five #level1/level2/deep',
                    tags: const ['level1/level2/deep']),
                _FakeMemoRepository._memo('f', 'six #other',
                    tags: const ['other']),
              ],
            )),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // Folded by default: only root nodes are visible; parents show the
    // aggregated subtree count (2 + 2 + 1).
    expect(find.text('level1'), findsOneWidget);
    expect(find.text('5'), findsWidgets); // aggregated count on level1 row
    expect(find.text('level2'), findsNothing);
    expect(find.text('other'), findsOneWidget);

    // Expand level1 -> level2 appears with its subtree count (2 + 1); deep
    // stays folded.
    final treeChevrons = find.descendant(
        of: find.byType(AnimatedRotation),
        matching: find.byIcon(Icons.chevron_right_rounded));
    await tester.tap(treeChevrons.first);
    await tester.pumpAndSettle();
    expect(find.text('level2'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('deep'), findsNothing);

    // Expand level2 -> deep appears.
    await tester.tap(treeChevrons.last);
    await tester.pumpAndSettle();
    expect(find.text('deep'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('random walk samples up to 10 memos and re-rolls',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final memos = List.generate(
      12,
      (i) => _FakeMemoRepository._memo('m$i', 'Random note $i #walk',
          tags: const ['walk'],
          created: DateTime.now().subtract(Duration(days: i))),
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider
            .overrideWith((ref) => _FakeMemoRepository(memos: memos)),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Random walk'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Random note'), findsWidgets);
    final listView = tester.widget<ListView>(find.byType(ListView).first);
    final delegate =
        listView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, 10); // capped at 10 of 12

    await tester.tap(find.text('Walk again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(
        (tester.widget<ListView>(find.byType(ListView).first).childrenDelegate
                as SliverChildBuilderDelegate)
            .estimatedChildCount,
        10);
  });

  testWidgets('daily review resurfaces past memos and on-this-day',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Daily review'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    // On-this-day section still groups memos from previous years.
    expect(find.text('1 years ago today'), findsOneWidget);
    expect(find.text('One year ago today #life'), findsOneWidget);
    // The rest of the pool is resurfaced with "ago you wrote" labels.
    await tester.scrollUntilVisible(
      find.text('Today you wrote'),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('ago you wrote'), findsWidgets);

    // Re-roll swaps the batch without errors.
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Daily review'), findsOneWidget);
  });

  testWidgets('settings language row stays single-line at phone width',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The three language segments live in the subtitle, so the title is not
    // squeezed into a one-character-per-line vertical wrap.
    expect(tester.getSize(find.text('Language')).height, lessThan(30));

    // Switching to Chinese applies immediately and stays single-line.
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Language'), findsNothing);
    expect(tester.getSize(find.text('语言')).height, lessThan(30));
  });

  testWidgets('trash lists deleted memos with restore action', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository()),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Open the drawer and enter the trash.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Trash'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Deleted memo'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('memo cards with image attachments lay out without exceptions',
      (tester) async {
    // Regression: a single full-width image inside the horizontal gallery
    // ListView used double.infinity width under unbounded constraints.
    const pic = Attachment(name: 'attachments/pic', filename: 'pic.png', type: 'image/png');
    final memos = [
      Memo(
        name: 'memos/one-img',
        content: 'single image memo',
        attachments: const [pic],
        createTime: DateTime.now(),
      ),
      Memo(
        name: 'memos/two-img',
        content: 'multi image memo',
        attachments: const [pic, pic],
        createTime: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => _FakeMemoRepository(memos: memos)),
      ],
      child: const MemosGoApp(),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('single image memo'), findsOneWidget);
    expect(find.text('multi image memo'), findsOneWidget);
  });
}
