import 'package:characters/characters.dart';

/// Clips [text] to at most [maxChars] grapheme clusters (emoji- and
/// CJK-safe, unlike String.substring's UTF-16 units), trimming ends and
/// appending an ellipsis when clipped. Shared budget helper for prompts,
/// cache titles and excerpts.
String clipText(String text, int maxChars) {
  final trimmed = text.trim();
  if (trimmed.characters.length <= maxChars) return trimmed;
  return '${trimmed.characters.take(maxChars).toString()}…';
}
