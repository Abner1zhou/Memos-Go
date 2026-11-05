import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/app.dart';
import 'package:memos_go/core/widgets/attachment_image.dart';
import 'package:memos_go/core/widgets/image_viewer.dart';
import 'package:memos_go/data/local/app_database.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/features/drawer/activity_heatmap.dart';
import 'package:memos_go/features/me/me_page.dart';
import 'package:memos_go/features/review/daily_review_page.dart';
import 'package:memos_go/features/shell/app_shell.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/offline_app.dart';

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    accounts: [testAccount],
    activeAccount: testAccount,
  );
}

List<Memo> _defaultMemos() => [
  testMemo(
    'today',
    'Morning note #work',
    created: DateTime.now(),
    tags: const ['work'],
  ),
  testMemo(
    'long',
    List.filled(120, 'lorem').join(' '),
    created: DateTime.now().subtract(const Duration(days: 1)),
  ),
  testMemo(
    'heat',
    'heatmap seed #work #life',
    created: DateTime.now().subtract(const Duration(days: 3)),
    tags: const ['work', 'life'],
  ),
  testMemo(
    'heat2',
    'another seed #life',
    created: DateTime.now().subtract(const Duration(days: 3)),
    tags: const ['life'],
  ),
  testMemo(
    'oldyear',
    'One year ago today #life',
    created: DateTime(
      DateTime.now().year - 1,
      DateTime.now().month,
      DateTime.now().day,
      9,
    ),
    tags: const ['life'],
  ),
];

List<Memo> _defaultDeleted() => [
  testMemo(
    'gone',
    'Deleted memo',
    state: MemoState.deleted,
    created: DateTime.now().subtract(const Duration(days: 2)),
  ),
];

/// Vertical [Scrollable] hosted by [page].
///
/// [WidgetTester.scrollUntilVisible] casts this finder to [Scrollable], so it
/// cannot be a [ListView]. `.first` ignores extra scrollers inside cards.
Finder _verticalScrollable(Type page) {
  return find
      .descendant(
        of: find.byType(page),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      )
      .first;
}

/// Drags [scrollable] until [target] can be tapped above the primary bar.
///
/// The shell keeps `extendBody` false, so the branch ends where the bar
/// starts. [WidgetTester.scrollUntilVisible] treats a widget as visible once
/// it is built, including the cache that sits under that bar.
Future<void> _scrollAboveNav(
  WidgetTester tester,
  Finder target,
  Finder scrollable,
) async {
  for (var i = 0; i < 24; i++) {
    if (_isAboveNav(tester, target)) return;
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pump();
  }
  fail('$target stayed under the navigation bar');
}

bool _isAboveNav(WidgetTester tester, Finder target) {
  if (target.hitTestable().evaluate().isEmpty) return false;
  final nav = find.byKey(primaryNavBarKey);
  if (nav.evaluate().isEmpty) return true;
  final rect = tester.getRect(target);
  return rect.top >= 0 && rect.bottom <= tester.getRect(nav).top - 1;
}

