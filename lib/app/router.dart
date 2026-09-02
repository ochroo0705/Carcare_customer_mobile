import 'dart:async';

import 'package:carcare_customer_mobile/app/customer_shell.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointments_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:carcare_customer_mobile/features/history/presentation/screens/service_order_detail_screen.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/add_vehicle_screen.dart';
import 'package:flutter/foundation.dart';
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

class BookingRoutePath extends CustomerRoutePath {
  const BookingRoutePath(this.slug, this.branchId);
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
      return BookingRoutePath(segments[1], segments[3]);
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
        BookingRoutePath(:final slug, :final branchId) => RouteInformation(
          uri: Uri.parse('/organizations/$slug/book/$branchId'),
        ),
        DiscoveryRoutePath() => RouteInformation(uri: Uri.parse('/')),
      };
}

class CustomerRouterDelegate extends RouterDelegate<CustomerRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<CustomerRoutePath> {
  CustomerRouterDelegate(
    OrganizationRepository repository,
    this.themeController,
    AuthRepository authRepository,
    this.appointmentRepository,
    this.vehicleRepository,
    this.historyRepository,
    this.notificationsRepository,
    this.deviceRepository,
    this.remotePushService,
    this.deviceIdStore,
  ) : discoveryController = DiscoveryController(repository)..load() {
    organizationDetailController = OrganizationDetailController(repository);
    authController = AuthController(authRepository)..restore();
    appointmentsController = AppointmentsController(appointmentRepository);
    vehiclesController = VehiclesController(vehicleRepository);
    historyController = HistoryController(historyRepository);
    notificationsController = NotificationsController(notificationsRepository);
    discoveryController.addListener(notifyListeners);
    organizationDetailController.addListener(notifyListeners);
    authController.addListener(notifyListeners);
    authController.addListener(_onAuthChanged);
    appointmentsController.addListener(notifyListeners);
    vehiclesController.addListener(notifyListeners);
    historyController.addListener(notifyListeners);
    notificationsController.addListener(notifyListeners);
    favoritesController.addListener(notifyListeners);
    favoritesController.load();
    _tokenRefreshSubscription = remotePushService.onTokenRefresh.listen(
      _onTokenRefreshed,
    );
    _foregroundMessageSubscription = remotePushService.onMessage.listen(
      (message) => notificationsController.handleIncomingPush(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
      ),
    );
  }

  final DiscoveryController discoveryController;
  late final OrganizationDetailController organizationDetailController;
  late final AuthController authController;
  late final AppointmentsController appointmentsController;
  late final VehiclesController vehiclesController;
  late final HistoryController historyController;
  late final NotificationsController notificationsController;
  final ThemeController themeController;
  final AppointmentRepository appointmentRepository;
  final VehicleRepository vehicleRepository;
  final ServiceHistoryRepository historyRepository;
  final NotificationsRepository notificationsRepository;
  final DeviceRepository deviceRepository;
  final RemotePushService remotePushService;
  final DeviceIdStore deviceIdStore;
  final FavoritesController favoritesController = FavoritesController();
  late final StreamSubscription<String> _tokenRefreshSubscription;
  late final StreamSubscription<dynamic> _foregroundMessageSubscription;
  String? _selectedSlug;
  String? _bookingBranchId;
  String? _selectedOrderId;
  bool _showLogin = false;
  bool _showAddVehicle = false;
  bool _showNotifications = false;
  bool _wasAuthenticated = false;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();

