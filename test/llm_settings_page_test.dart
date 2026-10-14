import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:memos_go/features/settings/llm_settings_page.dart';
import 'package:memos_go/l10n/generated/app_localizations.dart';
import 'package:memos_go/providers/llm_providers.dart';
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
      initialLocation: '/llm',
      routes: [
        GoRoute(
          path: '/llm',
          builder: (context, state) => const LlmSettingsPage(),
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('fills the form and saves to secure storage', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
        find.byType(TextFormField).at(0), 'https://api.deepseek.com/v1');
    await tester.enterText(find.byType(TextFormField).at(1), 'sk-secret');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'deepseek-chat');
    await tester.enterText(
        find.byType(TextFormField).at(3), 'text-embedding-3-small');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final stored = storage.values['memos_go.llmConfig'];
    expect(stored, isNotNull);
    expect(stored, contains('"chatModel":"deepseek-chat"'));
    expect(stored, contains('"apiKey":"sk-secret"'));
    expect(stored, contains('"embeddingModel":"text-embedding-3-small"'));
    expect(container.read(llmProvider).chatModel, 'deepseek-chat');
  });

  testWidgets('hydrates the form from previously saved settings',
      (tester) async {
    storage.values['memos_go.llmConfig'] =
        '{"baseUrl":"https://api.deepseek.com/v1","apiKey":"sk-secret",'
        '"chatModel":"deepseek-chat","embeddingModel":""}';
    await pumpPage(tester);

    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'https://api.deepseek.com/v1',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      'deepseek-chat',
    );
    // Clear button only shows once a config exists.
    expect(find.widgetWithText(TextButton, '清除配置'), findsOneWidget);
  });

  testWidgets('invalid endpoint URL blocks saving with an error',
      (tester) async {
    await pumpPage(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'not a url');
    await tester.enterText(find.byType(TextFormField).at(1), 'sk-secret');
    await tester.enterText(
        find.byType(TextFormField).at(2), 'deepseek-chat');
    await tester.pump();

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('接口地址无效，需以 http(s):// 开头'), findsOneWidget);
    expect(storage.values.containsKey('memos_go.llmConfig'), isFalse);
  });

  testWidgets('an entirely empty form saves and disables AI features',
      (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(container.read(llmProvider).isConfigured, isFalse);
  });
}
