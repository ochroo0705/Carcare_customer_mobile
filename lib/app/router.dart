import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:flutter/material.dart';

sealed class CustomerRoutePath {
  const CustomerRoutePath();
}

class DiscoveryRoutePath extends CustomerRoutePath {
  const DiscoveryRoutePath();
}

class OrganizationRoutePath extends CustomerRoutePath {
  const OrganizationRoutePath(this.slug);
  final String slug;
}

class CustomerRouteInformationParser
    extends RouteInformationParser<CustomerRoutePath> {
  @override
  Future<CustomerRoutePath> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final segments = routeInformation.uri.pathSegments;
    if (segments.length == 2 && segments.first == 'organizations') {
      return OrganizationRoutePath(segments[1]);
    }
    return const DiscoveryRoutePath();
  }

  @override
  RouteInformation? restoreRouteInformation(CustomerRoutePath configuration) =>
      switch (configuration) {
        OrganizationRoutePath(:final slug) => RouteInformation(
          uri: Uri.parse('/organizations/$slug'),
        ),
        DiscoveryRoutePath() => RouteInformation(uri: Uri.parse('/')),
      };
}

class CustomerRouterDelegate extends RouterDelegate<CustomerRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<CustomerRoutePath> {
  CustomerRouterDelegate(OrganizationRepository repository)
    : discoveryController = DiscoveryController(repository)..load() {
    discoveryController.addListener(notifyListeners);
  }

  final DiscoveryController discoveryController;
  String? _selectedSlug;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  CustomerRoutePath get currentConfiguration => _selectedSlug == null
      ? const DiscoveryRoutePath()
      : OrganizationRoutePath(_selectedSlug!);

  @override
  Widget build(BuildContext context) {
    final organization = _selectedSlug == null
        ? null
        : discoveryController.organizationBySlug(_selectedSlug!);
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          key: const ValueKey('discovery'),
          child: DiscoveryScreen(
            controller: discoveryController,
            onOrganizationSelected: (slug) {
              _selectedSlug = slug;
              notifyListeners();
            },
          ),
        ),
        if (_selectedSlug != null)
          MaterialPage<void>(
            key: ValueKey('organization-$_selectedSlug'),
            child: OrganizationDetailScreen(
              organization: organization,
              isLoading: discoveryController.state.isLoading,
              onBack: _closeDetails,
            ),
          ),
      ],
      onDidRemovePage: (page) {
        if (page.key != const ValueKey('discovery')) _closeDetails();
      },
    );
  }

  void _closeDetails() {
    _selectedSlug = null;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(CustomerRoutePath configuration) async {
    _selectedSlug = switch (configuration) {
      OrganizationRoutePath(:final slug) => slug,
      DiscoveryRoutePath() => null,
    };
  }

  @override
  void dispose() {
    discoveryController.removeListener(notifyListeners);
    discoveryController.dispose();
    super.dispose();
  }
}
