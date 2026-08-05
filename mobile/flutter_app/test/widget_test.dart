import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';
import 'package:flutter_app/screens/scan_screen.dart';
import 'package:flutter_app/theme/clay_theme.dart';
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

  testWidgets(
      'rapid successive presses inside a scrolling list each register',
      (tester) async {
    // Regression test: GestureDetector's tap recognizer has to win a gesture
    // arena against a ListView's drag recognizer, so quick repeated taps
    // could get eaten. PopIt drives its animation from raw pointer events
    // instead, which must not have this problem.
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              PopIt.circle(
                size: 60,
                onTap: () => taps++,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );

    final center = tester.getCenter(find.byType(PopIt));
    for (var i = 0; i < 6; i++) {
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();

    expect(taps, 6);
  });

  testWidgets('pressing a bubble scales it down without any lateral shift',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PopIt.circle(
              size: 60,
              onTap: () {},
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ),
    );

    final transformFinder = find.descendant(
      of: find.byType(PopIt),
      matching: find.byType(Transform),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PopIt)),
    );

    var minScale = 1.0;
    for (var elapsed = Duration.zero;
        elapsed < Clay.pressDuration;
        elapsed += const Duration(milliseconds: 15)) {
      await tester.pump(const Duration(milliseconds: 15));
      for (final m in tester.widgetList<Transform>(transformFinder)) {
        // A pure, centred scale carries no translation component — the cap
        // must sink straight into the socket, never slide toward an edge.
        expect(m.transform.getTranslation().x, closeTo(0, 0.001));
        expect(m.transform.getTranslation().y, closeTo(0, 0.001));
        final scaleX = m.transform.getColumn(0).x;
        if (scaleX < minScale) minScale = scaleX;
      }
    }

    // And it must actually have shrunk at some point — this isn't a no-op.
    expect(minScale, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
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
