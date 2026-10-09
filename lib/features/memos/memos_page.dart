import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/attachment_image.dart';
import '../../core/widgets/image_viewer.dart';
import '../../core/widgets/memo_markdown.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/navigation.dart';
import '../../data/models/models.dart';
import '../../data/repositories/memo_repository.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import '../drawer/app_drawer.dart';

class MemosPage extends ConsumerWidget {
  const MemosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final query = MemosQuery();
    final list = ref.watch(memosListProvider(query));
    final repo = ref.watch(memoRepositoryProvider);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            tooltip: l10n.allMemos,
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            tooltip: l10n.searchTitle,
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/memos/new'),
        child: const Icon(Icons.add, size: 30),
      ),
      body: Column(
        children: [
          const _FeaturePills(),
          Expanded(
            child: MemosFeedBody(query: query, list: list, repo: repo),
          ),
        ],
      ),
    );
  }
}

/// Flomo-style entry pills below the app bar.
class _FeaturePills extends StatelessWidget {
  const _FeaturePills();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        children: [
          _Pill(
            icon: Icons.calendar_today_outlined,
            label: l10n.dailyReview,
            onTap: () => context.push('/review'),
          ),
          const SizedBox(width: 8),
          _Pill(
            icon: Icons.shuffle_rounded,
            label: l10n.randomWalk,
            onTap: () => context.push('/random'),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
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
      onRefresh: () async {
        await notifier.refresh();
        ref.invalidate(memoInsightsProvider);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
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
          return MemoCard(memo: memo, repo: repo ?? ref.read(memoRepositoryProvider)!);
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/memos/edit/${memo.uid}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (memo.pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.push_pin_rounded,
                          size: 14, color: theme.colorScheme.primary),
                    ),
                  Expanded(
                    child: Text(
                      formatStamp(memo.createTime),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (memo.visibility != MemoVisibility.private)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: VisibilityBadge(
                          visibility: memo.visibility, compact: true),
                    ),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 160),
                    icon: Icon(Icons.more_horiz,
                        size: 22, color: theme.colorScheme.onSurfaceVariant),
                    onSelected: (action) => _onAction(context, ref, action),
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
                        value: 'detail',
                        child: Row(
                          children: [
                            const Icon(Icons.article_outlined),
                            const SizedBox(width: 12),
                            Text(l10n.memoDetail),
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
                _ExpandableContent(
                  content: memo.content,
                  onTagTap: (tag) => pushTagMemos(context, tag),
                ),
              ],
              if (memo.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                MemoAttachmentsGallery(
                  memo: memo,
                  repo: repo,
                  onTap: (images, index) => showAttachmentViewer(
                    context,
                    images: images,
                    repo: repo,
                    initialIndex: index,
                  ),
                ),
              ],
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onAction(
      BuildContext context, WidgetRef ref, String action) async {
    final l10n = AppLocalizations.of(context)!;
    switch (action) {
      case 'pin':
        try {
          final updated = await ref
              .read(memoRepositoryProvider)!
              .updateMemo(memo.copyWith(pinned: !memo.pinned));
          ref.read(memoMutationProvider.notifier).upsert(updated);
        } catch (e) {
          if (context.mounted) _snack(context, e.toString());
        }
      case 'detail':
        if (context.mounted) context.push('/memos/detail/${memo.uid}');
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
            ref.read(memoMutationProvider.notifier).remove(memo.name);
            ref.invalidate(memoInsightsProvider);
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

/// Memo body that collapses long content behind an expand/collapse link,
/// mirroring flomo's card behavior.
class _ExpandableContent extends StatefulWidget {
  const _ExpandableContent({required this.content, this.onTagTap});

  final String content;
  final ValueChanged<String>? onTagTap;

  @override
  State<_ExpandableContent> createState() => _ExpandableContentState();
}

class _ExpandableContentState extends State<_ExpandableContent> {
  static const _maxLines = 10;
  static const _maxChars = 400;

  bool _expanded = false;

  bool get _isLong {
    final lineCount = '\n'.allMatches(widget.content).length + 1;
    return lineCount > _maxLines || widget.content.length > _maxChars;
  }

  String get _collapsedText {
    final lines = widget.content.split('\n');
    var text = lines.take(_maxLines).join('\n');
    if (text.length > _maxChars) text = text.substring(0, _maxChars);
    // Back off when the cut would leave an unclosed ``` fence.
    if ('```'.allMatches(text).length.isOdd) {
      final fenceAt = text.lastIndexOf('```');
      if (fenceAt > 0) text = text.substring(0, fenceAt);
    }
    return text.trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collapsed = !_expanded && _isLong;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MemoMarkdown(
          content: collapsed ? _collapsedText : widget.content,
          onTagTap: widget.onTagTap,
        ),
        if (_isLong)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AppTheme.tagBlue,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(
                _expanded ? l10n.collapse : l10n.expand,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}
