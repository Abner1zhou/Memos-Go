import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/memo_codec.dart' show MemoRecord;
import 'auth_providers.dart';
import 'retrieval_providers.dart';

/// Semantic top-12 for a query, shared retrieval with chat. Degrades to an
/// empty list on every failure path — keyword search never breaks.
final semanticSearchProvider =
    FutureProvider.autoDispose.family<List<MemoRecord>, String>(
        (ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return const [];

  final account = ref.watch(authProvider).activeAccount;
  if (account == null) return const [];

  try {
    final hits = await ref
        .watch(retrievalServiceProvider)
        .retrieve(account.id, trimmed);
    return [for (final h in hits) h.record];
  } catch (_) {
    return const [];
  }
});
