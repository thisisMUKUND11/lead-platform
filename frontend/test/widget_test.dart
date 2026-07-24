import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/pages/capture_page.dart';

void main() {
  Widget wrap(Widget child) =>
      ProviderScope(child: MaterialApp(home: child));

  final submitButton = find.widgetWithText(FilledButton, 'Submit');

  Future<void> tapSubmit(WidgetTester tester) async {
    // The submit button can sit below the test viewport; scroll it in first.
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pump();
  }

  group('Public capture form validation', () {
    testWidgets('shows errors when submitting an empty form', (tester) async {
      await tester.pumpWidget(wrap(const CapturePage()));

      await tapSubmit(tester);

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Phone is required'), findsOneWidget);
      expect(find.text('Company is required'), findsOneWidget);
    });

    testWidgets('rejects an invalid email', (tester) async {
      await tester.pumpWidget(wrap(const CapturePage()));

      // Fields in order: name, email, phone, company.
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Jordan');
      await tester.enterText(fields.at(1), 'not-an-email');
      await tapSubmit(tester);

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Name is required'), findsNothing);
    });
  });
}
