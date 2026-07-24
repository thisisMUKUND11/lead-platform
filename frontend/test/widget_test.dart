import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/pages/capture_page.dart';

void main() {
  Widget wrap(Widget child) =>
      ProviderScope(child: MaterialApp(home: child));

  group('Public capture form validation', () {
    testWidgets('shows errors when submitting an empty form', (tester) async {
      await tester.pumpWidget(wrap(const CapturePage()));

      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pump();

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('rejects an invalid email', (tester) async {
      await tester.pumpWidget(wrap(const CapturePage()));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Full name *'),
        'Jordan',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email *'),
        'not-an-email',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
      expect(find.text('Name is required'), findsNothing);
    });
  });
}
