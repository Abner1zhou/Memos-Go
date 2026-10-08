import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/login/login_page.dart';
import 'features/memo_detail/memo_detail_page.dart';
import 'features/memo_editor/memo_editor_page.dart';
import 'features/memos/memos_page.dart';
import 'features/memos/tag_memos_page.dart';
import 'features/review/on_this_day_page.dart';
import 'features/review/random_walk_page.dart';
import 'features/search/search_page.dart';
import 'features/settings/settings_page.dart';
import 'features/trash/trash_page.dart';
import 'providers/auth_providers.dart';
import 'providers/settings_providers.dart';

final _rootNavigator =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final _routerProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthStatus>(AuthStatus.loading);

  ref.onDispose(auth.dispose);
  ref.listen(authProvider.select((s) => s.status), (_, next) => auth.value = next,
      fireImmediately: true);

  return GoRouter(
    navigatorKey: _rootNavigator,
    refreshListenable: auth,
    initialLocation: '/memos',
    redirect: (context, state) {
      final signedIn = auth.value == AuthStatus.signedIn;
      final loggingIn = state.matchedLocation == '/login';
      if (!signedIn) return loggingIn ? null : '/login';
      return loggingIn ? '/memos' : null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/memos',
        builder: (context, state) => const MemosPage(),
        routes: [
          GoRoute(
            path: 'new',
            parentNavigatorKey: _rootNavigator,
            builder: (context, state) => const MemoEditorPage(),
          ),
          GoRoute(
            path: 'detail/:uid',
            parentNavigatorKey: _rootNavigator,
            builder: (context, state) =>
                MemoDetailPage(uid: state.pathParameters['uid']!),
          ),
          GoRoute(
            path: 'edit/:uid',
            parentNavigatorKey: _rootNavigator,
            builder: (context, state) =>
                MemoEditorPage(editingUid: state.pathParameters['uid']!),
          ),
          GoRoute(
            path: 'tag/:tag',
            builder: (context, state) =>
                TagMemosPage(tag: state.pathParameters['tag']!),
          ),
        ],
      ),
      GoRoute(
        path: '/search',
        parentNavigatorKey: _rootNavigator,
        builder: (context, state) => const SearchPage(),
      ),
      GoRoute(
        path: '/settings',
        parentNavigatorKey: _rootNavigator,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: '/trash',
        parentNavigatorKey: _rootNavigator,
        builder: (context, state) => const TrashPage(),
      ),
      GoRoute(
        path: '/review',
        parentNavigatorKey: _rootNavigator,
        builder: (context, state) => const OnThisDayPage(),
      ),
      GoRoute(
        path: '/random',
        parentNavigatorKey: _rootNavigator,
        builder: (context, state) => const RandomWalkPage(),
      ),
    ],
  );
});

class MemosGoApp extends ConsumerWidget {
  const MemosGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(_routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
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
}
