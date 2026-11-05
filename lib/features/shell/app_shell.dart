import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../memos/voice_memo_capture.dart';

/// Finder key for the persistent primary navigation bar.
const primaryNavBarKey = Key('primary-nav');

/// Shell around the four primary branches. Compose sits in the center of the
/// bar: a tap opens the editor, a long-press starts quick voice capture.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  var _voiceBusy = false;

  Future<void> _quickVoiceMemo() async {
    if (_voiceBusy) return;
    HapticFeedback.mediumImpact();
    setState(() => _voiceBusy = true);
    try {
      await captureVoiceMemo(context, ref);
    } finally {
      if (mounted) setState(() => _voiceBusy = false);
    }
  }

  void _onBranch(int branch) {
    widget.navigationShell.goBranch(
      branch,
      initialLocation: branch == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    // extendBody stays false: each branch is laid out above the bar, so
    // lists and settings rows are not covered by it.
    return Scaffold(
      extendBody: false,
      body: widget.navigationShell,
      bottomNavigationBar: _PrimaryNavBar(
        key: primaryNavBarKey,
        selectedBranch: widget.navigationShell.currentIndex,
        composeBusy: _voiceBusy,
        onBranchSelected: _onBranch,
        onCompose: () => context.push('/memos/new'),
        onComposeLongPress: _voiceBusy ? null : _quickVoiceMemo,
      ),
    );
  }
}

class _PrimaryNavBar extends StatelessWidget {
  const _PrimaryNavBar({
    super.key,
    required this.selectedBranch,
    required this.composeBusy,
    required this.onBranchSelected,
    required this.onCompose,
    required this.onComposeLongPress,
  });

  /// Index into the shell branches: memos, search, review, me.
  final int selectedBranch;
  final bool composeBusy;
  final ValueChanged<int> onBranchSelected;
  final VoidCallback onCompose;
  final VoidCallback? onComposeLongPress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: _NavItem(
                    icon: Icons.notes_outlined,
                    selectedIcon: Icons.notes_rounded,
                    label: l10n.memoTab,
                    selected: selectedBranch == 0,
                    onTap: () => onBranchSelected(0),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.search,
                    selectedIcon: Icons.search,
                    label: l10n.searchTitle,
                    selected: selectedBranch == 1,
                    onTap: () => onBranchSelected(1),
                  ),
                ),
                _ComposeButton(
                  label: l10n.navCompose,
                  busy: composeBusy,
                  tooltip: l10n.newMemoFabTooltip,
                  onTap: onCompose,
                  onLongPress: onComposeLongPress,
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.event_note_outlined,
                    selectedIcon: Icons.event_note,
                    label: l10n.navReview,
                    selected: selectedBranch == 2,
                    onTap: () => onBranchSelected(2),
                  ),
                ),
                Expanded(
                  child: _NavItem(
                    icon: Icons.person_outline,
                    selectedIcon: Icons.person,
                    label: l10n.navMe,
                    selected: selectedBranch == 3,
                    onTap: () => onBranchSelected(3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = selected
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    final labelColor = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              selected ? selectedIcon : icon,
              size: 22,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeButton extends StatelessWidget {
  const _ComposeButton({
    required this.label,
    required this.busy,
    required this.tooltip,
    required this.onTap,
    required this.onLongPress,
  });

  final String label;
  final bool busy;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background =
        theme.floatingActionButtonTheme.backgroundColor ??
        theme.colorScheme.primary;
    final foreground =
        theme.floatingActionButtonTheme.foregroundColor ?? Colors.white;

    return Semantics(
      button: true,
      label: tooltip,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Material(
              color: background,
              elevation: 1,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: busy ? null : onTap,
                onLongPress: busy ? null : onLongPress,
                child: SizedBox(
                  width: 46,
                  height: 32,
                  child: busy
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: foreground,
                            ),
                          ),
                        )
                      : Icon(Icons.add, size: 24, color: foreground),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
