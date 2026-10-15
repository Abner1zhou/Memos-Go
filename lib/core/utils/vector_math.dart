import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

/// Decodes a little-endian float32 blob into a vector.
Float32List decodeVector(Uint8List bytes) {
  final out = Float32List(bytes.length ~/ 4);
  final view = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
  for (var i = 0; i < out.length; i++) {
    out[i] = view.getFloat32(i * 4, Endian.little);
  }
  return out;
}

/// Encodes a vector as little-endian float32 bytes for the blob column.
Uint8List encodeVector(List<double> vector) {
  final view = ByteData(vector.length * 4);
  for (var i = 0; i < vector.length; i++) {
    view.setFloat32(i * 4, vector[i], Endian.little);
  }
  return view.buffer.asUint8List();
}

/// Cosine similarity; zero vectors and length mismatches yield 0.
double cosineSimilarity(Float32List a, Float32List b) {
  if (a.isEmpty || a.length != b.length) return 0;
  var dot = 0.0, na = 0.0, nb = 0.0;
  for (var i = 0; i < a.length; i++) {
    dot += a[i] * b[i];
    na += a[i] * a[i];
    nb += b[i] * b[i];
  }
  if (na == 0 || nb == 0) return 0;
  return dot / (math.sqrt(na) * math.sqrt(nb));
}

class ScoredUid {
  const ScoredUid(this.uid, this.score);

  final String uid;
  final double score;
}

/// Brute-force cosine top-k over the stored vectors, computed in a
/// background isolate (personal-scale corpora: a few thousand × 1024-dim
/// scans take single-digit milliseconds but would jank the UI thread).
Future<List<ScoredUid>> topKSimilar(
    Float32List query, Map<String, Uint8List> vectors, int k) {
  return Isolate.run(() {
    final scored = <ScoredUid>[
      for (final entry in vectors.entries)
        ScoredUid(entry.key, cosineSimilarity(query, decodeVector(entry.value)))
    ];
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(k).toList();
  });
}
