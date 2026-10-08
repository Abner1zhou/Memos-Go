import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/attachment_image.dart';
import '../../core/widgets/memo_markdown.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/models.dart';
import '../../data/repositories/memo_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';

class MemosPage extends ConsumerWidget {
  const MemosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authProvider);
    final query = MemosQuery();
    final list = ref.watch(memosListProvider(query));
    final repo = ref.watch(memoRepositoryProvider);
    final user = auth.activeAccount?.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.memoTab),
            if (user != null)
              Text(
                user.shownName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l10n.servers,
            icon: const Icon(Icons.dns_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/memos/new'),
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.newMemo),
      ),
      body: MemosFeedBody(query: query, list: list, repo: repo),
    );
  }
}

/// Reusable paginated memo feed used by the home tab and tag views.
class MemosFeedBody extends ConsumerWidget {
  const MemosFeedBody({super.key, required this.query, required this.list, this.repo});

  final MemosQuery query;
  final MemosListState list;
  final MemoRepository? repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(memosListProvider(query).notifier);

    if (list.status == MemosListStatus.loading && list.memos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (list.status == MemosListStatus.error && list.memos.isEmpty) {
      return _MessageView(
        icon: Icons.cloud_off_outlined,
        title: l10n.loadFailed,
        detail: list.error,
        action: FilledButton.tonal(
          onPressed: notifier.refresh,
          child: Text(l10n.retry),
        ),
      );
    }
    if (list.memos.isEmpty) {
      return _MessageView(
        icon: Icons.edit_note_outlined,
        title: l10n.emptyMemoTitle,
        detail: l10n.emptyMemoSubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
        itemCount: list.memos.length + (list.hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index >= list.memos.length) {
            Future.microtask(notifier.loadMore);
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final memo = list.memos[index];
          return MemoCard(memo: memo, repo: repo!);
        },
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView(
      {required this.icon, required this.title, this.detail, this.action});

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class MemoCard extends ConsumerWidget {
  const MemoCard({super.key, required this.memo, required this.repo});

  final Memo memo;
  final MemoRepository repo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final query = MemosQuery();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/memos/detail/${memo.uid}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (memo.pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin_rounded,
                          size: 15, color: theme.colorScheme.primary),
                    ),
                  Expanded(
                    child: Text(
                      relativeTime(memo.createTime,
                          locale: Localizations.localeOf(context)
                              .languageCode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  VisibilityBadge(visibility: memo.visibility),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 160),
                    onSelected: (action) =>
                        _onAction(context, ref, action, query),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: Row(
                          children: [
                            Icon(memo.pinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded),
                            const SizedBox(width: 12),
                            Text(memo.pinned ? l10n.unpin : l10n.pin),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined),
                            const SizedBox(width: 12),
                            Text(l10n.edit),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: theme.colorScheme.error),
                            const SizedBox(width: 12),
                            Text(l10n.delete,
                                style:
                                    TextStyle(color: theme.colorScheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (memo.content.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                MemoMarkdown(
                  content: memo.content,
                  onTagTap: (tag) => context.push('/memos/tag/$tag'),
                ),
              ],
              if (memo.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                MemoAttachmentsGallery(memo: memo, repo: repo),
              ],
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, String action,
      MemosQuery query) async {
    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(memosListProvider(query).notifier);
    switch (action) {
      case 'pin':
        try {
          final updated = await ref
              .read(memoRepositoryProvider)!
              .updateMemo(memo.copyWith(pinned: !memo.pinned));
          notifier.upsertLocal(updated);
        } catch (e) {
          if (context.mounted) _snack(context, e.toString());
        }
      case 'edit':
        if (context.mounted) context.push('/memos/edit/${memo.uid}');
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(l10n.deleteMemoConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.confirm),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await ref.read(memoRepositoryProvider)!.deleteMemo(memo.uid);
            notifier.removeLocal(memo.name);
            ref.invalidate(tagCountsProvider);
            if (context.mounted) _snack(context, l10n.deleted);
          } catch (e) {
            if (context.mounted) _snack(context, e.toString());
          }
        }
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
