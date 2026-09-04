import 'dart:math' as math;

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The Carservice mark drawn as a vector so the gear and heart animate
/// independently: the whole mark **pops in** on load (scale-up with a slight
/// overshoot + fade), then the gear **rotates** continuously while the heart
/// **pulses** in the centre (staying upright). No raster asset — crisp at any
/// size. Mirrors `assets/brand/mark.png`.
class AnimatedLogo extends StatefulWidget {
  const AnimatedLogo({this.size = 140, super.key});

  final double size;

  @override
  State<AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<AnimatedLogo>
    with TickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  // Pop-in: scale 0.35 → 1.08 (overshoot) → 1.0, with the fade over the first
  // half.
  late final Animation<double> _popScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.35, end: 1.08).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 65,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.08, end: 1.0).chain(
        CurveTween(curve: Curves.easeOut),
      ),
      weight: 35,
    ),
  ]).animate(_pop);
  late final Animation<double> _popOpacity = CurvedAnimation(
    parent: _pop,
    curve: const Interval(0, 0.5, curve: Curves.easeOut),
  );
  late final Animation<double> _heartScale = Tween(begin: 1.0, end: 1.07)
      .chain(CurveTween(curve: Curves.easeInOut))
      .animate(_pulse);

  @override
  void initState() {
    super.initState();
    _pop.forward();
    // Gear/heart start only once the pop settles, so the entrance reads as one
    // beat (matches the design preview).
    _pop.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _spin.repeat();
        _pulse.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([_pop, _spin, _pulse]),
    builder: (context, _) => Opacity(
      opacity: _popOpacity.value,
      child: Transform.scale(
        scale: _popScale.value,
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _GearHeartPainter(
            gearAngle: _spin.value * 2 * math.pi,
            heartScale: _heartScale.value,
          ),
        ),
      ),
    ),
  );
}

class _GearHeartPainter extends CustomPainter {
  _GearHeartPainter({required this.gearAngle, required this.heartScale});

  final double gearAngle;
  final double heartScale;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final u = size.width / 200; // design in a 200-unit box
    final amber = Paint()
      ..color = AppColors.amber
      ..isAntiAlias = true;

    // --- gear (rotates about the centre) ---
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(gearAngle);
    const toothW = 27.0, toothH = 40.0, toothR = 10.0, tip = 86.0;
    for (var i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, -(tip - toothH / 2) * u),
            width: toothW * u,
            height: toothH * u,
          ),
          Radius.circular(toothR * u),
        ),
        amber,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 59 * u, amber); // gear body
    canvas.restore();

    // --- white centre hole (static; a circle, so rotation would be invisible) ---
    canvas.drawCircle(center, 32 * u, Paint()..color = Colors.white);

    // --- heart (pulses, stays upright) ---
    canvas.drawPath(
      _heartPath(center.translate(0, 1 * u), 34 * u * heartScale),
      Paint()
        ..color = AppColors.amberHover
        ..isAntiAlias = true,
    );
  }

  Path _heartPath(Offset c, double w) {
    final h = w * 0.9;
    return Path()
      ..moveTo(c.dx, c.dy + h * 0.38)
      ..cubicTo(
        c.dx - w * 0.5, c.dy - h * 0.05,
        c.dx - w * 0.5, c.dy - h * 0.45,
        c.dx, c.dy - h * 0.18,
      )
      ..cubicTo(
        c.dx + w * 0.5, c.dy - h * 0.45,
        c.dx + w * 0.5, c.dy - h * 0.05,
        c.dx, c.dy + h * 0.38,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_GearHeartPainter old) =>
      old.gearAngle != gearAngle || old.heartScale != heartScale;
}
