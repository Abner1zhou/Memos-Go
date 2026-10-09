import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import '../memos/memos_page.dart';

/// Daily review, flomo-style: every day resurfaces a random batch of past
/// memos ("N days/months/years ago you wrote ..."), plus an "on this day in
/// past years" section when such memos exist.
class DailyReviewPage extends ConsumerStatefulWidget {
  const DailyReviewPage({super.key});

  @override
  ConsumerState<DailyReviewPage> createState() => _DailyReviewPageState();
}

class _DailyReviewPageState extends ConsumerState<DailyReviewPage> {
  static const _sampleSize = 10;

  /// Incremented per manual re-roll; the base seed is today's date so a given
  /// day renders a stable batch across rebuilds.
  int _roll = 0;

  List<Memo> _sample(List<Memo> pool) {
    final now = DateTime.now();
    final rng = Random(now.year * 10000 + now.month * 100 + now.day + _roll);
    final copy = [...pool]..shuffle(rng);
    return copy.take(_sampleSize).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final insights = ref.watch(memoInsightsProvider);
    final repo = ref.watch(memoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dailyReview),
        actions: [
          IconButton(
            tooltip: l10n.reviewShuffle,
            onPressed: () => setState(() => _roll++),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: insights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${l10n.loadFailed}: $e',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall),
              TextButton(
                onPressed: () => ref.invalidate(memoInsightsProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (ins) {
          final today = DateTime.now();
          final pool = ins.memos
              .where((m) =>
                  m.state == MemoState.normal && m.content.trim().isNotEmpty)
              .toList();

          if (pool.isEmpty || repo == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_outlined,
                      size: 52, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noReviewYet,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }

          final onThisDay = <int, List<Memo>>{};
          for (final memo in pool) {
            final created = memo.createTime?.toLocal();
            if (created == null) continue;
            if (created.month == today.month &&
                created.day == today.day &&
                created.year < today.year) {
              onThisDay.putIfAbsent(created.year, () => []).add(memo);
            }
          }
          final sortedYears = onThisDay.keys.toList()
            ..sort((a, b) => b.compareTo(a));
          // Recall samples exclude on-this-day memos so nothing shows twice.
          final seen =
              onThisDay.values.expand((list) => list).map((m) => m.name).toSet();
          final recalled =
              _sample(pool.where((m) => !seen.contains(m.name)).toList());

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            itemCount: sortedYears.length + recalled.length,
            itemBuilder: (context, index) {
              if (index < sortedYears.length) {
                final year = sortedYears[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                      child: Text(
                        l10n.yearsAgoToday(today.year - year),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final memo in onThisDay[year]!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MemoCard(memo: memo, repo: repo),
                      ),
                  ],
                );
              }
              final memo = recalled[index - sortedYears.length];
              return Padding(
                key: ValueKey('recall-$_roll-${memo.name}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                      child: Text(
                        _agoLabel(l10n, memo.createTime?.toLocal(), today),
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    MemoCard(memo: memo, repo: repo),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _agoLabel(AppLocalizations l10n, DateTime? created, DateTime now) {
    if (created == null) return l10n.wroteToday;
    final days = now.difference(created).inDays;
    if (days < 1) return l10n.wroteToday;
    if (days < 30) return l10n.wroteDaysAgo(days);
    var months = (now.year - created.year) * 12 + now.month - created.month;
    if (now.day < created.day) months--;
    if (months < 1) return l10n.wroteDaysAgo(days);
    if (months < 12) return l10n.wroteMonthsAgo(months);
    return l10n.wroteYearsAgo(months ~/ 12);
  }
}
