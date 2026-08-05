import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/scan_screen.dart';
import 'package:flutter_app/widgets/pop_it.dart';

void main() {
  testWidgets('home screen renders the expense tracker with static data',
      (tester) async {
    await tester.pumpWidget(const FinanceTrackerApp());

    expect(find.text('Sai Kumar'), findsOneWidget);
    expect(find.text('Spent this month'), findsOneWidget);
    expect(find.text('₹12,480'), findsOneWidget);
    expect(find.text('Where it went'), findsOneWidget);
    expect(find.text('Swiggy'), findsOneWidget);
  });

  testWidgets('a bubble animates while held and settles after release',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PopIt.circle(
              size: 60,
              onTap: () => taps++,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PopIt)),
    );
    await tester.pump(const Duration(milliseconds: 30));

    // The press animation is running, so frames are still being scheduled.
    expect(tester.binding.hasScheduledFrame, isTrue);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('the scan bubble opens the scanner', (tester) async {
    await tester.pumpWidget(const FinanceTrackerApp());

    // Tap the bubble itself — the label underneath it is not the hit target.
    await tester.tap(find.byIcon(Icons.qr_code_scanner_rounded).first);
    await tester.pumpAndSettle();

    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text('Hold steady over the QR code'), findsOneWidget);
    expect(find.text('Pay via UPI ID'), findsOneWidget);
  });
}