  @override
  CustomerRoutePath get currentConfiguration {
    if (_selectedSlug == null) return const DiscoveryRoutePath();
    if (_bookingBranchId != null) {
      return BookingRoutePath(_selectedSlug!, _bookingBranchId!);
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
            onLoginRequested: _requestLogin,
            onNotificationsRequested: _openNotifications,
            destinations: [
              DiscoveryScreen(onOrganizationSelected: _selectOrganization),
              AppointmentsScreen(onLoginRequested: _requestLogin),
              HistoryScreen(
                onLoginRequested: _requestLogin,
                onOrderSelected: _openOrderDetail,
              ),
              ProfileScreen(
                onLoginRequested: _requestLogin,
                onAddVehicle: _openAddVehicle,
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
              onAddVehicle: _openAddVehicle,
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
        if (_showAddVehicle)
          MaterialPage<void>(
            key: const ValueKey('add-vehicle'),
            child: AddVehicleScreen(
              repository: vehicleRepository,
              onBack: _closeAddVehicle,
              onAdded: (vehicle) {
                final context = navigatorKey?.currentContext;
                final messenger = context == null
                    ? null
                    : ScaffoldMessenger.maybeOf(context);
                _closeAddVehicle();
                vehiclesController.load();
                messenger?.showSnackBar(
                  const SnackBar(content: Text('Машин нэмэгдлээ.')),
                );
              },
            ),
          ),
        if (_selectedOrderId != null)
          MaterialPage<void>(
            key: ValueKey('order-detail-$_selectedOrderId'),
            child: ServiceOrderDetailScreen(
              repository: historyRepository,
              orderId: _selectedOrderId!,
              onBack: _closeOrderDetail,
            ),
          ),
        if (_showNotifications)
          MaterialPage<void>(
            key: const ValueKey('notifications'),
            child: NotificationsScreen(onBack: _closeNotifications),
          ),
      ],
      onDidRemovePage: (page) {
        if (_showNotifications) {
          _closeNotifications();
        } else if (_selectedOrderId != null) {
          _closeOrderDetail();
        } else if (_showAddVehicle) {
          _closeAddVehicle();
        } else if (_showLogin) {
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

  void _requestLogin() {
    _showLogin = true;
    notifyListeners();
  }

  void _openAddVehicle() {
    _showAddVehicle = true;
    notifyListeners();
  }

  void _closeAddVehicle() {
    _showAddVehicle = false;
    notifyListeners();
  }

  void _openOrderDetail(String id) {
    _selectedOrderId = id;
    notifyListeners();
  }

  void _closeOrderDetail() {
    _selectedOrderId = null;
    notifyListeners();
  }

  void _openNotifications() {
    _showNotifications = true;
    notifyListeners();
  }

  void _closeNotifications() {
    _showNotifications = false;
    notifyListeners();
  }

  void _onAuthChanged() {
    final isAuthenticated = authController.isAuthenticated;
    if (isAuthenticated && !_wasAuthenticated) {
      appointmentsController.load();
      vehiclesController.load();
      historyController.load();
      notificationsController.load();
      _registerDeviceForPush();
    } else if (!isAuthenticated && _wasAuthenticated) {
      appointmentsController.reset();
      vehiclesController.reset();
      historyController.reset();
      notificationsController.reset();
      _removeDeviceForPush();
    }
    _wasAuthenticated = isAuthenticated;
  }

  /// Registers the current FCM token against `POST /api/v1/app/devices` (see
  /// `CUSTOMER_API_CONTRACT.md` "Push device registration"). Best-effort: a
  /// missing token (no Firebase configured, permission denied, or a platform
  /// this app doesn't ship push on) or a failed request must never block
  /// login.
  Future<void> _registerDeviceForPush() async {
    try {
      final token = await remotePushService.getToken();
      if (token == null) return;
      final deviceId = await deviceIdStore.getOrCreate();
      await deviceRepository.registerDevice(
        deviceId: deviceId,
        platform: _platformName,
        firebaseToken: token,
      );
    } catch (_) {
      // Best-effort — push registration failing must never block sign-in.
    }
  }

  Future<void> _removeDeviceForPush() async {
    try {
      final deviceId = await deviceIdStore.getOrCreate();
      await deviceRepository.removeDevice(deviceId);
    } catch (_) {
      // Best-effort — matches the API doc's "call during logout when possible".
    }
  }

  /// The API contract requires re-registering whenever the FCM token
  /// refreshes, but only while signed in — there's no account to attach an
  /// unauthenticated refresh to.
  Future<void> _onTokenRefreshed(String token) async {
    if (!authController.isAuthenticated) return;
    try {
      final deviceId = await deviceIdStore.getOrCreate();
      await deviceRepository.registerDevice(
        deviceId: deviceId,
        platform: _platformName,
        firebaseToken: token,
      );
    } catch (_) {
      // Best-effort, same as _registerDeviceForPush.
    }
  }

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

  @override
  Future<void> setNewRoutePath(CustomerRoutePath configuration) async {
    switch (configuration) {
      case BookingRoutePath(:final slug, :final branchId):
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
    _tokenRefreshSubscription.cancel();
    _foregroundMessageSubscription.cancel();
    discoveryController.removeListener(notifyListeners);
    organizationDetailController.removeListener(notifyListeners);
    authController.removeListener(notifyListeners);
    authController.removeListener(_onAuthChanged);
    appointmentsController.removeListener(notifyListeners);
    vehiclesController.removeListener(notifyListeners);
    historyController.removeListener(notifyListeners);
    notificationsController.removeListener(notifyListeners);
    favoritesController.removeListener(notifyListeners);
    discoveryController.dispose();
    organizationDetailController.dispose();
    authController.dispose();
    appointmentsController.dispose();
    vehiclesController.dispose();
    historyController.dispose();
    notificationsController.dispose();
    favoritesController.dispose();
    super.dispose();
  }
}
