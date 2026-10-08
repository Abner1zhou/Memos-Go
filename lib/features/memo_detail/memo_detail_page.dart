import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/attachment_image.dart';
import '../../core/widgets/memo_markdown.dart';
import '../../data/models/models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';

/// Read-only memo detail with actions (edit / pin / delete / comment count).
class MemoDetailPage extends ConsumerStatefulWidget {
  const MemoDetailPage({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<MemoDetailPage> createState() => _MemoDetailPageState();
}

class _MemoDetailPageState extends ConsumerState<MemoDetailPage> {
  Memo? _memo;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      final memo = await ref.read(memoRepositoryProvider)!.getMemo(widget.uid);
      if (mounted) setState(() => _memo = memo);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final repo = ref.watch(memoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.memoTab),
        actions: [
          if (_memo != null)
            PopupMenuButton<String>(
              onSelected: _onAction,
              itemBuilder: (context) => [
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
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(_memo!.pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded),
                      const SizedBox(width: 12),
                      Text(_memo!.pinned ? l10n.unpin : l10n.pin),
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
                          style: TextStyle(color: theme.colorScheme.error)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text('$l10n.loadFailed: $_error'))
          : _memo == null || repo == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _error = null);
                    await _load();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      Row(
                        children: [
                          if (_memo!.pinned)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(Icons.push_pin_rounded,
                                  size: 16,
                                  color: theme.colorScheme.primary),
                            ),
                          Expanded(
                            child: Text(
                              formatDateTime(_memo!.createTime,
                                  locale: Localizations.localeOf(context)
                                      .languageCode),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          VisibilityBadge(visibility: _memo!.visibility),
                        ],
                      ),
                      const SizedBox(height: 14),
                      MemoMarkdown(
                        content: _memo!.content,
                        selectable: true,
                        onTagTap: (tag) => context.push('/memos/tag/$tag'),
                      ),
                      if (_memo!.attachments.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        for (final attachment in _memo!.attachments
                            .where((a) => a.isImage && a.name.isNotEmpty))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AspectRatio(
                                aspectRatio: 4 / 3,
                                child: AttachmentImage(
                                  url: repo.attachmentUrl(attachment),
                                  headers: repo.authHeaders,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (_memo!.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in _memo!.tags)
                              ActionChip(
                                label: Text('#$tag'),
                                onPressed: () =>
                                    context.push('/memos/tag/$tag'),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Future<void> _onAction(String action) async {
    final l10n = AppLocalizations.of(context)!;
    final repo = ref.read(memoRepositoryProvider)!;
    final memo = _memo!;
    switch (action) {
      case 'edit':
        context.push('/memos/edit/${memo.uid}');
      case 'pin':
        try {
          final updated =
              await repo.updateMemo(memo.copyWith(pinned: !memo.pinned));
          setState(() => _memo = updated);
        } catch (e) {
          _snack(e.toString());
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(l10n.deleteMemoConfirm),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel)),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.confirm)),
            ],
          ),
        );
        if (confirmed == true) {
          try {
            await repo.deleteMemo(memo.uid);
            ref
                .read(memosListProvider(const MemosQuery()).notifier)
                .removeLocal(memo.name);
            ref.invalidate(tagCountsProvider);
            if (mounted) context.pop();
          } catch (e) {
            _snack(e.toString());
          }
        }
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