Future<void> _pumpApp(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_StubAuthNotifier.new),
        memoRepositoryProvider.overrideWith((ref) => offlineRepo(db)),
        ...offlineTestOverrides(db),
      ],
      child: const MemosGoApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('home feed renders cards and the primary nav', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await buildSeededDb(
      normal: _defaultMemos(),
      deleted: _defaultDeleted(),
    );
    await _pumpApp(tester, db);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.menu), findsNothing);
    expect(find.byKey(primaryNavBarKey), findsOneWidget);
    expect(find.text('Memos'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Compose'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Me'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Daily review'), findsNothing);
    // Feed cards with content; long memo is collapsed behind Expand.
    expect(find.text('Morning note #work'), findsOneWidget);
    expect(find.text('Expand'), findsOneWidget);
    expect(find.text('Collapse'), findsNothing);

    await tester.tap(find.text('Expand'));
    await tester.pump();
    expect(find.text('Collapse'), findsOneWidget);

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('Search memo content…'), findsWidgets);
  });

  testWidgets('tapping a card opens the editor instead of read-only detail', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await buildSeededDb(
      normal: _defaultMemos(),
      deleted: _defaultDeleted(),
    );
    await _pumpApp(tester, db);

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

  testWidgets('tag page FAB opens composer prefilled with the tag', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await buildSeededDb(
      normal: _defaultMemos(),
      deleted: _defaultDeleted(),
    );
    await _pumpApp(tester, db);

    // Me tab holds the tag directory that used to live in the drawer.
    await tester.tap(find.text('Me'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.ensureVisible(find.text('work'));
    await tester.pump();
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

  testWidgets('drawer shows stats, heatmap, menu and tag directory', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await buildSeededDb(
      normal: _defaultMemos(),
      deleted: _defaultDeleted(),
    );
    await _pumpApp(tester, db);

    await tester.tap(find.text('Me'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.byType(ActivityHeatmap), findsOneWidget);
    expect(find.text('tester'), findsOneWidget); // user header
    expect(find.text('All memos'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Tags'), findsOneWidget);
    expect(find.text('Days'), findsOneWidget);
    final meScroll = _verticalScrollable(MePage);
    await _scrollAboveNav(tester, find.text('Trash'), meScroll);
    expect(find.text('Trash'), findsOneWidget);
    // Tag directory rows sorted by count (life first).
    await _scrollAboveNav(tester, find.text('life'), meScroll);
    expect(find.text('life'), findsOneWidget);
    expect(find.text('work'), findsOneWidget);
    expect(find.text('Pinned tags'), findsNothing); // nothing pinned yet

    // Pin "life" via its overflow menu. The directory sits below the
    // account header and heatmap, so bring the row on screen first.
    await _scrollAboveNav(
      tester,
      find.text('life'),
      _verticalScrollable(MePage),
    );
    await tester.pump();
    await tester.tap(
      find
          .descendant(
            of: find.ancestor(
              of: find.text('life'),
              matching: find.byType(Row),
            ),
            matching: find.byIcon(Icons.more_horiz),
          )
          .last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin').last);
    await tester.pumpAndSettle();
    expect(find.text('Pinned tags'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tag tree folds hierarchical tags by / separator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await buildSeededDb(
      normal: [
        testMemo('a', 'one #level1', tags: const ['level1']),
        testMemo('b', 'two #level1', tags: const ['level1']),
        testMemo('c', 'three #level1/level2', tags: const ['level1/level2']),
        testMemo('d', 'four #level1/level2', tags: const ['level1/level2']),
        testMemo(
          'e',
          'five #level1/level2/deep',
          tags: const ['level1/level2/deep'],
        ),
        testMemo('f', 'six #other', tags: const ['other']),
      ],
    );
    await _pumpApp(tester, db);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('level1'));
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
      matching: find.byIcon(Icons.chevron_right_rounded),
    );
    await tester.tap(treeChevrons.first);
    await tester.pumpAndSettle();
    expect(find.text('level2'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('deep'), findsNothing);

    // Expand level2 -> deep appears. The library header sits above the
    // tree, so bring the chevron on-screen before tapping it.
    await tester.ensureVisible(treeChevrons.last);
    await tester.pumpAndSettle();
    await tester.tap(treeChevrons.last);
    await tester.pumpAndSettle();
    expect(find.text('deep'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('random walk samples up to 10 memos and re-rolls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final memos = List.generate(
      12,
      (i) => testMemo(
        'm$i',
        'Random note $i #walk',
        tags: const ['walk'],
        created: DateTime.now().subtract(Duration(days: i)),
      ),
    );
    final db = await buildSeededDb(normal: memos);
    await _pumpApp(tester, db);

    await tester.tap(find.text('Review'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Random walk'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Random note'), findsWidgets);
    final listView = tester.widget<ListView>(find.byType(ListView).first);
    final delegate = listView.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.estimatedChildCount, 10); // capped at 10 of 12

    await tester.tap(find.text('Walk again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(
      (tester.widget<ListView>(find.byType(ListView).first).childrenDelegate
              as SliverChildBuilderDelegate)
          .estimatedChildCount,
      10,
    );
  });

  testWidgets('daily review resurfaces past memos and on-this-day', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final db = await buildSeededDb(
      normal: _defaultMemos(),
      deleted: _defaultDeleted(),
    );
    await _pumpApp(tester, db);

    await tester.tap(find.text('Review'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Daily review'), findsOneWidget);
    expect(find.text('AI chat'), findsOneWidget);
    // On-this-day section still groups memos from previous years.
    expect(find.text('1 years ago today'), findsOneWidget);
    expect(find.text('One year ago today #life'), findsOneWidget);
    // Recall order is shuffled, so walk the list and keep every label that
    // was built. A single scrollUntilVisible would drop the other label once
    // it left the cache.
    final seen = <String>{};
    void collectLabels() {
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final data = text.data;
        if (data != null) seen.add(data);
      }
    }

    collectLabels();
    final reviewScroll = _verticalScrollable(DailyReviewPage);
    for (var i = 0; i < 12; i++) {
      await tester.drag(reviewScroll, const Offset(0, -280));
      await tester.pump();
      collectLabels();
    }
    expect(seen.any((label) => label.contains('ago you wrote')), isTrue);
    expect(seen.contains('Today you wrote'), isTrue);

    // Re-roll swaps the batch without errors.
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Daily review'), findsOneWidget);

    await tester.tap(find.text('AI chat'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Chat with memories'), findsOneWidget);
  });

  testWidgets('settings language row stays single-line at phone width', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = await buildSeededDb(
      normal: _defaultMemos(),
      deleted: _defaultDeleted(),
    );
    await _pumpApp(tester, db);

    await tester.tap(find.text('Me'));
    await tester.pumpAndSettle();
    final meScroll = _verticalScrollable(MePage);
    await _scrollAboveNav(tester, find.text('Language'), meScroll);

    expect(tester.takeException(), isNull);
    // The three language segments live in the subtitle, so the title is not
    // squeezed into a one-character-per-line vertical wrap.
    expect(tester.getSize(find.text('Language')).height, lessThan(30));

    // The segmented control sits under the title and must clear the bar.
    await _scrollAboveNav(tester, find.text('中文'), meScroll);
    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Language'), findsNothing);
    expect(tester.getSize(find.text('语言')).height, lessThan(30));
  });

  testWidgets('trash lists deleted memos with restore action', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = await buildSeededDb(
      normal: _defaultMemos(),
      deleted: _defaultDeleted(),
    );
    await _pumpApp(tester, db);

    await tester.tap(find.text('Me'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await _scrollAboveNav(
      tester,
      find.text('Trash'),
      _verticalScrollable(MePage),
    );
    await tester.tap(find.text('Trash'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Deleted memo'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete permanently'), findsOneWidget);

    // Restore fails offline instantly (unreachable server facade) and the
    // fallback writes straight to the local mirror; the trash stream then
    // drops the row.
    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Trash is empty'), findsOneWidget);
  });

  testWidgets('memo cards with image attachments lay out without exceptions', (
    tester,
  ) async {
    // Regression: a single full-width image inside the horizontal gallery
    // ListView used double.infinity width under unbounded constraints.
    const pic = Attachment(
      name: 'attachments/pic',
      filename: 'pic.png',
      type: 'image/png',
    );
    final db = await buildSeededDb(
      normal: [
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
      ],
    );
    await _pumpApp(tester, db);

    expect(tester.takeException(), isNull);
    expect(find.text('single image memo'), findsOneWidget);
    expect(find.text('multi image memo'), findsOneWidget);
  });

  testWidgets('tapping a memo image opens the fullscreen viewer', (
    tester,
  ) async {
    const pic = Attachment(
      name: 'attachments/pic',
      filename: 'pic.png',
      type: 'image/png',
    );
    final db = await buildSeededDb(
      normal: [
        Memo(
          name: 'memos/one-img',
          content: 'single image memo',
          attachments: const [pic],
          createTime: DateTime.now(),
        ),
      ],
    );
    await _pumpApp(tester, db);

    final image = find.byType(AttachmentImage).first;
    await tester.ensureVisible(image);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(image, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.byType(AttachmentViewerPage), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Fixed pumps instead of pumpAndSettle: the viewer's loading spinner
    // animates indefinitely. The pop exit animation needs over a second.
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(AttachmentViewerPage), findsNothing);
    expect(find.text('single image memo'), findsOneWidget);
  });
}
