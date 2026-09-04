import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/features/splash/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shows [SplashScreen] on launch, then reveals the app.
///
/// Wired via `MaterialApp.router`'s `builder`, where [child] is the app's
/// Router. Crucially, the heavy app subtree (controllers, the Discovery map, the
/// whole render tree) is only built when [child] is actually **mounted** — so
/// for the first [floor] the gate mounts *only* the splash, keeping those
/// frames cheap enough for the pop-in/spin to animate smoothly. Then it mounts
/// the app behind the splash (its build cost is now hidden under the overlay)
/// and, after a short settle, cross-fades the splash out.
///
/// This is still time-boxed rather than tied to a real "app is warm" signal —
/// that readiness hook, and the first-run onboarding hand-off, attach here next.
class SplashGate extends StatefulWidget {
  const SplashGate({
    required this.child,
    this.floor = const Duration(milliseconds: 1300),
    this.settle = const Duration(milliseconds: 550),
    super.key,
  });

  final Widget child;

  /// How long only the splash is mounted (app not yet built), so the entrance
  /// animation plays on cheap frames.
  final Duration floor;

  /// Grace period after the app mounts (its build cost hidden under the splash)
  /// before the splash fades out.
  final Duration settle;

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _mountApp = false; // heavy app subtree mounted behind the splash?
  bool _hideSplash = false; // fading the splash out?
  bool _removed = false; // fade done — splash fully removed from the tree

  @override
  void initState() {
    super.initState();
    if (debugDisableAppBootstrap) return; // tests: no splash, no timers
    // Wait for the splash's first frame to actually paint before starting the
    // clock, so the floor is measured from when the animation is on screen.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future.delayed(widget.floor, () {
        if (!mounted) return;
        setState(() => _mountApp = true); // build the app behind the splash
        Future.delayed(widget.settle, () {
          if (mounted) setState(() => _hideSplash = true);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (debugDisableAppBootstrap) return widget.child;
    return Stack(
      fit: StackFit.expand,
    children: [
      // Nothing heavy is built until _mountApp flips — this is what keeps the
      // opening frames cheap. The splash stays at index 1 throughout so its
      // State (and running animation) is preserved across these rebuilds.
      if (_mountApp) widget.child else const SizedBox.expand(),
      if (!_removed)
        IgnorePointer(
          ignoring: _hideSplash,
          child: AnimatedOpacity(
            opacity: _hideSplash ? 0 : 1,
            duration: const Duration(milliseconds: 450),
            // Once faded out, drop the splash entirely so its animation
            // controllers stop and it isn't kept alive behind the app.
            onEnd: () {
              if (_hideSplash && mounted) setState(() => _removed = true);
            },
            child: const SplashScreen(),
          ),
        ),
      ],
    );
  }
}
