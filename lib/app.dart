import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/generated/app_localizations.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/chat/chat_page.dart';
import 'features/login/login_page.dart';
import 'features/me/me_page.dart';
import 'features/memo_detail/memo_detail_page.dart';
import 'features/memo_editor/memo_editor_page.dart';
import 'features/memos/memos_page.dart';
import 'features/memos/tag_memos_page.dart';
import 'features/review/daily_review_page.dart';
import 'features/review/random_walk_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/asr_settings_page.dart';
import 'features/settings/llm_settings_page.dart';
import 'features/shell/app_shell.dart';
import 'features/trash/trash_page.dart';
import 'providers/auth_providers.dart';
import 'providers/settings_providers.dart';
import 'providers/suggestion_providers.dart';
import 'providers/sync_providers.dart';
import 'providers/vectorization_providers.dart';

/// Root navigator for the app router; public so tests can build a GoRouter
/// over [buildAppRoutes], whose sub-routes target this key.
@visibleForTesting
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthStatus>(AuthStatus.loading);

  ref.onDispose(auth.dispose);
  ref.listen(
    authProvider.select((s) => s.status),
    (_, next) => auth.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    refreshListenable: auth,
    initialLocation: '/memos',
    redirect: (context, state) {
      final signedIn = auth.value == AuthStatus.signedIn;
      final loggingIn = state.matchedLocation == '/login';
      if (!signedIn) return loggingIn ? null : '/login';
      return loggingIn ? '/memos' : null;
    },
    routes: buildAppRoutes(),
  );
});

/// Exposed for tests so they match against the real route table
/// (e.g. percent-encoded tag path parameters).
///
/// Primary destinations live in a [StatefulShellRoute] so the bottom nav
/// stays mounted. Editor, detail, tag, ASR/LLM settings, trash, random walk
/// and chat cover that shell on the root navigator. `/settings` is the Me
/// branch so older links still land on account and settings.
@visibleForTesting
List<RouteBase> buildAppRoutes() => [
  GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) =>
        AppShell(navigationShell: navigationShell),
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/memos',
            builder: (context, state) => const MemosPage(),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => MemoEditorPage(
                  initialTag: state.uri.queryParameters['tag'],
                ),
              ),
              GoRoute(
                path: 'detail/:uid',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) =>
                    MemoDetailPage(uid: state.pathParameters['uid']!),
              ),
              GoRoute(
                path: 'edit/:uid',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) =>
                    MemoEditorPage(editingUid: state.pathParameters['uid']!),
              ),
              GoRoute(
                path: 'tag/:tag',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) =>
                    TagMemosPage(tag: state.pathParameters['tag']!),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchPage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/review',
            builder: (context, state) => const DailyReviewPage(),
          ),
        ],
      ),
      StatefulShellBranch(
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const MePage(),
            routes: [
              GoRoute(
                path: 'asr',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const AsrSettingsPage(),
              ),
              GoRoute(
                path: 'llm',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const LlmSettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  GoRoute(
    path: '/trash',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const TrashPage(),
  ),
  GoRoute(
    path: '/random',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const RandomWalkPage(),
  ),
  GoRoute(
    path: '/chat',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ChatPage(),
  ),
];

class MemosGoApp extends ConsumerWidget {
  const MemosGoApp({super.key, this.fontFamily});

  /// Overrides the theme font. Widget tests pass this when the tester is
  /// running with the Ahem test font and a real face has been loaded.
  final String? fontFamily;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(_routerProvider);
    // Keeps the sync engine alive for the whole session while signed in.
    ref.watch(syncEngineProvider);
    // Keeps the vectorization engine alive alongside sync.
    ref.watch(vectorizationEngineProvider);
    // Keeps the save-time suggestion engine alive alongside both.
    ref.watch(suggestionEngineProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: _withFont(AppTheme.light()),
      darkTheme: _withFont(AppTheme.dark()),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }

  ThemeData _withFont(ThemeData base) {
    final family = fontFamily;
    if (family == null) return base;
    final title = base.appBarTheme.titleTextStyle;
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: family),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: family),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: (title ?? const TextStyle()).copyWith(
          fontFamily: family,
        ),
      ),
    );
  }
}
