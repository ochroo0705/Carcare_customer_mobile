import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/core/widgets/skeleton.dart';
import 'package:flutter/material.dart';

/// Ready-made, feature-agnostic skeleton placeholders that mirror the shape of
/// the app's real content (all built on [GlassSurface]). Swap these into the
/// `*.loading` full-body branches in place of a centered spinner.
///
/// Each *List widget wraps its items in a single [Shimmer]; the standalone
/// cards/detail are meant to be wrapped by the caller (or used inside a list).

/// A card matching the appointment / order layout: title row + status pill,
/// a subtitle line, a meta (icon + text) row, and an optional trailing amount.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key, this.showTrailing = false});

  /// Renders a right-aligned amount block (history order cards show a price).
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: SkeletonBox(height: 16, width: 150)),
              SizedBox(width: 12),
              SkeletonBox(height: 22, width: 72, radius: 999),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 12, width: 110),
          const SizedBox(height: 12),
          Row(
            children: const [
              SkeletonBox(height: 14, width: 14, radius: 4),
              SizedBox(width: 8),
              SkeletonBox(height: 12, width: 140),
            ],
          ),
          if (showTrailing) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SkeletonBox(height: 12, width: 90),
                SkeletonBox(height: 18, width: 80),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A card matching the organization/discovery layout: leading avatar, two
/// text lines with a chip row, and a trailing control.
class SkeletonAvatarCard extends StatelessWidget {
  const SkeletonAvatarCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 52, width: 52, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 15, width: 160),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: double.infinity),
                SizedBox(height: 10),
                SkeletonBox(height: 20, width: 120, radius: 999),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(height: 20, width: 20, radius: 6),
        ],
      ),
    );
  }
}

/// A card matching the notification layout: leading dot + stacked text lines.
class SkeletonNotificationCard extends StatelessWidget {
  const SkeletonNotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(height: 8, width: 8, shape: BoxShape.circle),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 14, width: 170),
                SizedBox(height: 8),
                SkeletonBox(height: 12, width: double.infinity),
                SizedBox(height: 6),
                SkeletonBox(height: 10, width: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of identical skeleton cards wrapped in one [Shimmer].
class SkeletonCardList extends StatelessWidget {
  const SkeletonCardList({
    super.key,
    this.itemCount = 5,
    this.showTrailing = false,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final bool showTrailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonList(
      itemCount: itemCount,
      padding: padding,
      itemBuilder: (_, _) => SkeletonCard(showTrailing: showTrailing),
    );
  }
}

/// A non-scrolling column of skeleton cards in one [Shimmer]. Use when the
/// placeholder is embedded inside an existing scroll view (e.g. a section of a
/// larger list) where a nested scrollable would not have bounded height.
class SkeletonCardColumn extends StatelessWidget {
  const SkeletonCardColumn({
    super.key,
    this.itemCount = 3,
    this.showTrailing = false,
    this.spacing = 12,
  });

  final int itemCount;
  final bool showTrailing;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            SkeletonCard(showTrailing: showTrailing),
            if (i != itemCount - 1) SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }
}

/// A list of avatar cards (discovery/organizations) wrapped in one [Shimmer].
class SkeletonAvatarCardList extends StatelessWidget {
  const SkeletonAvatarCardList({
    super.key,
    this.itemCount = 5,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonList(
      itemCount: itemCount,
      padding: padding,
      itemBuilder: (_, _) => const SkeletonAvatarCard(),
    );
  }
}

/// A list of notification cards wrapped in one [Shimmer].
class SkeletonNotificationList extends StatelessWidget {
  const SkeletonNotificationList({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SkeletonList(
      itemCount: itemCount,
      padding: padding,
      itemBuilder: (_, _) => const SkeletonNotificationCard(),
    );
  }
}

/// Stacked glass sections approximating a detail screen: a header card plus
/// [sections] body cards, each with a title line and a few rows.
class SkeletonDetail extends StatelessWidget {
  const SkeletonDetail({
    super.key,
    this.sections = 3,
    this.padding = const EdgeInsets.all(16),
  });

  final int sections;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Header card
          GlassSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 18, width: 180)),
                    SizedBox(width: 12),
                    SkeletonBox(height: 24, width: 80, radius: 999),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonBox(height: 12, width: 130),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < sections; i++) ...[
            GlassSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(height: 14, width: 120),
                  SizedBox(height: 14),
                  SkeletonBox(height: 12, width: double.infinity),
                  SizedBox(height: 10),
                  SkeletonBox(height: 12, width: double.infinity),
                  SizedBox(height: 10),
                  SkeletonBox(height: 12, width: 200),
                ],
              ),
            ),
            if (i != sections - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
