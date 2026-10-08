/// A node in the hierarchical tag tree. Tags containing `/` separators nest
/// under their parent segments, e.g. `#level1/level2` becomes a child of
/// `level1` even when `#level1` itself was never used on a memo.
class TagNode {
  TagNode(this.segment, this.path);

  /// Displayed segment, e.g. `level2`.
  final String segment;

  /// Full tag path, e.g. `level1/level2`.
  final String path;

  final Map<String, TagNode> _children = {};

  /// Memos tagged with exactly [path].
  int ownCount = 0;

  bool get hasChildren => _children.isNotEmpty;

  /// Memos in this subtree (own + all descendants).
  int get totalCount =>
      ownCount + _children.values.fold(0, (sum, c) => sum + c.totalCount);

  List<TagNode> get sortedChildren {
    final list = _children.values.toList()
      ..sort((a, b) {
        final byCount = b.totalCount.compareTo(a.totalCount);
        if (byCount != 0) return byCount;
        return a.segment.compareTo(b.segment);
      });
    return list;
  }

  TagNode _child(String segment, String path) =>
      _children.putIfAbsent(segment, () => TagNode(segment, path));
}

/// Builds the tag hierarchy from a flat `full tag -> memo count` map.
List<TagNode> buildTagTree(Map<String, int> tagCounts) {
  final root = TagNode('', '');
  for (final entry in tagCounts.entries) {
    final segments = entry.key.split('/');
    var node = root;
    var path = '';
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i].trim();
      if (segment.isEmpty) break;
      path = path.isEmpty ? segment : '$path/$segment';
      node = node._child(segment, path);
    }
    node.ownCount = entry.value;
  }
  return root.sortedChildren;
}
