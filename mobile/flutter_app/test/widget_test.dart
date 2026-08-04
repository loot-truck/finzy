import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('renders the sign-in and classify controls', (tester) async {
    await tester.pumpWidget(const FinanceTrackerApp());

    expect(find.text('Finance Tracker'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Classify'), findsOneWidget);
    expect(find.text('Not signed in'), findsOneWidget);
  });
}
