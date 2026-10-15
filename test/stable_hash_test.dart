import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/stable_hash.dart';

void main() {
  test('stableHash is deterministic and restart-stable', () {
    expect(stableHash('部署了 k8s'), stableHash('部署了 k8s'));
    expect(stableHash('a'), isNot(stableHash('b')));
    expect(stableHash(''), 0x811c9dc5 & 0x7FFFFFFF);
  });

  test('stableHash distinguishes contents of equal length', () {
    expect(stableHash('abc'), isNot(stableHash('acb')));
  });
}
