import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memos_go/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App boots to the login screen when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MemosGoApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(Scaffold), findsWidgets);
  });
}
