import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/navigation.dart';
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import 'memos_page.dart';

/// Memo feed filtered by a single tag (`#tag`).
class TagMemosPage extends ConsumerWidget {
  const TagMemosPage({super.key, required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = MemosQuery(tag: tag);
    final list = ref.watch(memosListProvider(query));
    final repo = ref.watch(memoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text('#$tag')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => pushNewMemoWithTag(context, tag),
        child: const Icon(Icons.add, size: 30),
      ),
      body: MemosFeedBody(query: query, list: list, repo: repo),
    );
  }
}
