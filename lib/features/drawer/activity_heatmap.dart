import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';

/// GitHub-style contribution heatmap showing memos created per day.
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key, required this.dayCounts, this.weeks = 16});

  /// `yyyy-MM-dd` (local) -> number of memos created that day.
  final Map<String, int> dayCounts;
  final int weeks;

  static const _cellSize = 13.0;
  static const _gap = 3.0;

  String _keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final dark = theme.brightness == Brightness.dark;
    final emptyColor =
        dark ? const Color(0xFF2A2B2F) : const Color(0xFFECEDF0);
    final shades = dark
        ? const [
            Color(0xFF1E4B33),
            Color(0xFF276B47),
            Color(0xFF2F8C59),
            Color(0xFF3ACB82),
          ]
        : const [
            Color(0xFFC9EED8),
            Color(0xFF8FE0AE),
            Color(0xFF4FCB85),
            Color(0xFF22A45E),
          ];

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final thisMonday = today.subtract(Duration(days: today.weekday - 1));
    final firstMonday = thisMonday.subtract(Duration(days: 7 * (weeks - 1)));

    Color levelOf(int count) {
      if (count <= 0) return emptyColor;
      if (count == 1) return shades[0];
      if (count <= 3) return shades[1];
      if (count <= 6) return shades[2];
      return shades[3];
    }

    Widget cell(int week, int row) {
      final date = firstMonday.add(Duration(days: week * 7 + row));
      if (date.isAfter(todayDate)) {
        return const SizedBox(width: _cellSize, height: _cellSize);
      }
      final isToday = date == todayDate;
      return Container(
        width: _cellSize,
        height: _cellSize,
        decoration: BoxDecoration(
          color: levelOf(dayCounts[_keyOf(date)] ?? 0),
          borderRadius: BorderRadius.circular(3),
          border: isToday
              ? Border.all(color: AppTheme.brandGreenDark, width: 1.5)
              : null,
        ),
      );
    }

    // Month label above the week column containing the 1st of a month.
    final labels = <int, String>{};
    var lastLabeledMonth = -1;
    for (var w = 0; w < weeks; w++) {
      final monday = firstMonday.add(Duration(days: 7 * w));
      if (monday.day <= 7 && monday.month != lastLabeledMonth) {
        labels[w] = DateFormat.MMM(locale).format(monday);
        lastLabeledMonth = monday.month;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 14,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final entry in labels.entries)
                Positioned(
                  left: entry.key * (_cellSize + _gap),
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < 7; row++)
          Padding(
            padding: EdgeInsets.only(bottom: row == 6 ? 0 : _gap),
            child: Row(
              children: [
                for (var w = 0; w < weeks; w++) ...[
                  if (w > 0) const SizedBox(width: _gap),
                  cell(w, row),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
