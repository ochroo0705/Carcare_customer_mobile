import 'package:carcare_customer_mobile/app/customer_shell.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/screens/favorites_screen.dart';
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
    this.themeController,
    AuthRepository authRepository,
    this.appointmentRepository,
  ) : discoveryController = DiscoveryController(repository)..load() {
    organizationDetailController = OrganizationDetailController(repository);
    authController = AuthController(authRepository)..restore();
    discoveryController.addListener(notifyListeners);
    organizationDetailController.addListener(notifyListeners);
    authController.addListener(notifyListeners);
    favoritesController.addListener(notifyListeners);
    favoritesController.load();
  }

  final DiscoveryController discoveryController;
  late final OrganizationDetailController organizationDetailController;
  late final AuthController authController;
  final ServiceRepository serviceRepository;
  final ThemeController themeController;
  final AppointmentRepository appointmentRepository;
  final FavoritesController favoritesController = FavoritesController();
  String? _selectedSlug;
  String? _bookingBranchId;
  bool _showLogin = false;

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
    final organization = organizationDetailController.organization;
    final bookingBranch = organization?.branches
        .where((branch) => branch.id == _bookingBranchId)
        .firstOrNull;
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          key: const ValueKey('customer-shell'),
          child: CustomerShell(
            themeController: themeController,
            destinations: [
              DiscoveryScreen(
                controller: discoveryController,
                favoritesController: favoritesController,
                onOrganizationSelected: _selectOrganization,
              ),
              FavoritesScreen(
                discoveryController: discoveryController,
                favoritesController: favoritesController,
                onOrganizationSelected: _selectOrganization,
              ),
            ],
          ),
        ),
        if (_selectedSlug != null)
          MaterialPage<void>(
            key: ValueKey('organization-$_selectedSlug'),
            child: OrganizationDetailScreen(
              organization: organization,
              status: organizationDetailController.status,
              errorMessage: organizationDetailController.message,
              onRetry: () => organizationDetailController.load(_selectedSlug!),
              onBack: _closeDetails,
              isFavorite:
                  organization != null &&
                  favoritesController.contains(organization.slug),
              onFavoriteToggle: () {
                if (organization != null) {
                  favoritesController.toggle(organization.slug);
                }
              },
              onBook: (organization, branch) {
                _startBooking(organization.slug, branch.id);
              },
            ),
          ),
        if (_showLogin)
          MaterialPage<void>(
            key: const ValueKey('booking-login'),
            child: LoginScreen(
              controller: authController,
              onBack: _cancelLogin,
              onAuthenticated: _resumeBooking,
            ),
          ),
        if (!_showLogin &&
            authController.isAuthenticated &&
            organization != null &&
            bookingBranch != null)
          MaterialPage<void>(
            key: ValueKey('booking-${organization.slug}-${bookingBranch.id}'),
            child: BookingRequestScreen(
              organization: organization,
              branch: bookingBranch,
              repository: appointmentRepository,
              onBack: _closeBooking,
              onUnauthenticated: () async {
                await authController.clearConfirmedUnauthorized();
                _showLogin = true;
                notifyListeners();
              },
              onCompleted: (appointment) {
                final context = navigatorKey?.currentContext;
                final messenger = context == null
                    ? null
                    : ScaffoldMessenger.maybeOf(context);
                _closeBooking();
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Цагийн хүсэлт амжилттай илгээгдлээ.'),
                  ),
                );
              },
            ),
          ),
      ],
      onDidRemovePage: (page) {
        if (_showLogin) {
          _cancelLogin();
        } else if (_bookingBranchId != null) {
          _closeBooking();
        } else if (page.key != const ValueKey('customer-shell')) {
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

  void _selectOrganization(String slug) {
    _selectedSlug = slug;
    organizationDetailController.load(slug);
    notifyListeners();
  }

  void _closeBooking() {
    _bookingBranchId = null;
    notifyListeners();
  }

  void _startBooking(String slug, String branchId) {
    _selectedSlug = slug;
    _bookingBranchId = branchId;
    _showLogin = !authController.isAuthenticated;
    notifyListeners();
  }

  void _cancelLogin() {
    _showLogin = false;
    _bookingBranchId = null;
    authController.resetFlow();
    notifyListeners();
  }

  void _resumeBooking() {
    _showLogin = false;
    notifyListeners();
  }

  @override
  Future<void> setNewRoutePath(CustomerRoutePath configuration) async {
    switch (configuration) {
      case ServiceSelectionRoutePath(:final slug, :final branchId):
        _selectedSlug = slug;
        _bookingBranchId = branchId;
        await organizationDetailController.load(slug);
      case OrganizationRoutePath(:final slug):
        _selectedSlug = slug;
        _bookingBranchId = null;
        await organizationDetailController.load(slug);
      case DiscoveryRoutePath():
        _selectedSlug = null;
        _bookingBranchId = null;
    }
  }

  @override
  void dispose() {
    discoveryController.removeListener(notifyListeners);
    organizationDetailController.removeListener(notifyListeners);
    authController.removeListener(notifyListeners);
    favoritesController.removeListener(notifyListeners);
    discoveryController.dispose();
    organizationDetailController.dispose();
    authController.dispose();
    favoritesController.dispose();
    super.dispose();
  }
}
