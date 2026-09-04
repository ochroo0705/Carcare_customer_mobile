import 'package:carcare_customer_mobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:carcare_customer_mobile/features/splash/presentation/splash_gate.dart';
import 'package:carcare_customer_mobile/features/splash/presentation/widgets/animated_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SplashScreen shows the animated logo and wordmark',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashScreen()),
    );
    await tester.pump(); // start the pop-in

    expect(find.byType(AnimatedLogo), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    // wordmark is a two-tone RichText — assert the concatenated text.
    expect(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'Carservice',
      ),
      findsOneWidget,
    );

    // Let the pop-in finish so the gear/heart loops start, then stop pumping
    // (the spin repeats forever — never pumpAndSettle a splash).
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('SplashGate shows the splash alone first, then mounts and '
      'reveals the app', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashGate(
          floor: Duration(milliseconds: 200),
          settle: Duration(milliseconds: 150),
          child: Scaffold(body: Text('APP-BEHIND')),
        ),
      ),
    );
    await tester.pump(); // first frame + post-frame callback

    // During the floor, ONLY the splash is mounted — the heavy app subtree is
    // deliberately not built yet (this is what keeps the animation smooth).
    expect(find.byType(AnimatedLogo), findsOneWidget);
    expect(find.text('APP-BEHIND'), findsNothing);

    // After the floor, the app mounts behind the splash.
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('APP-BEHIND'), findsOneWidget);

    // After the settle + cross-fade, the splash is removed and the app remains.
    await tester.pump(const Duration(milliseconds: 200)); // settle
    await tester.pump(const Duration(milliseconds: 500)); // fade-out (onEnd)
    await tester.pump(); // process the onEnd removal
    expect(find.byType(AnimatedLogo), findsNothing);
    expect(find.text('APP-BEHIND'), findsOneWidget);
  });
}
