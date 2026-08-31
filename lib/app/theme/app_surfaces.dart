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
              ? const [Color(0x334F46E5), Color(0x0012142B)]
              : const [Color(0x167C3AED), Color(0x00F4F5FA)],
          stops: const [0, 0.72],
        ),
      ),
      child: child,
    );
  }
}

class GlassSurface extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = CarCareTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.large),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: theme.glass,
                border: Border.all(color: theme.glassBorder),
                borderRadius: BorderRadius.circular(AppRadii.large),
              ),
              child: child,
            ),
          ),
        ),
      ),
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
          dark ? 'assets/brand/mark-dark.png' : 'assets/brand/mark-light.png',
          width: compact ? 28 : 32,
          height: compact ? 28 : 32,
        ),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'car'),
              TextSpan(
                text: 'care',
                style: TextStyle(
                  color: dark
                      ? const Color(0xFFA78BFA)
                      : AppColors.violetLightText,
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
