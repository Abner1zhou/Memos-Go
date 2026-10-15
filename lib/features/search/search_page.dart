import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/memo_codec.dart' show MemoRecord;
import '../../providers/auth_providers.dart';
import '../../providers/memo_providers.dart';
import '../../providers/semantic_search_providers.dart';
import '../memos/memos_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _query = '';
  String _semanticQuery = '';
  Timer? _semanticDebounce;

  @override
  void dispose() {
    _semanticDebounce?.cancel();
    super.dispose();
  }

  /// The semantic provider is a per-string autoDispose family that pays a
  /// keychain read, a full vector scan and one embeddings call per key —
  /// debounce the key so typing doesn't fan out into per-keystroke calls.
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _semanticDebounce?.cancel();
    _semanticDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _semanticQuery = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final trimmed = _query.trim();
    final query = MemosQuery(search: trimmed.isEmpty ? null : trimmed);
    final list = ref.watch(memosListProvider(query));
    final repo = ref.watch(memoRepositoryProvider);
    // Hybrid search: keyword hits stay the primary feed; semantic hits add
    // a related-memos rail on top when the LLM layer has vectors.
    final semantic = _semanticQuery.isEmpty
        ? const <MemoRecord>[]
        : ref.watch(semanticSearchProvider(_semanticQuery)).value ?? const <MemoRecord>[];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.searchTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: SearchBar(
              leading: const Icon(Icons.search),
              hintText: l10n.searchHint,
              onChanged: _onQueryChanged,
            ),
          ),
          if (semantic.isNotEmpty && repo != null)
            SizedBox(
              height: 170,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                    child: Row(children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(l10n.searchSemantic,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: semantic.length,
                      itemBuilder: (context, index) => SizedBox(
                        width: 280,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: MemoCard(
                              memo: semantic[index].memo, repo: repo),
                        ),
                      ),
                    ),
                  ),
                ],
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
