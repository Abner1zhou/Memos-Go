import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:memos_go/features/drawer/activity_heatmap.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
  });

  testWidgets('heatmap stretches to the parent width', (tester) async {
    const parentWidth = 360.0;
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: parentWidth,
              child: ActivityHeatmap(dayCounts: {'2099-01-01': 1}),
            ),
          ),
        ),
      ),
    );

    final heatmap = tester.getRect(find.byType(ActivityHeatmap));
    expect(heatmap.width, closeTo(parentWidth, 0.5));
  });

  testWidgets('heatmap fills a narrower parent too', (tester) async {
    const parentWidth = 240.0;
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        home: Scaffold(
          body: SizedBox(
            width: parentWidth,
            child: ActivityHeatmap(dayCounts: {}, weeks: 12),
          ),
        ),
      ),
    );

    final heatmap = tester.getRect(find.byType(ActivityHeatmap));
    expect(heatmap.width, closeTo(parentWidth, 0.5));
  });
}
