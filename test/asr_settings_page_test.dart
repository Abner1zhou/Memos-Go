import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memos_go/data/api/asr_api.dart';
import 'package:memos_go/features/settings/asr_settings_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/asr_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secure_storage.dart';

void main() {
  late FakeSecureStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = FakeSecureStorage();
    FlutterSecureStoragePlatform.instance = storage;
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance =
        MethodChannelFlutterSecureStorage();
    container.dispose();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/asr',
      routes: [
        GoRoute(
          path: '/asr',
          builder: (context, state) => const AsrSettingsPage(),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    // Let initState's microtask read the (empty) storage and settle forms.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('fills the form and saves to secure storage', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
        find.byType(TextFormField).at(0), 'https://api.example.com/v1');
    await tester.enterText(find.byType(TextFormField).at(1), 'sk-secret');
    await tester.enterText(find.byType(TextFormField).at(2), 'whisper-1');
    await tester.enterText(find.byType(TextFormField).at(3), 'zh');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final stored = storage.values['memos_go.asrConfig'];
    expect(stored, isNotNull);
    expect(stored, contains('"model":"whisper-1"'));
    expect(stored, contains('"apiKey":"sk-secret"'));
    // The provider saw the change too.
    expect(container.read(asrProvider).model, 'whisper-1');
  });

  testWidgets('hydrates the form from previously saved settings',
      (tester) async {
    storage.values['memos_go.asrConfig'] =
        '{"baseUrl":"https://api.example.com/v1","apiKey":"sk-secret",'
        '"model":"whisper-1","language":"","keepAudio":true}';
    await pumpPage(tester);

    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller!
            .text,
        'https://api.example.com/v1');
    expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(2))
            .controller!
            .text,
        'whisper-1');
    // Clear button only shows once a config exists.
    expect(find.widgetWithText(TextButton, '清除配置'), findsOneWidget);
  });

  testWidgets('switching to DashScope compatible persists the dialect',
      (tester) async {
    await pumpPage(tester);

    // Segmented selector: switch protocol to DashScope compatible mode.
    await tester.tap(find.text('DashScope 兼容'));
    await tester.pump();

    await tester.enterText(find.byType(TextFormField).at(0),
        'https://dashscope.aliyuncs.com/compatible-mode/v1');
    await tester.enterText(find.byType(TextFormField).at(1), 'sk-dash');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'qwen3-asr-flash');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(storage.values['memos_go.asrConfig'],
        contains('"dialect":"dashscope"'));
    expect(container.read(asrProvider).dialect, AsrDialect.dashscope);
  });

  testWidgets('switching to DashScope native persists the dialect',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('DashScope 原生'));
    await tester.pump();

    // The console copies /api/v1; saving must collapse it to the host root.
    await tester.enterText(find.byType(TextFormField).at(0),
        'https://llm-xxx.cn-beijing.maas.aliyuncs.com/api/v1');
    await tester.enterText(find.byType(TextFormField).at(1), 'sk-dash');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'qwen3-asr-flash');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(storage.values['memos_go.asrConfig'],
        contains('"dialect":"dashscopeNative"'));
    expect(storage.values['memos_go.asrConfig'],
        isNot(contains('/api/v1')));
    expect(container.read(asrProvider).dialect, AsrDialect.dashscopeNative);
  });

  testWidgets('invalid endpoint URL blocks saving with an error',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'not a url');
    await tester.enterText(find.byType(TextFormField).at(1), 'sk-secret');
    await tester.enterText(find.byType(TextFormField).at(2), 'whisper-1');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('接口地址无效，需以 http(s):// 开头'), findsOneWidget);
    expect(storage.values.containsKey('memos_go.asrConfig'), isFalse);
  });
}
