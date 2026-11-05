import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/app.dart';
import 'package:memos_go/data/models/models.dart';
import 'package:memos_go/data/repositories/auth_repository.dart';
import 'package:memos_go/data/repositories/cached_memo_repository.dart';
import 'package:memos_go/providers/auth_providers.dart';
import 'package:memos_go/providers/settings_providers.dart';
import 'package:memos_go/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';
import 'helpers/offline_app.dart';

/// Phone-sized captures of the bottom nav. Skipped unless
/// `UPDATE_NAV_SCREENSHOTS=1`, so `flutter test` does not rewrite the PNGs.
///
/// ```bash
/// UPDATE_NAV_SCREENSHOTS=1 flutter test test/nav_screenshots_test.dart
/// ```
void main() {
  final enabled = Platform.environment['UPDATE_NAV_SCREENSHOTS'] == '1';

  testWidgets('capture bottom-nav screenshots', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStoragePlatform.instance = FakeSecureStorage();
    addTearDown(
      () => FlutterSecureStoragePlatform.instance =
          MethodChannelFlutterSecureStorage(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (call) async => const {
            'appName': 'MemosGo',
            'packageName': 'com.abner.memosgo',
            'version': '1.7.0',
            'buildNumber': '9',
            'installerStore': null,
          },
        );
    await tester.runAsync(_loadRoboto);
    _usePhoneSurface(tester);

    final now = DateTime.now();
    final account = ServerAccount(
      id: 'http://x|abner',
      baseUrl: 'https://memos.example.com',
      token: 'tok',
      user: const User(
        name: 'users/1',
        username: 'abner',
        displayName: 'Anning',
      ),
    );
    final memos = _seedMemos(now);
    final db = await buildSeededDb(normal: memos, accountId: account.id);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _ShotAuth(account)),
          settingsProvider.overrideWith(_ShotSettings.new),
          memoRepositoryProvider.overrideWith(
            (ref) => CachedMemoRepository(
              account: account,
              db: db,
              server: UnreachableServer(),
            ),
          ),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
          ...offlineTestOverrides(db),
        ],
        child: const MemosGoApp(fontFamily: 'Roboto'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await _shot(tester, '01-memos.png');

    await tester.tap(find.text('Search'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField).first, 'lake');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('West Lake'), findsWidgets);
    await _shot(tester, '02-search.png');

    await tester.tap(find.text('Review'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Daily review'), findsOneWidget);
    expect(find.text('AI chat'), findsOneWidget);
    await _shot(tester, '03-review.png');

    await tester.tap(find.text('Me'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Anning'), findsOneWidget);
    expect(find.text('All tags'), findsWidgets);
    await _shot(tester, '04-me.png');

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('New memo'), findsOneWidget);
    await _shot(tester, '05-write.png');

    expect(tester.takeException(), isNull);
  }, skip: !enabled);
}

class _ShotAuth extends AuthNotifier {
  _ShotAuth(this.account);

  final ServerAccount account;

  @override
  AuthState build() => AuthState(
    status: AuthStatus.signedIn,
    accounts: [account],
    activeAccount: account,
  );
}

class _ShotSettings extends SettingsNotifier {
  @override
  Settings build() =>
      const Settings(themeMode: ThemeMode.light, localeCode: 'en');
}

List<Memo> _seedMemos(DateTime now) {
  final memos = <Memo>[
    testMemo(
      'west-lake',
      'Walked the West Lake causeway. The wind was light. #life/weekend',
      created: now.subtract(const Duration(hours: 2)),
      pinned: true,
      tags: const ['life/weekend'],
    ),
    testMemo(
      'nav',
      'Collapsed primary navigation into five tabs: Memos, Search, Compose, Review, Me. #product',
      created: now.subtract(const Duration(days: 1, hours: 3)),
      tags: const ['product'],
    ),
    testMemo(
      'book',
      'Finished Siddhartha. I want to copy the river chapter again. #reading',
      created: now.subtract(const Duration(days: 3, hours: 5)),
      tags: const ['reading'],
    ),
    testMemo(
      'tea',
      'Boiled a pot of white tea at sunrise. Light on the windowsill. #life',
      created: now.subtract(const Duration(days: 8)),
      tags: const ['life'],
    ),
    testMemo(
      'tags',
      'Tag tree: parents start folded, and the count includes the subtree. #product/design',
      created: now.subtract(const Duration(days: 16)),
      tags: const ['product/design'],
    ),
    testMemo(
      'last-year',
      'A year ago today I was writing by the lake too. #life',
      created: DateTime(now.year - 1, now.month, now.day, 9, 30),
      tags: const ['life'],
    ),
  ];
  for (var i = 0; i < 16; i++) {
    memos.add(
      testMemo(
        'heat-$i',
        'Scratch note $i',
        created: now.subtract(Duration(days: 21 + i * 5, hours: i)),
        tags: i.isEven ? const ['life'] : const ['reading'],
      ),
    );
  }
  return memos;
}

/// Logical 390×844, like a modern phone, with status-bar and home-indicator
/// insets so the shell's SafeArea matches a device screenshot.
void _usePhoneSurface(WidgetTester tester) {
  const dpr = 2.0;
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = const Size(390 * dpr, 844 * dpr);
  const padding = FakeViewPadding(top: 47 * dpr, bottom: 34 * dpr);
  tester.view.viewPadding = padding;
  tester.view.padding = padding;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetPadding);
}

Future<void> _loadRoboto() async {
  const dir = '/home/ubuntu/flutter/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final name in [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]) {
    final bytes = await File('$dir/$name').readAsBytes();
    loader.addFont(
      Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
    );
  }
  await loader.load();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MemosGoApp),
    matchesGoldenFile('../docs/screenshots/nav/$name'),
  );
}
