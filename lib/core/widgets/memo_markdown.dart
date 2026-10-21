import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';

/// Renders memo content as Markdown. `#tags` are rewritten into internal
/// links so they become tappable chips; `[n]` markers become tappable cite
/// links when the caller listens for citations. Code spans/fences and, in
/// the cite case, existing markdown links are never rewritten.
class MemoMarkdown extends StatelessWidget {
  const MemoMarkdown({
    super.key,
    required this.content,
    this.onTagTap,
    this.onCiteTap,
    this.selectable = false,
  });

  final String content;
  final ValueChanged<String>? onTagTap;
  final ValueChanged<int>? onCiteTap;
  final bool selectable;

  static final RegExp _tagInCode = RegExp(r'```[\s\S]*?```|`[^`\n]*`');
  static final RegExp _tagPattern = RegExp(r'(^|[\s(])#([^\s#),.；。，、]+)');

  /// Existing markdown links (inline `[text](url)`, reference
  /// `[text][ref]`) and reference link definitions (`[ref]: url`) that the
  /// cite rewrite must not corrupt.
  static final RegExp _mdLink = RegExp(
      r'\[[^\]]*\]\([^)]*\)|\[[^\]]*\]\[[^\]]*\]|\[[^\]]*\]:[ \t]*\S+');

  /// Replaces every [pattern] match with a `sentinel<index>sentinel`
  /// placeholder, remembering the originals in [store] in order. Pair with
  /// [_restore] using the same [sentinel]; one sentinel per region kind keeps
  /// the restore passes from colliding.
  static String _mask(
      String src, RegExp pattern, String sentinel, List<String> store) {
    return src.replaceAllMapped(pattern, (m) {
      store.add(m.group(0)!);
      return '$sentinel${store.length - 1}$sentinel';
    });
  }

  /// Restores every `$sentinel<n>$sentinel` placeholder made by [_mask].
  static String _restore(String src, String sentinel, List<String> store) {
    for (var i = 0; i < store.length; i++) {
      src = src.replaceFirst('$sentinel$i$sentinel', store[i]);
    }
    return src;
  }

  /// Wraps `#tag` occurrences into markdown links.
  static String _rewriteTags(String src) {
    return src.replaceAllMapped(_tagPattern, (m) {
      final prefix = m.group(1) ?? '';
      final tag = m.group(2)!;
      return '$prefix[#$tag](#tag:$tag)';
    });
  }

  /// Rewrites `[n]` citation markers into tappable links.
  static String _rewriteCites(String src) {
    return src.replaceAllMapped(RegExp(r'\[(\d{1,3})\]'), (m) {
      return '[[${m[1]}]](#cite:${m[1]})';
    });
  }

  /// Full transform: `#tags` become chips, and — only when [onCiteTap] is
  /// set (chat answers) — `[n]` markers become cite links. Code spans/fences
  /// stay masked across both rewrites; with cites active, existing markdown
  /// links are masked too, so neither is ever rewritten. Without [onCiteTap]
  /// (the memo path) the output is byte-identical to tags-only rewriting.
  String _linkify(String src) {
    final code = <String>[];
    var out = _mask(src, _tagInCode, '\u0000', code);
    out = _rewriteTags(out);
    if (onCiteTap != null) {
      final links = <String>[];
      out = _mask(out, _mdLink, '\u0001', links);
      out = _rewriteCites(out);
      out = _restore(out, '\u0001', links);
    }
    return _restore(out, '\u0000', code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MarkdownBody(
      data: _linkify(content),
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
        a: TextStyle(color: AppTheme.tagBlue, fontWeight: FontWeight.w500),
      ),
      onTapLink: (text, href, title) {
        if (href == null) return;
        if (href.startsWith('#tag:')) {
          // The markdown parser percent-encodes link destinations
          // (CommonMark destination normalization), so a Chinese tag written
          // as `(#tag:中文)` arrives here as `#tag:%E4%B8%AD%E6%96%87`.
          onTagTap?.call(Uri.decodeComponent(href.substring(5)));
          return;
        }
        if (href.startsWith('#cite:')) {
          final n = int.tryParse(Uri.decodeComponent(href.substring(6)));
          if (n != null) onCiteTap?.call(n);
          return;
        }
        debugPrint('open url: $href');
      },
    );
  }
}

/// Visibility badge shown on memo cards. [compact] renders the icon only.
class VisibilityBadge extends StatelessWidget {
  const VisibilityBadge({super.key, required this.visibility, this.compact = false});

  final MemoVisibility visibility;
  final bool compact;

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
    if (compact) {
      return Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant);
    }
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
