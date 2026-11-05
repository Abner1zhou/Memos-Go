import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/memo_providers.dart';
import '../drawer/activity_heatmap.dart';
import '../drawer/tag_tree.dart';

/// Stats, activity heatmap and tag directory that used to live in the drawer.
/// Embedded in the Me tab so those capabilities stay one tap from primary nav.
class MemoLibrarySection extends ConsumerWidget {
  const MemoLibrarySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final insights = ref.watch(memoInsightsProvider);
    final pinned = ref.watch(pinnedTagsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          insights.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    l10n.loadFailed,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(memoInsightsProvider),
                    child: Text(l10n.retry),
                  ),
                ],
              ),
            ),
            data: (ins) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatsRow(insights: ins),
                const SizedBox(height: 18),
                ActivityHeatmap(dayCounts: ins.dayCounts),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AllMemosButton(onTap: () => context.go('/memos')),
          if (pinned.isNotEmpty) ...[
            _SectionHeader(label: l10n.pinnedTags),
            for (final tag in pinned)
              _TagRow(
                tag: tag,
                count: insights.valueOrNull?.tagCounts[tag],
                pinned: true,
              ),
          ],
          _SectionHeader(label: l10n.allTags),
          if (insights.valueOrNull?.tagCounts.isEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                l10n.noTags,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            _TagTree(tagCounts: insights.valueOrNull?.tagCounts ?? const {}),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.insights});

  final MemoInsights insights;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final numberColor = dark
        ? const Color(0xFF6A7078)
        : const Color(0xFFC4C9D2);

    final memoCount = insights.hasMore
        ? '${insights.memoCount}+'
        : '${insights.memoCount}';
    final oldest = insights.oldest;
    final days = oldest == null
        ? '0'
        : '${DateTime.now().difference(oldest).inDays + 1}';

    Widget stat(String number, String label) => Expanded(
      child: Column(
        children: [
          Text(
            number,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: numberColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Row(
      children: [
        stat(memoCount, l10n.statNotes),
        stat('${insights.tagCounts.length}', l10n.statTags),
        stat(days, l10n.statDays),
      ],
    );
  }
}

class _AllMemosButton extends StatelessWidget {
  const _AllMemosButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final fg = theme.colorScheme.onPrimaryContainer;
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(Icons.notes_rounded, size: 22, color: fg),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.allMemos,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 22, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hierarchical, foldable rendering of the all-tags directory. Tags with `/`
/// separators (e.g. `#level1/level2`) nest below their parent segments;
/// parents start folded and show the aggregated subtree count.
class _TagTree extends ConsumerStatefulWidget {
  const _TagTree({required this.tagCounts});

  final Map<String, int> tagCounts;

  @override
  ConsumerState<_TagTree> createState() => _TagTreeState();
}

class _TagTreeState extends ConsumerState<_TagTree> {
  final Set<String> _expandedPaths = {};

  @override
  Widget build(BuildContext context) {
    final roots = buildTagTree(widget.tagCounts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final node in roots) _buildNode(node, 0)],
    );
  }

  Widget _buildNode(TagNode node, int depth) {
    final expanded = _expandedPaths.contains(node.path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TreeTagRow(
          node: node,
          depth: depth,
          expanded: expanded,
          onToggle: node.hasChildren
              ? () => setState(() => _expandedPaths.toggle(node.path))
              : null,
        ),
        if (node.hasChildren && expanded)
          for (final child in node.sortedChildren) _buildNode(child, depth + 1),
      ],
    );
  }
}

extension _ToggleOnSet<T> on Set<T> {
  void toggle(T value) {
    if (!remove(value)) add(value);
  }
}

class _TreeTagRow extends ConsumerWidget {
  const _TreeTagRow({
    required this.node,
    required this.depth,
    required this.expanded,
    this.onToggle,
  });

  final TagNode node;
  final int depth;
  final bool expanded;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pinned = ref.watch(pinnedTagsProvider).contains(node.path);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => pushTagMemos(context, node.path),
      child: Padding(
        padding: EdgeInsets.only(left: 2.0 + depth * 18, right: 2),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 32,
              child: onToggle == null
                  ? null
                  : InkWell(
                      onTap: onToggle,
                      child: AnimatedRotation(
                        turns: expanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            Text(
              '#',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.tagBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.segment,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${node.totalCount}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_horiz,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onSelected: (_) =>
                  ref.read(pinnedTagsProvider.notifier).toggle(node.path),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        pinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                      ),
                      const SizedBox(width: 12),
                      Text(pinned ? l10n.unpin : l10n.pin),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppTheme.groupTitleColor,
        ),
      ),
    );
  }
}

class _TagRow extends ConsumerWidget {
  const _TagRow({required this.tag, this.count, this.pinned = false});

  final String tag;
  final int? count;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => pushTagMemos(context, tag),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Row(
          children: [
            Text(
              '#',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.tagBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tag,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_horiz,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onSelected: (_) =>
                  ref.read(pinnedTagsProvider.notifier).toggle(tag),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(
                        pinned
                            ? Icons.push_pin_outlined
                            : Icons.push_pin_rounded,
                      ),
                      const SizedBox(width: 12),
                      Text(pinned ? l10n.unpin : l10n.pin),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
