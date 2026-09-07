import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/organization_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class OrganizationCard extends StatelessWidget {
  const OrganizationCard({
    required this.organization,
    required this.onTap,
    this.isFavorite = false,
    this.onFavoriteToggle,
    super.key,
  });
  final Organization organization;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primaryBranch = organization.branches.first;
    return GlassSurface(
      key: ValueKey('organization-${organization.slug}'),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrganizationAvatar(
            name: organization.name,
            logoUrl: organization.logoUrl,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organization.name,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  primaryBranch.locationLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.storefront_outlined,
                      label: '${organization.branches.length} салбар',
                    ),
                    // "Ойролцоо" шүүлт идэвхтэй үед хамгийн ойр салбарын зай
                    // (branches нь сервер талд ойроор эрэмбэлэгдсэн).
                    if (primaryBranch.distanceLabel != null)
                      _InfoChip(
                        icon: Icons.near_me_outlined,
                        label: primaryBranch.distanceLabel!,
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: ValueKey('favorite-${organization.slug}'),
                onPressed: onFavoriteToggle == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onFavoriteToggle!();
                      },
                tooltip: isFavorite ? 'Хадгалснаас хасах' : 'Хадгалах',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    // Key by state so the switcher pops the heart on toggle.
                    key: ValueKey(isFavorite),
                    color: isFavorite ? scheme.primary : null,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
