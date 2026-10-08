import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import '../memos/memos_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final trimmed = _query.trim();
    final query = MemosQuery(search: trimmed.isEmpty ? null : trimmed);
    final list = ref.watch(memosListProvider(query));
    final repo = ref.watch(memoRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: l10n.searchHint,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: trimmed.isEmpty
                ? Center(
                    child: Text(
                      l10n.searchHint,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : MemosFeedBody(query: query, list: list, repo: repo),
          ),
        ],
      ),
    );
  }
}
