import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/text_clip.dart';
import '../../data/local/suggestion_dao.dart' show MemoSuggestionsRowParsed;
import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/llm_providers.dart';
import '../../providers/memo_providers.dart';
import '../../providers/memo_suggestion_providers.dart';

/// "AI 建议" strip at the bottom of the memo detail page (spec §7): tag
/// chips append `#tag` to the memo content via the repository; related
/// memos navigate to their detail page. Renders nothing when the feature
/// is off or the memo has no cached suggestion.
class MemoSuggestionSection extends ConsumerWidget {
  const MemoSuggestionSection({super.key, required this.memo});

  final Memo memo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(llmProvider.select((s) =>
        s.isConfigured && s.suggestOnSave && s.embeddingModel.trim().isNotEmpty));
    if (!enabled) return const SizedBox.shrink();
    final row = ref.watch(memoSuggestionProvider(memo.uid)).value;
    if (row == null) return const SizedBox.shrink();
    final tags = [
      for (final t in row.tagList)
        if (!memo.tags.contains(t) &&
            !memo.content.contains('#$t')) t
    ];
    final related = row.relatedUidList;
    if (tags.isEmpty && related.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 28),
        Row(children: [
          Icon(Icons.auto_awesome_outlined,
              size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(l10n.suggestTitle,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in tags)
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 14),
                  label: Text('#$tag'),
                  onPressed: () => _applyTag(context, ref, tag),
                ),
            ],
          ),
        ],
        if (related.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(l10n.suggestRelated,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          SizedBox(
            height: 64,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final name in related)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: _RelatedChipLabel(uid: name.split('/').last),
                      onPressed: () =>
                          context.push('/memos/detail/${name.split('/').last}'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _applyTag(
      BuildContext context, WidgetRef ref, String tag) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(memoRepositoryProvider);
    if (repo == null) return;
    try {
      final current = await repo.getMemo(memo.uid);
      if (current.content.contains('#$tag')) return;
      final content = current.content.trimRight();
      final next = content.isEmpty ? '#$tag' : '$content #$tag';
      await repo.updateMemo(current.copyWith(content: next));
      ref.read(memoMutationProvider.notifier).upsert(
          current.copyWith(content: next));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.suggestTagAdded(tag))));
    } catch (_) {
      // 静默：详情页自身会随流刷新，失败不弹错（spec：不打断）。
    }
  }
}

/// Chip label for one related memo: a clipped content excerpt watched from
/// the local mirror, falling back to the uid when the memo is gone or its
/// content is empty. Keeps the parent build free of imperative fetches.
class _RelatedChipLabel extends ConsumerWidget {
  const _RelatedChipLabel({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(memoWatchProvider(uid)).value;
    final content = record?.memo.content.trim() ?? '';
    return Text(
      content.isEmpty ? uid : clipText(content, 16),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
