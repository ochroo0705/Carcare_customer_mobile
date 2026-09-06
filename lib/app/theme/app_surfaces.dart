import 'dart:ui';

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AppShellBackground extends StatelessWidget {
  const AppShellBackground({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.shellBackground,
        gradient: RadialGradient(
          center: const Alignment(-0.75, -1),
          radius: 1.35,
          colors: dark
              ? const [Color(0x33F5A524), Color(0x000B0D10)]
              : const [Color(0x16F5A524), Color(0x00F6F5F2)],
          stops: const [0, 0.72],
        ),
      ),
      child: child,
    );
  }
}

class GlassSurface extends StatefulWidget {
  const GlassSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface>
    with SingleTickerProviderStateMixin {
  // 0 → resting, 1 → fully pressed. The press-in always plays to completion
  // before releasing, so a quick tap reads as a deliberate dip instead of a
  // flicker. Depth is applied as 1 - value * 0.03 (i.e. down to 0.97).
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 220),
  )..addStatusListener((status) {
      // If the finger already lifted while pressing in, spring back once the
      // dip has fully landed.
      if (status == AnimationStatus.completed && !_pointerDown) {
        _press.reverse();
      }
    });

  late final Animation<double> _scale = Tween<double>(begin: 1, end: 0.97)
      .animate(CurvedAnimation(
        parent: _press,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeOut,
      ));

  bool _pointerDown = false;

  bool get _interactive =>
      widget.onTap != null &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  void _onDown() {
    if (!_interactive) return;
    _pointerDown = true;
    _press.forward();
  }

  void _onUp() {
    _pointerDown = false;
    // Reverse now only if the dip already finished; otherwise the status
    // listener reverses it the moment the press-in completes.
    if (_press.status == AnimationStatus.completed) _press.reverse();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    final surface = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: theme.glass,
                border: Border.all(color: theme.glassBorder),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

    if (widget.onTap == null) return surface;

    // A press "give" that coexists with InkWell's ripple: Listener observes
    // raw pointer events without entering the gesture arena, so it never
    // competes with the tap/scroll recognizers underneath.
    return Listener(
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onUp(),
      onPointerCancel: (_) => _onUp(),
      child: ScaleTransition(scale: _scale, child: surface),
    );
  }
}

class CarCareBrand extends StatelessWidget {
  const CarCareBrand({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/brand/mark.png',
          width: compact ? 28 : 32,
          height: compact ? 28 : 32,
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'car'),
              TextSpan(
                text: 'service',
                style: TextStyle(
                  color: dark ? AppColors.amberHover : AppColors.amberLightText,
                ),
              ),
            ],
          ),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: compact ? 17 : 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
