import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/core/utils/vector_math.dart';

void main() {
  test('encode/decode roundtrips float32', () {
    final bytes = encodeVector([0.25, -1.5, 3.0]);
    expect(bytes.lengthInBytes, 12);
    final back = decodeVector(bytes);
    expect(back.length, 3);
    expect(back[0], closeTo(0.25, 1e-6));
    expect(back[1], closeTo(-1.5, 1e-6));
  });

  test('cosine of identical vectors is ~1, orthogonal is 0', () {
    final a = Float32List.fromList([1, 0]);
    expect(cosineSimilarity(a, Float32List.fromList([2, 0])), closeTo(1, 1e-6));
    expect(cosineSimilarity(a, Float32List.fromList([0, 5])), closeTo(0, 1e-6));
  });

  test('cosine guards zero vectors and length mismatch', () {
    expect(cosineSimilarity(Float32List(2), Float32List.fromList([1, 2])), 0);
    expect(cosineSimilarity(Float32List.fromList([1]),
        Float32List.fromList([1, 2])), 0);
  });

  test('topKSimilar ranks by cosine and cuts to k', () async {
    final query = Float32List.fromList([1, 0]);
    final vectors = <String, Uint8List>{
      'orth': encodeVector([0, 1]),
      'same': encodeVector([3, 0]),
      'half': encodeVector([1, 1]),
      'neg': encodeVector([-1, 0]),
    };
    final top = await topKSimilar(query, vectors, 3);
    expect(top.map((s) => s.uid).toList(), ['same', 'half', 'orth']);
    expect(top.first.score, closeTo(1, 1e-6));
  });
}
