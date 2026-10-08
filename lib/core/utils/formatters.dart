import 'package:intl/intl.dart';

/// Compact relative time, e.g. `3 分钟前` / `3m ago` depending on locale.
String relativeTime(DateTime? time, {String locale = 'zh'}) {
  if (time == null) return '';
  final now = DateTime.now();
  final diff = now.difference(time.toLocal());

  if (diff.inSeconds < 60) {
    return locale.startsWith('zh') ? '刚刚' : 'just now';
  }
  if (diff.inMinutes < 60) {
    return locale.startsWith('zh')
        ? '${diff.inMinutes} 分钟前'
        : '${diff.inMinutes}m ago';
  }
  if (diff.inHours < 24) {
    return locale.startsWith('zh')
        ? '${diff.inHours} 小时前'
        : '${diff.inHours}h ago';
  }
  if (diff.inDays < 7) {
    return locale.startsWith('zh')
        ? '${diff.inDays} 天前'
        : '${diff.inDays}d ago';
  }
  final year = time.year == now.year ? '' : '${time.year}/';
  return '$year${time.month}/${time.day}';
}

String formatDateTime(DateTime? time, {String locale = 'zh'}) {
  if (time == null) return '';
  return DateFormat('yyyy/MM/dd HH:mm', locale).format(time.toLocal());
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
}

/// Extracts `#tags` from memo content, used for tag chips in the editor.
Set<String> extractTags(String content) {
  final tags = <String>{};
  for (final match in RegExp(r'(^|\s)#([^\s#]+)').allMatches(content)) {
    tags.add(match.group(2)!);
  }
  return tags;
}
