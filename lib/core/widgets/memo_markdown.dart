import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../data/models/models.dart';

/// Renders memo content as Markdown. `#tags` are rewritten into internal
/// links so they become tappable chips.
class MemoMarkdown extends StatelessWidget {
  const MemoMarkdown({
    super.key,
    required this.content,
    this.onTagTap,
    this.selectable = false,
  });

  final String content;
  final ValueChanged<String>? onTagTap;
  final bool selectable;

  static final RegExp _tagInCode = RegExp(r'```[\s\S]*?```|`[^`\n]*`');
  static final RegExp _tagPattern = RegExp(r'(^|[\s(])#([^\s#),.；。，、]+)');

  /// Wraps `#tag` occurrences into markdown links; code spans are preserved.
  String _linkifyTags(String src) {
    final codeSpans = <String>[];
    var out = src.replaceAllMapped(_tagInCode, (m) {
      codeSpans.add(m.group(0)!);
      return '\u0000${codeSpans.length - 1}\u0000';
    });
    out = out.replaceAllMapped(_tagPattern, (m) {
      final prefix = m.group(1) ?? '';
      final tag = m.group(2)!;
      return '$prefix[#$tag](#tag:$tag)';
    });
    for (var i = 0; i < codeSpans.length; i++) {
      out = out.replaceFirst('\u0000$i\u0000', codeSpans[i]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkColor = theme.colorScheme.primary;
    return MarkdownBody(
      data: _linkifyTags(content),
      selectable: selectable,
      shrinkWrap: true,
      extensionSet: md.ExtensionSet.gitHubWeb,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
        h1: theme.textTheme.titleLarge,
        h2: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        h3: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        blockquoteDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(6),
        ),
        codeblockDecoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        code: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: theme.colorScheme.onSurface,
        ),
        listBullet: theme.textTheme.bodyMedium,
        checkbox: theme.textTheme.bodyMedium,
        a: TextStyle(color: linkColor, fontWeight: FontWeight.w500),
      ),
      onTapLink: (text, href, title) {
        if (href == null) return;
        if (href.startsWith('#tag:')) {
          onTagTap?.call(href.substring(5));
          return;
        }
        debugPrint('open url: $href');
      },
    );
  }
}

/// Visibility badge shown on memo cards.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({super.key, required this.visibility});

  final MemoVisibility visibility;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (icon, label) = switch (visibility) {
      MemoVisibility.private => (Icons.lock_outline, l10n.visibilityPrivate),
      MemoVisibility.protected =>
        (Icons.group_outlined, l10n.visibilityProtected),
      MemoVisibility.public => (Icons.public, l10n.visibilityPublic),
      MemoVisibility.space => (Icons.workspaces_outline, l10n.visibilitySpace),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
