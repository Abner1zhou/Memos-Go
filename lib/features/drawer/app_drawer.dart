import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/navigation.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import 'activity_heatmap.dart';
import 'tag_tree.dart';

/// Flomo-style navigation drawer: user header, stats, activity heatmap,
/// feature menu and the tag directory.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final user = ref.watch(
        authProvider.select((s) => s.activeAccount?.user));
    final insights = ref.watch(memoInsightsProvider);
    final pinned = ref.watch(pinnedTagsProvider);

    return Drawer(
      width: 312,
      backgroundColor: theme.colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user?.shownName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _HeaderIcon(
                  icon: Icons.search,
                  tooltip: l10n.searchTitle,
                  onPressed: () => _go(context, '/search'),
                ),
                _HeaderIcon(
                  icon: Icons.settings_outlined,
                  tooltip: l10n.settings,
                  onPressed: () => _go(context, '/settings'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            insights.when(
              skipLoadingOnReload: true,
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Text(l10n.loadFailed,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
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
            const SizedBox(height: 22),
            _AllMemosButton(onTap: () => Navigator.of(context).pop()),
            _MenuItem(
              icon: Icons.calendar_today_outlined,
              label: l10n.dailyReview,
              onTap: () => _go(context, '/review'),
            ),
            _MenuItem(
              icon: Icons.shuffle_rounded,
              label: l10n.randomWalk,
              onTap: () => _go(context, '/random'),
            ),
            _MenuItem(
              icon: Icons.delete_outline,
              label: l10n.trash,
              onTap: () => _go(context, '/trash'),
            ),
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
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              )
            else
              _TagTree(
                  tagCounts: insights.valueOrNull?.tagCounts ?? const {}),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String location) {
    Navigator.of(context).pop(); // close the drawer first
    context.push(location);
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, size: 21),
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      onPressed: onPressed,
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
    final numberColor =
        dark ? const Color(0xFF6A7078) : const Color(0xFFC4C9D2);

    final memoCount =
        insights.hasMore ? '${insights.memoCount}+' : '${insights.memoCount}';
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
                    fontSize: 22, fontWeight: FontWeight.w700, color: numberColor),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
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
                        fontSize: 16, fontWeight: FontWeight.w600, color: fg),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: fg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
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
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(label, style: theme.textTheme.bodyMedium),
          ],
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
      onTap: () {
        Navigator.of(context).pop();
        pushTagMemos(context, node.path);
      },
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
                        child: Icon(Icons.chevron_right_rounded,
                            size: 22,
                            color: theme.colorScheme.onSurfaceVariant),
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
                    fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_horiz,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
              onSelected: (_) =>
                  ref.read(pinnedTagsProvider.notifier).toggle(node.path),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
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
      onTap: () {
        Navigator.of(context).pop();
        pushTagMemos(context, tag);
      },
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
                      fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.more_horiz,
                  size: 20, color: theme.colorScheme.onSurfaceVariant),
              onSelected: (_) => ref.read(pinnedTagsProvider.notifier).toggle(tag),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'pin',
                  child: Row(
                    children: [
                      Icon(pinned
                          ? Icons.push_pin_outlined
                          : Icons.push_pin_rounded),
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
