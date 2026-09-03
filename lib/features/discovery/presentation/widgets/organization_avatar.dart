import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular organization logo. Renders [logoUrl] via [CachedNetworkImage]
/// (memory + disk cached, so a logo is fetched once across the discovery list,
/// detail page and map), falling back to the organization's initial letter
/// while loading, on error, or when no logo URL is published.
class OrganizationAvatar extends StatelessWidget {
  const OrganizationAvatar({
    required this.name,
    required this.logoUrl,
    this.radius = 26,
    super.key,
  });

  final String name;
  final String? logoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        name.characters.isEmpty ? '?' : name.characters.first.toUpperCase(),
      ),
    );

    final url = logoUrl?.trim();
    if (url == null || url.isEmpty) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
