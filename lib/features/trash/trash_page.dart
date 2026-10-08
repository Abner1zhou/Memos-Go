import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/memo_markdown.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../data/models/models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';

/// Deleted memos with restore / permanent-delete actions.
class TrashPage extends ConsumerWidget {
  const TrashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final query = MemosQuery(state: MemoState.deleted.wireName);
    final list = ref.watch(memosListProvider(query));
    final notifier = ref.read(memosListProvider(query).notifier);

    Widget body;
    if (list.status == MemosListStatus.loading && list.memos.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (list.memos.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline,
                size: 52, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              list.error ?? l10n.emptyTrash,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () async {
          await notifier.refresh();
          ref.invalidate(memoInsightsProvider);
        },
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: list.memos.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) =>
              _TrashCard(memo: list.memos[index], onRestored: () {
            notifier.removeLocal(list.memos[index].name);
            ref.invalidate(memoInsightsProvider);
          }),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trash)),
      body: body,
    );
  }
}

class _TrashCard extends ConsumerWidget {
  const _TrashCard({required this.memo, required this.onRestored});

  final Memo memo;
  final VoidCallback onRestored;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDateTime(memo.createTime,
                  locale: Localizations.localeOf(context).languageCode),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (memo.content.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: MemoMarkdown(content: memo.content),
              ),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _restore(context, ref),
                  child: Text(l10n.restore),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error),
                  onPressed: () => _deletePermanently(context, ref),
                  child: Text(l10n.deletePermanently),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(memoRepositoryProvider)!
          .updateMemo(memo.copyWith(state: MemoState.normal));
      onRestored();
      if (context.mounted) _snack(context, l10n.restored);
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  Future<void> _deletePermanently(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.deletePermanentlyConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(memoRepositoryProvider)!.deleteMemo(memo.uid);
      onRestored();
      if (context.mounted) _snack(context, l10n.deleted);
    } catch (e) {
      if (context.mounted) _snack(context, e.toString());
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
