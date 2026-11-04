/// Bumped when the user clears LLM credentials so in-flight suggestion and
/// chat writes do not recreate rows a privacy wipe just deleted.
class AiActivityGuard {
  int _epoch = 0;

  int get epoch => _epoch;

  void invalidate() => _epoch++;
}
