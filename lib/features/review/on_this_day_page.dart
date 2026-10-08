import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../data/models/models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import '../memos/memos_page.dart';

/// "On this day" review: memos written on today's month/day in previous
/// years, grouped per year.
class OnThisDayPage extends ConsumerWidget {
  const OnThisDayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final insights = ref.watch(memoInsightsProvider);
    final repo = ref.watch(memoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dailyReview)),
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
          final years = <int, List<Memo>>{};
          for (final memo in ins.memos) {
            final created = memo.createTime?.toLocal();
            if (created == null) continue;
            if (created.month == today.month &&
                created.day == today.day &&
                created.year < today.year) {
              years.putIfAbsent(created.year, () => []).add(memo);
            }
          }
          final sortedYears = years.keys.toList()..sort((a, b) => b.compareTo(a));

          if (sortedYears.isEmpty) {
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

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
            itemCount: sortedYears.length,
            itemBuilder: (context, index) {
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
                  for (final memo in years[year]!)
                    if (repo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: MemoCard(memo: memo, repo: repo),
                      ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
