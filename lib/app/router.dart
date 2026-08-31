import 'package:carcare_customer_mobile/features/booking/domain/service_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/service_selection_screen.dart';
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

class ServiceSelectionRoutePath extends CustomerRoutePath {
  const ServiceSelectionRoutePath(this.slug, this.branchId);
  final String slug;
  final String branchId;
}

class CustomerRouteInformationParser
    extends RouteInformationParser<CustomerRoutePath> {
  @override
  Future<CustomerRoutePath> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final segments = routeInformation.uri.pathSegments;
    if (segments.length == 4 &&
        segments.first == 'organizations' &&
        segments[2] == 'book') {
      return ServiceSelectionRoutePath(segments[1], segments[3]);
    }
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
        ServiceSelectionRoutePath(:final slug, :final branchId) =>
          RouteInformation(
            uri: Uri.parse('/organizations/$slug/book/$branchId'),
          ),
        DiscoveryRoutePath() => RouteInformation(uri: Uri.parse('/')),
      };
}

class CustomerRouterDelegate extends RouterDelegate<CustomerRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<CustomerRoutePath> {
  CustomerRouterDelegate(
    OrganizationRepository repository,
    this.serviceRepository,
  ) : discoveryController = DiscoveryController(repository)..load() {
    discoveryController.addListener(notifyListeners);
  }

  final DiscoveryController discoveryController;
  final ServiceRepository serviceRepository;
  String? _selectedSlug;
  String? _bookingBranchId;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  CustomerRoutePath get currentConfiguration {
    if (_selectedSlug == null) return const DiscoveryRoutePath();
    if (_bookingBranchId != null) {
      return ServiceSelectionRoutePath(_selectedSlug!, _bookingBranchId!);
    }
    return OrganizationRoutePath(_selectedSlug!);
  }

  @override
  Widget build(BuildContext context) {
    final organization = _selectedSlug == null
        ? null
        : discoveryController.organizationBySlug(_selectedSlug!);
    final bookingBranch = organization?.branches
        .where((branch) => branch.id == _bookingBranchId)
        .firstOrNull;
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
              onBook: (organization, branch) {
                _selectedSlug = organization.slug;
                _bookingBranchId = branch.id;
                notifyListeners();
              },
            ),
          ),
        if (organization != null && bookingBranch != null)
          MaterialPage<void>(
            key: ValueKey('services-${organization.slug}-${bookingBranch.id}'),
            child: ServiceSelectionScreen(
              organization: organization,
              branch: bookingBranch,
              repository: serviceRepository,
              onBack: _closeBooking,
            ),
          ),
      ],
      onDidRemovePage: (page) {
        if (_bookingBranchId != null) {
          _closeBooking();
        } else if (page.key != const ValueKey('discovery')) {
          _closeDetails();
        }
      },
    );
  }

  void _closeDetails() {
    _selectedSlug = null;
    _bookingBranchId = null;
    notifyListeners();
  }

  void _closeBooking() {
    _bookingBranchId = null;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(CustomerRoutePath configuration) async {
    switch (configuration) {
      case ServiceSelectionRoutePath(:final slug, :final branchId):
        _selectedSlug = slug;
        _bookingBranchId = branchId;
      case OrganizationRoutePath(:final slug):
        _selectedSlug = slug;
        _bookingBranchId = null;
      case DiscoveryRoutePath():
        _selectedSlug = null;
        _bookingBranchId = null;
    }
  }

  @override
  void dispose() {
    discoveryController.removeListener(notifyListeners);
    discoveryController.dispose();
    super.dispose();
  }
}
