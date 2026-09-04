import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/splash/presentation/widgets/animated_logo.dart';
import 'package:flutter/material.dart';

/// First-launch splash: the animated Carservice mark (pop-in → spinning gear +
/// pulsing heart), the wordmark, and a loading indicator. Shown over the app
/// while it warms up, then faded out by [SplashGate].
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // A Material ancestor is required so Text resolves a proper default style —
    // without it Flutter draws the debug yellow double-underline under the
    // wordmark.
    return Material(
      color: dark ? AppColors.darkBackground : AppColors.lightBackground,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedLogo(size: 172),
            const SizedBox(height: 32),
            _Wordmark(dark: dark),
            const SizedBox(height: 26),
            const _LoadingDots(),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: const TextStyle(
        fontSize: 31,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        decoration: TextDecoration.none,
      ),
      children: [
        const TextSpan(text: 'Car', style: TextStyle(color: AppColors.amber)),
        TextSpan(
          text: 'service',
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF3A342B),
          ),
        ),
      ],
    ),
  );
}

/// Three amber dots with a staggered blink — a lightweight "loading" cue.
class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        // Each dot's opacity is a phase-shifted sine of the shared clock.
        final phase = (_c.value - i * 0.15) % 1.0;
        final t = (0.5 - (phase - 0.5).abs()) * 2; // triangle 0→1→0
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Opacity(
            opacity: 0.25 + 0.75 * t,
            child: const _Dot(),
          ),
        );
      }),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: const BoxDecoration(
      color: AppColors.amber,
      shape: BoxShape.circle,
    ),
  );
}
