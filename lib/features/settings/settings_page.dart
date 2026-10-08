import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../providers/auth_providers.dart';
import '../../providers/settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final account = auth.activeAccount;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (account != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(l10n.account,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  account.user.shownName.isNotEmpty
                      ? account.user.shownName.substring(0, 1).toUpperCase()
                      : '?',
                  style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
                ),
              ),
              title: Text(account.user.shownName),
              subtitle: Text(
                '@${account.user.username}\n${account.baseUrl}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              isThreeLine: true,
            ),
            const Divider(),
          ],
          if (auth.accounts.length > 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(l10n.servers,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: theme.colorScheme.primary)),
            ),
            for (final other in auth.accounts)
              if (other.id != account?.id)
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: Text('${other.user.shownName} @ ${_hostOf(other.baseUrl)}'),
                  subtitle: Text(l10n.currentServer == other.id
                      ? l10n.currentServer
                      : other.baseUrl),
                  trailing: TextButton(
                    onPressed: () =>
                        ref.read(authProvider.notifier).switchAccount(other.id),
                    child: Text(l10n.switchServer),
                  ),
                ),
            const Divider(),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(l10n.appearance,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.themeMode),
            trailing: SegmentedButton<ThemeMode>(
              selected: {settings.themeMode},
              onSelectionChanged: (s) =>
                  ref.read(settingsProvider.notifier).setThemeMode(s.first),
              segments: [
                ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.settings_brightness_outlined, size: 18)),
                ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode_outlined, size: 18)),
                ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_outlined, size: 18)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            trailing: SegmentedButton<String>(
              selected: {settings.localeCode},
              onSelectionChanged: (s) => ref
                  .read(settingsProvider.notifier)
                  .setLocaleCode(s.first),
              segments: [
                ButtonSegment(value: '', label: Text(l10n.langSystem)),
                const ButtonSegment(value: 'zh', label: Text('中文')),
                const ButtonSegment(value: 'en', label: Text('English')),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_link),
            title: Text(l10n.addServer),
            subtitle: Text(l10n.loginSubtitle),
            onTap: () => context.push('/login'),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            title: Text(l10n.logout,
                style: TextStyle(color: theme.colorScheme.error)),
            onTap: () => _confirmSignOut(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.about),
            subtitle: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) => Text(
                '${l10n.version} ${snap.data?.version ?? '-'}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hostOf(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    return uri?.host ?? baseUrl;
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.removeServerConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.confirm)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).signOut();
      if (context.mounted) context.go('/login');
    }
  }
}
