import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/memo_providers.dart';

class TagsPage extends ConsumerWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final counts = ref.watch(tagCountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tagsTab)),
      body: counts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('${l10n.loadFailed}: $e')),
        data: (map) {
          final entries = map.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sell_outlined,
                      size: 52, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(l10n.noTags,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  leading: Icon(Icons.tag_rounded,
                      color: theme.colorScheme.primary),
                  title: Text('#${entry.key}'),
                  trailing: Text(
                    l10n.memosCount(entry.value),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  onTap: () => context.push('/memos/tag/${Uri.encodeComponent(entry.key)}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
