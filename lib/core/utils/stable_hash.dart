/// FNV-1a 变体哈希（32 位，掩码到 31 位正整数），跨进程/重启稳定——
/// 不同于 `Object.hashCode`（每次运行可能不同）。用于缓存指纹与
/// 内容变更检测这类需要持久一致性的场景。
int stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final code in input.codeUnits) {
    hash ^= code;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  // 空串不进循环、返回原始种子（0x811c9dc5，超出 31 位），统一在返回前
  // 掩码，保证结果始终是 31 位正整数。
  return hash & 0x7FFFFFFF;
}
