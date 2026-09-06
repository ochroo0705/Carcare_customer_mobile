import 'package:flutter/material.dart';

/// Shared, dependency-free motion primitives. Tuned subtle & fast (~180ms) and
/// respect the platform "reduce motion" accessibility setting — when that is on,
/// children appear immediately with no transform.
///
/// IMPORTANT: these use only *transforms* (translate/scale), never [Opacity].
/// Cards here are `GlassSurface`, which blurs the background with a
/// `BackdropFilter`; wrapping a `BackdropFilter` in an opacity layer disables
/// its sampling for the duration of the fade and then snaps it back on when the
/// layer is removed — a visible flicker of the blurred background. Transforms
/// don't isolate a layer, so the glass keeps compositing correctly throughout.

const Duration _kFast = Duration(milliseconds: 220);
const Curve _kEase = Curves.easeOutCubic;

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Slides (and gently scales) a child up into place when it first mounts. Pass
/// an [index] to stagger a list: each item waits `index * stepDelay` before
/// starting. No opacity — see the file header for why.
class RiseIn extends StatefulWidget {
  const RiseIn({
    super.key,
    required this.child,
    this.index = 0,
    this.stepDelay = const Duration(milliseconds: 45),
    this.duration = _kFast,
    this.offset = 16,
  });

  final Widget child;
  final int index;
  final Duration stepDelay;
  final Duration duration;

  /// Vertical distance (logical px) the child travels while easing in.
  final double offset;

  @override
  State<RiseIn> createState() => _RiseInState();
}

class _RiseInState extends State<RiseIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _controller,
    curve: _kEase,
  );

  @override
  void initState() {
    super.initState();
    final delay = widget.stepDelay * widget.index;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        return Transform.translate(
          offset: Offset(0, (1 - t) * widget.offset),
          child: Transform.scale(
            scale: 0.98 + t * 0.02,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
