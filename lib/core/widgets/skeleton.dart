import 'package:flutter/material.dart';

/// Lightweight, dependency-free skeleton (shimmer) loading primitives.
///
/// Use these for **content** loads — lists and detail screens fetching data to
/// display — in place of a bare [CircularProgressIndicator]. Keep spinners for
/// action states (submit / pay / pagination footers), where a skeleton would
/// misrepresent what is happening.
///
/// Typical use: wrap a tree of [SkeletonBox]es in a single [Shimmer] so one
/// animation drives the whole placeholder efficiently.
///
/// ```dart
/// Shimmer(
///   child: Column(
///     children: const [
///       SkeletonBox(height: 16, width: 160),
///       SizedBox(height: 8),
///       SkeletonBox(height: 12, width: double.infinity),
///     ],
///   ),
/// )
/// ```
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// When false the child renders as static placeholders (no animation).
  final bool enabled;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant Shimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final base = onSurface.withValues(alpha: 0.09);
    final highlight = onSurface.withValues(alpha: 0.18);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Slide a diagonal highlight band across the masked subtree.
        final t = _controller.value;
        final dx = (t * 2.0) - 1.0; // -1 → 1
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + dx, -0.3),
              end: Alignment(1.0 + dx, 0.3),
              colors: [base, highlight, base],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// A single rounded placeholder block. Paints the skeleton base tone; the
/// enclosing [Shimmer] adds the moving highlight.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.shape = BoxShape.rectangle,
  });

  final double? width;
  final double height;
  final double radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.09);
    return Container(
      width: shape == BoxShape.circle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(radius),
      ),
    );
  }
}

/// A vertical list of identical skeleton items with consistent spacing,
/// wrapped in one [Shimmer]. Pass the placeholder for a single item.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    required this.itemBuilder,
    this.itemCount = 6,
    this.separator = 12,
    this.padding = const EdgeInsets.all(16),
  });

  final IndexedWidgetBuilder itemBuilder;
  final int itemCount;
  final double separator;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(height: separator),
        itemBuilder: itemBuilder,
      ),
    );
  }
}
