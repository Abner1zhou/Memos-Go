import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/memo_markdown.dart';
import '../../data/api/llm_api.dart';
import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/llm_providers.dart';
import 'review_digest.dart';

enum _Phase { unconfigured, idle, loading, ready, error }

/// "AI 摘要" card atop the daily review page: summarizes today's memos and
/// echoes past years' same-day memos via the configured LLM. Results are
/// cached per day; a changed input fingerprint keeps the card usable via
/// "重新生成" instead of re-billing automatically.
class ReviewDigestCard extends ConsumerStatefulWidget {
  const ReviewDigestCard({
    super.key,
    required this.today,
    required this.onThisDay,
  });

  final List<Memo> today;

  /// Year -> same-day memos written that year.
  final Map<int, List<Memo>> onThisDay;

  @override
  ConsumerState<ReviewDigestCard> createState() => _ReviewDigestCardState();
}

class _ReviewDigestCardState extends ConsumerState<ReviewDigestCard> {
  _Phase _phase = _Phase.idle;
  String? _content;
  String? _error;

  ReviewDigestInput get _input =>
      ReviewDigestInput(today: widget.today, onThisDay: widget.onThisDay);

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final settings = await ref.read(llmRepositoryProvider).load();
      if (!mounted) return;
      if (!settings.isConfigured) {
        setState(() => _phase = _Phase.unconfigured);
        return;
      }
      final cached = await ReviewDigestCache().load(_dayKey(DateTime.now()));
      if (!mounted) return;
      if (cached != null && cached.fingerprint == _input.fingerprint()) {
        setState(() {
          _phase = _Phase.ready;
          _content = cached.content;
        });
      }
    });
  }

  static String _dayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    final repo = ref.read(llmRepositoryProvider);
    final settings = await repo.load();
    if (!mounted) return;
    if (!settings.isConfigured) {
      setState(() => _phase = _Phase.unconfigured);
      return;
    }
    final input = _input;
    final now = DateTime.now();
    final language = Localizations.localeOf(context).languageCode;
    try {
      final content = await repo.chat(
        settings,
        messages: [
          LlmChatMessage(
              role: 'system', content: reviewDigestSystemPrompt(language)),
          LlmChatMessage(
              role: 'user',
              content: buildReviewDigestUserPrompt(input,
                  now: now, language: language)),
        ],
      );
      await ReviewDigestCache().save(
        _dayKey(now),
        ReviewDigestEntry(
          content: content,
          fingerprint: input.fingerprint(),
          generatedAt: now,
        ),
      );
      if (!mounted) return;
      setState(() {
        _phase = _Phase.ready;
        _content = content;
      });
    } catch (e) {
      if (!mounted) return;
      final api = asLlmApiError(e);
      setState(() {
        _phase = _Phase.error;
        _error = '${l10n.digestFailed}: ${api?.message ?? e}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (widget.today.isEmpty && widget.onThisDay.isEmpty) {
      return const SizedBox.shrink();
    }

    final Widget body;
    switch (_phase) {
      case _Phase.unconfigured:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.digestNotConfigured,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => context.push('/settings/llm'),
              child: Text(l10n.digestGoConfig),
            ),
          ],
        );
      case _Phase.idle:
        body = FilledButton.tonal(
          onPressed: _generate,
          child: Text(l10n.digestGenerate),
        );
      case _Phase.loading:
        body = const Center(
          child: Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      case _Phase.ready:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MemoMarkdown(content: _content ?? ''),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l10n.digestRegenerate),
              ),
            ),
          ],
        );
      case _Phase.error:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error ?? '',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
            TextButton(onPressed: _generate, child: Text(l10n.retry)),
          ],
        );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 6),
                Text(l10n.digestTitle,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}
