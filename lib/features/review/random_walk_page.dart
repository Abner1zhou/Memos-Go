import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../data/models/models.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import '../memos/memos_page.dart';

/// Random walk: shows a random sample of memos and lets the user re-roll.
class RandomWalkPage extends ConsumerStatefulWidget {
  const RandomWalkPage({super.key});

  @override
  ConsumerState<RandomWalkPage> createState() => _RandomWalkPageState();
}

class _RandomWalkPageState extends ConsumerState<RandomWalkPage> {
  static const _sampleSize = 10;

  /// Incremented per re-roll; seeds the sampler so a given roll renders a
  /// stable batch across rebuilds while pool changes still apply.
  int _roll = 0;

  List<Memo> _sample(List<Memo> pool) {
    final rng = Random(_roll);
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
      appBar: AppBar(title: Text(l10n.randomWalk)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _roll++),
        icon: const Icon(Icons.shuffle_rounded),
        label: Text(l10n.walkAgain),
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
          final pool = ins.memos
              .where((m) =>
                  m.state == MemoState.normal && m.content.trim().isNotEmpty)
              .toList();
          if (pool.isEmpty) {
            return Center(
              child: Text(
                l10n.emptyMemoTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            );
          }
          final picks = _sample(pool);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            itemCount: picks.length,
            itemBuilder: (context, index) => Padding(
              key: ValueKey('random-$_roll-${picks[index].name}'),
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  repo == null ? null : MemoCard(memo: picks[index], repo: repo),
            ),
          );
        },
      ),
    );
  }
}
