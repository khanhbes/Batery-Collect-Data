// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:ev_data_logger/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Home form validation is shown for invalid values', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: EvDataLoggerApp()));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byType(TextFormField).at(0), '120');
    await tester.enterText(find.byType(TextFormField).at(1), '-5');

    await tester.tap(find.text('Start Trip'));
    await tester.pump();

    expect(find.text('Start SoC must be between 0 and 100.'), findsOneWidget);
    expect(
      find.text('Payload must be greater than or equal to 0.'),
      findsOneWidget,
    );
  });
}
