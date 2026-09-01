import 'package:carcare_customer_mobile/app/theme/app_surfaces.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/organization_card.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:flutter/material.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    required this.discoveryController,
    required this.favoritesController,
    required this.onOrganizationSelected,
    super.key,
  });

  final DiscoveryController discoveryController;
  final FavoritesController favoritesController;
  final ValueChanged<String> onOrganizationSelected;

  @override
  Widget build(BuildContext context) {
    final organizations = discoveryController.state.organizations
        .where(
          (organization) => favoritesController.contains(organization.slug),
        )
        .toList(growable: false);
    return AppShellBackground(
      child: SafeArea(
        child: organizations.isEmpty
            ? const _EmptyFavorites()
            : ListView.separated(
                key: const PageStorageKey('favorites-list'),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                itemCount: organizations.length + 1,
                separatorBuilder: (_, index) =>
                    SizedBox(height: index == 0 ? 18 : 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Хадгалсан сервисүүд',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Энэ төхөөрөмж дээр хадгалсан ${organizations.length} сервис',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    );
                  }
                  final organization = organizations[index - 1];
                  return OrganizationCard(
                    organization: organization,
                    isFavorite: true,
                    onFavoriteToggle: () =>
                        favoritesController.toggle(organization.slug),
                    onTap: () => onOrganizationSelected(organization.slug),
                  );
                },
              ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            'Хадгалсан сервис алга',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Сервисийн зүрхэн тэмдгийг дарж энд хадгалаарай.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );
}
