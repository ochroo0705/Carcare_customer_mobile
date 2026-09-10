import 'dart:async';

import 'package:carcare_customer_mobile/app/customer_shell.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/screens/diagnostic_detail_screen.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/screens/diagnostics_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_payment_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointments_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/walk_in_order_detail_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:carcare_customer_mobile/features/favorites/presentation/controllers/favorites_controller.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:carcare_customer_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:carcare_customer_mobile/features/history/presentation/screens/service_order_detail_screen.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/add_vehicle_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/vehicle_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Category-first booking-д тодорхой салбар урьдчилан шаардлагагүй болсон
/// тул энэ зам зөвхөн байгууллагын slug-ийг тээнэ (`branchId` арилгав) —
/// салбарыг `BookingRequestScreen` дотор л сонгоно.
class BookingRoutePath extends CustomerRoutePath {
  const BookingRoutePath(this.slug);
  final String slug;
}

class CustomerRouteInformationParser
    extends RouteInformationParser<CustomerRoutePath> {
  @override
  Future<CustomerRoutePath> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final segments = routeInformation.uri.pathSegments;
    if (segments.length == 3 &&
        segments.first == 'organizations' &&
        segments[2] == 'book') {
      return BookingRoutePath(segments[1]);
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
        BookingRoutePath(:final slug) => RouteInformation(
          uri: Uri.parse('/organizations/$slug/book'),
        ),
        DiscoveryRoutePath() => RouteInformation(uri: Uri.parse('/')),
      };
}

class CustomerRouterDelegate extends RouterDelegate<CustomerRoutePath>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<CustomerRoutePath> {
  CustomerRouterDelegate(
    this.organizationRepository,
    this.themeController,
    AuthRepository authRepository,
    this.appointmentRepository,
    this.vehicleRepository,
    this.historyRepository,
    this.diagnosticsRepository,
    this.notificationsRepository,
    this.deviceRepository,
    this.remotePushService,
    this.deviceIdStore,
    this.connectivityService,
    this.cacheStore,
  ) : discoveryController = DiscoveryController(
        organizationRepository,
        cache: cacheStore,
      )..load() {
    organizationDetailController = OrganizationDetailController(
      organizationRepository,
    );
    authController = AuthController(authRepository)..restore();
    appointmentsController = AppointmentsController(
      appointmentRepository,
      cache: cacheStore,
    );
    vehiclesController = VehiclesController(vehicleRepository, cache: cacheStore);
    historyController = HistoryController(historyRepository, cache: cacheStore);
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
    _connectivitySubscription = connectivityService.onConnectivityChanged
        .listen(_onConnectivityChanged);
    // Deep-link a background notification tap into the relevant screen.
    _notificationTapSubscription = remotePushService.onMessageOpenedApp.listen(
      (message) => _handleNotificationTap(message.data),
    );
    // A tap that cold-started the app: handle after the first frame so the
    // shell exists and its tab can be selected.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await remotePushService.getInitialMessage();
      if (initial != null) _handleNotificationTap(initial.data);
    });
  }

  final DiscoveryController discoveryController;
  late final OrganizationDetailController organizationDetailController;
  late final AuthController authController;
  late final AppointmentsController appointmentsController;
  late final VehiclesController vehiclesController;
  late final HistoryController historyController;
  late final NotificationsController notificationsController;
  final OrganizationRepository organizationRepository;
  final ThemeController themeController;
  final AppointmentRepository appointmentRepository;
  final VehicleRepository vehicleRepository;
  final ServiceHistoryRepository historyRepository;
  final DiagnosticsRepository diagnosticsRepository;
  final NotificationsRepository notificationsRepository;
  final DeviceRepository deviceRepository;
  final RemotePushService remotePushService;
  final DeviceIdStore deviceIdStore;
  final ConnectivityService connectivityService;
  final CacheStore cacheStore;
  final FavoritesController favoritesController = FavoritesController();
  late final StreamSubscription<String> _tokenRefreshSubscription;
  late final StreamSubscription<dynamic> _foregroundMessageSubscription;
  late final StreamSubscription<bool> _connectivitySubscription;
  late final StreamSubscription<dynamic> _notificationTapSubscription;
  String? _selectedSlug;
  ({double lat, double lng})? _detailLocation;
  String? _preferredBranchId;
  bool _booking = false;
  String? _selectedOrderId;
  String? _selectedAppointmentId;
  String? _selectedWalkInOrderId;
  bool _showDiagnostics = false;
  String? _selectedDiagnosticId;
  String? _paymentAppointmentId;
  AppointmentPayment? _paymentInitial;
  bool _showLogin = false;
  bool _showAddVehicle = false;
  Vehicle? _selectedVehicle;
  bool _showNotifications = false;
  bool _wasAuthenticated = false;
  bool _disposed = false;

  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  final _shellKey = GlobalKey<CustomerShellState>();

  /// Matches `CustomerShell`'s `destinations` order (Хайх · Захиалгууд · Түүх ·
  /// Профайл).
  static const _appointmentsTabIndex = 1;

  @override
  CustomerRoutePath get currentConfiguration {
    if (_selectedSlug == null) return const DiscoveryRoutePath();
    if (_booking) return BookingRoutePath(_selectedSlug!);
    return OrganizationRoutePath(_selectedSlug!);
  }

  @override
  Widget build(BuildContext context) {
    final organization = organizationDetailController.organization;
    return Navigator(
      key: navigatorKey,
      pages: [
        MaterialPage<void>(
          key: const ValueKey('customer-shell'),
          child: CustomerShell(
            key: _shellKey,
            onLoginRequested: _requestLogin,
            onNotificationsRequested: _openNotifications,
            destinations: [
              DiscoveryScreen(onOrganizationSelected: _selectOrganization),
              AppointmentsScreen(
                onLoginRequested: _requestLogin,
                onAppointmentSelected: _openAppointmentDetail,
                onPaymentRequested: (appointment) =>
                    _openPayment(appointment.id, appointment.payment),
                onWalkInOrderSelected: _openWalkInOrderDetail,
              ),
              HistoryScreen(
                onLoginRequested: _requestLogin,
                onOrderSelected: _openOrderDetail,
                onDiagnosticsRequested: _openDiagnostics,
              ),
              ProfileScreen(
                onLoginRequested: _requestLogin,
                onAddVehicle: _openAddVehicle,
                onVehicleSelected: _openVehicleDetail,
              ),
            ],
          ),
        ),
        if (_selectedSlug != null)
          MaterialPage<void>(
            key: ValueKey('organization-$_selectedSlug'),
            child: OrganizationDetailScreen(
              organization: organization,
              distanceLocation: _detailLocation,
              preferredBranchId: _preferredBranchId,
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
              onBook: (organization) {
                _startBooking(organization.slug);
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
            _booking)
          MaterialPage<void>(
            key: ValueKey('booking-${organization.slug}'),
            child: BookingRequestScreen(
              organization: organization,
              initialBranchId: _preferredBranchId,
              repository: appointmentRepository,
              onAddVehicle: _openAddVehicle,
              onBack: _closeBooking,
              onUnauthenticated: () async {
                await authController.clearConfirmedUnauthorized();
                _showLogin = true;
                notifyListeners();
              },
              onCompleted: (appointment) {
                HapticFeedback.mediumImpact();
                final context = navigatorKey?.currentContext;
                final messenger = context == null
                    ? null
                    : ScaffoldMessenger.maybeOf(context);
                appointmentsController.load();
                // Not just _closeBooking(): that only pops the booking page,
                // leaving the organization detail page underneath still on
                // the stack, so the customer would land back on it (and
                // need an extra manual back-tap to reach the shell/tabs).
                // _closeDetails() clears both, returning straight to the
                // shell root where the tab switch below is actually visible.
                _closeDetails();
                _shellKey.currentState?.selectDestination(
                  _appointmentsTabIndex,
                );
                // Land on the new appointment's detail page (it resolves the
                // id against the list `load()` above kicks off). Backing out of
                // it returns to the appointments tab underneath.
                _openAppointmentDetail(appointment.id);
                messenger?.showSnackBar(
                  const SnackBar(
                    content: Text('Цагийн хүсэлт амжилттай илгээгдлээ.'),
                  ),
                );
                // A booking fee (CUSTOMER_API_CONTRACT.md §4.1) means this
                // appointment isn't actually usable yet — open the payment
                // screen on top of the detail page so the customer pays first;
                // backing out of payment leaves them on the appointment detail.
                if (appointment.payment != null) {
                  _openPayment(appointment.id, appointment.payment);
                }
              },
            ),
          ),
        if (_selectedVehicle != null)
          MaterialPage<void>(
            key: ValueKey('vehicle-detail-${_selectedVehicle!.id}'),
            child: VehicleDetailScreen(
              vehicle: _selectedVehicle!,
              appointments: _appointmentsForVehicle(_selectedVehicle!),
              appointmentsLoading: appointmentsController.state.isLoading,
              onAppointmentSelected: _openAppointmentDetail,
              orders: _ordersForVehicle(_selectedVehicle!),
              ordersLoading: historyController.state.isLoading,
              onOrderSelected: _openOrderDetail,
              onBack: _closeVehicleDetail,
            ),
          ),
        if (_selectedAppointmentId != null)
          MaterialPage<void>(
            key: ValueKey('appointment-detail-$_selectedAppointmentId'),
            child: AppointmentDetailScreen(
              appointmentId: _selectedAppointmentId!,
              organizationRepository: organizationRepository,
              appointmentRepository: appointmentRepository,
              onBack: _closeAppointmentDetail,
              onPay: (appointment) =>
                  _openPayment(appointment.id, appointment.payment),
            ),
          ),
        if (_selectedWalkInOrderId != null)
          MaterialPage<void>(
            key: ValueKey('walk-in-order-detail-$_selectedWalkInOrderId'),
            child: WalkInOrderDetailScreen(
              orderId: _selectedWalkInOrderId!,
              onBack: _closeWalkInOrderDetail,
            ),
          ),
        if (_paymentAppointmentId != null)
          MaterialPage<void>(
            key: ValueKey('payment-$_paymentAppointmentId'),
            child: AppointmentPaymentScreen(
              appointmentId: _paymentAppointmentId!,
              repository: appointmentRepository,
              initialPayment: _paymentInitial,
              onBack: _closePayment,
              onPaymentUpdated: appointmentsController.load,
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
              onReportSelected: _openDiagnosticDetail,
            ),
          ),
        if (_showDiagnostics)
          MaterialPage<void>(
            key: const ValueKey('diagnostics'),
            child: DiagnosticsScreen(
              repository: diagnosticsRepository,
              onBack: _closeDiagnostics,
              onReportSelected: _openDiagnosticDetail,
            ),
          ),
        if (_selectedDiagnosticId != null)
          MaterialPage<void>(
            key: ValueKey('diagnostic-detail-$_selectedDiagnosticId'),
            child: DiagnosticDetailScreen(
              repository: diagnosticsRepository,
              reportId: _selectedDiagnosticId!,
              onBack: _closeDiagnosticDetail,
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
        } else if (_paymentAppointmentId != null) {
          _closePayment();
        } else if (_selectedDiagnosticId != null) {
          _closeDiagnosticDetail();
        } else if (_showDiagnostics) {
          _closeDiagnostics();
        } else if (_selectedOrderId != null) {
          _closeOrderDetail();
        } else if (_showAddVehicle) {
          _closeAddVehicle();
        } else if (_selectedAppointmentId != null) {
          _closeAppointmentDetail();
        } else if (_selectedVehicle != null) {
          _closeVehicleDetail();
        } else if (_selectedWalkInOrderId != null) {
          _closeWalkInOrderDetail();
        } else if (_showLogin) {
          _cancelLogin();
        } else if (_booking) {
          _closeBooking();
        } else if (page.key != const ValueKey('customer-shell')) {
          _closeDetails();
        }
      },
    );
  }

  void _closeDetails() {
    _selectedSlug = null;
    _detailLocation = null;
    _preferredBranchId = null;
    _booking = false;
    notifyListeners();
  }

  void _selectOrganization(Organization summary) {
    _selectedSlug = summary.slug;
    _detailLocation = discoveryController.nearMeLocation;
    // The API returns branches after applying the active branch-level filters
    // (near-me/open-now), and near-me sorts them by distance. Preserve that
    // exact result while loading the richer detail payload. Weekend remains an
    // organization-level eligibility filter by product decision, so it does
    // not by itself identify one branch to pin.
    _preferredBranchId =
        (discoveryController.nearMe || discoveryController.openNow) &&
            summary.branches.isNotEmpty
        ? summary.branches.first.id
        : null;
    organizationDetailController.load(summary.slug);
    notifyListeners();
  }

  void _closeBooking() {
    _booking = false;
    notifyListeners();
  }

  void _startBooking(String slug) {
    _selectedSlug = slug;
    final location = _detailLocation;
    final detail = organizationDetailController.organization;
    if (_preferredBranchId != null &&
        detail != null &&
        detail.branches.any((branch) => branch.id == _preferredBranchId)) {
      // Keep the branch that actually satisfied the discovery filters. The
      // detail payload may contain other branches that are closer but closed.
    } else if (location != null && detail != null) {
      final branches = detail.branches.toList()
        ..sort((a, b) {
          final aDistance = a.distanceKmFrom(
            userLatitude: location.lat,
            userLongitude: location.lng,
          );
          final bDistance = b.distanceKmFrom(
            userLatitude: location.lat,
            userLongitude: location.lng,
          );
          return (aDistance ?? double.infinity).compareTo(
            bDistance ?? double.infinity,
          );
        });
      _preferredBranchId = branches.isEmpty ? null : branches.first.id;
    } else {
      _preferredBranchId = null;
    }
    _booking = true;
    _showLogin = !authController.isAuthenticated;
    notifyListeners();
  }

  void _cancelLogin() {
    _showLogin = false;
    _booking = false;
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

  /// Public entry point for showing the login screen — used by onboarding's
  /// "Бүртгэлдээ нэвтрэх" soft-login hand-off.
  void requestLogin() => _requestLogin();

  void _openAddVehicle() {
    _showAddVehicle = true;
    notifyListeners();
  }

  void _closeAddVehicle() {
    _showAddVehicle = false;
    notifyListeners();
  }

  void _openVehicleDetail(Vehicle vehicle) {
    _selectedVehicle = vehicle;
    notifyListeners();
  }

  List<Appointment> _appointmentsForVehicle(Vehicle vehicle) {
    final plate = vehicle.plate.trim().toUpperCase();
    return appointmentsController.state.appointments
        .where(
          (appointment) =>
              appointment.vehiclePlate?.trim().toUpperCase() == plate,
        )
        .toList(growable: false);
  }

  List<ServiceOrder> _ordersForVehicle(Vehicle vehicle) {
    final plate = vehicle.plate.trim().toUpperCase();
    return historyController.state.orders
        .where(
          (order) => order.vehiclePlate?.trim().toUpperCase() == plate,
        )
        .toList(growable: false);
  }

  void _closeVehicleDetail() {
    _selectedVehicle = null;
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

  /// Тухайн цагийн дэлгэрэнгүйг нээнэ — сая ачаалсан жагсаалтаас биш, ХАМГИЙН
  /// СҮҮЛИЙН төлвийг (жишээ нь: ажилтан аль хэдийн өөрчилсөн ServiceItem
  /// статус) харуулахын тулд орох бүрт дахин ачаална. Дэлгэрэнгүй дэлгэц өөрөө
  /// `StatelessWidget` бөгөөд ямар ч lifecycle hook-гүй тул үүнгүйгээр гарч
  /// орж ирэхэд өмнөх in-memory төлөв хэвээрээ харагдана (network cache биш —
  /// зүгээр л дахин асуугаагүй байсан).
  void _openAppointmentDetail(String id) {
    _selectedAppointmentId = id;
    notifyListeners();
    appointmentsController.load();
  }

  /// Routes a tapped push notification to the relevant screen, per the payload
  /// contract in `carcare.mn/docs/mobile-device-push.md` §4:
  /// `data.appointmentId` (appointment_confirmed/reminder) → that appointment's
  /// detail; anything else (broadcast) → the notifications list. Any transient
  /// overlays already on the stack are cleared first so the target lands
  /// cleanly on the shell.
  void _handleNotificationTap(Map<String, dynamic> data) {
    final appointmentId = data['appointmentId'];
    if (appointmentId is String &&
        appointmentId.isNotEmpty &&
        authController.isAuthenticated) {
      _clearOverlays();
      appointmentsController.load();
      _shellKey.currentState?.selectDestination(_appointmentsTabIndex);
      _openAppointmentDetail(appointmentId);
      return;
    }
    // No routable appointment (broadcast, missing id, or signed out): surface
    // the in-app notifications list, where the message already landed.
    _clearOverlays();
    _openNotifications();
  }

  /// Dismisses every transient page so a deep link isn't buried under whatever
  /// the customer happened to have open.
  void _clearOverlays() {
    _selectedSlug = null;
    _booking = false;
    _selectedOrderId = null;
    _selectedAppointmentId = null;
    _selectedWalkInOrderId = null;
    _showDiagnostics = false;
    _selectedDiagnosticId = null;
    _paymentAppointmentId = null;
    _paymentInitial = null;
    _showLogin = false;
    _showAddVehicle = false;
    _selectedVehicle = null;
    _showNotifications = false;
    notifyListeners();
  }

  void _closeAppointmentDetail() {
    _selectedAppointmentId = null;
    notifyListeners();
  }

  /// `_openAppointmentDetail`-тэй адил зарчим, гэхдээ walk-in захиалгад —
  /// дэлгэрэнгүй нь бүхэлдээ list payload-д аль хэдийн ирсэн тул дахин
  /// ачаалах шаардлагагүй (харах: `WalkInOrderDetailScreen`-ийн тайлбар).
  void _openWalkInOrderDetail(String id) {
    _selectedWalkInOrderId = id;
    notifyListeners();
  }

  void _closeWalkInOrderDetail() {
    _selectedWalkInOrderId = null;
    notifyListeners();
  }

  void _openDiagnostics() {
    _showDiagnostics = true;
    notifyListeners();
  }

  void _closeDiagnostics() {
    _showDiagnostics = false;
    notifyListeners();
  }

  void _openDiagnosticDetail(String id) {
    _selectedDiagnosticId = id;
    notifyListeners();
  }

  void _closeDiagnosticDetail() {
    _selectedDiagnosticId = null;
    notifyListeners();
  }

  void _openPayment(String appointmentId, AppointmentPayment? initial) {
    _paymentAppointmentId = appointmentId;
    _paymentInitial = initial;
    notifyListeners();
  }

  void _closePayment() {
    _paymentAppointmentId = null;
    _paymentInitial = null;
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

  /// Reloads any screen currently showing stale (cached or errored) data the
  /// moment the device regains network connectivity — without this, a
  /// customer who reconnects has to know to manually tap retry on every tab
  /// individually, and tabs they haven't visited yet stay stuck showing the
  /// last failure even after the network is back.
  void _onConnectivityChanged(bool online) {
    if (!online) return;
    if (discoveryController.state.isFromCache ||
        discoveryController.state.status == DiscoveryStatus.error) {
      discoveryController.load();
    }
    if (!authController.isAuthenticated) return;
    if (appointmentsController.state.isFromCache ||
        appointmentsController.state.status == AppointmentsStatus.error) {
      appointmentsController.load();
    }
    if (vehiclesController.state.isFromCache ||
        vehiclesController.state.status == VehiclesStatus.error) {
      vehiclesController.load();
    }
    if (historyController.state.isFromCache ||
        historyController.state.status == HistoryStatus.error) {
      historyController.load();
    }
  }

  /// Registers the current FCM token against `POST /api/v1/app/devices` (see
  /// `CUSTOMER_API_CONTRACT.md` "Push device registration"). Best-effort: a
  /// missing token (no Firebase configured, permission denied, or a platform
  /// this app doesn't ship push on) or a failed request must never block
  /// login.
  Future<void> _registerDeviceForPush() async {
    final account = authController.account;
    if (account == null || _disposed) return;
    try {
      final token = await remotePushService.getToken();
      if (token == null ||
          _disposed ||
          !identical(authController.account, account)) {
        return;
      }
      final deviceId = await deviceIdStore.getOrCreate();
      if (_disposed || !identical(authController.account, account)) return;
      await deviceRepository.registerDevice(
        deviceId: deviceId,
        platform: _platformName,
        firebaseToken: token,
      );
    } catch (_) {
      // Best-effort — push registration failing must never block sign-in.
      if (kDebugMode) debugPrint('Push device registration could not complete.');
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
    final account = authController.account;
    if (account == null || _disposed) return;
    try {
      final deviceId = await deviceIdStore.getOrCreate();
      if (_disposed || !identical(authController.account, account)) return;
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
      case BookingRoutePath(:final slug):
        _selectedSlug = slug;
        _detailLocation = null;
        _preferredBranchId = null;
        _booking = true;
        await organizationDetailController.load(slug);
      case OrganizationRoutePath(:final slug):
        _selectedSlug = slug;
        _detailLocation = null;
        _preferredBranchId = null;
        _booking = false;
        await organizationDetailController.load(slug);
      case DiscoveryRoutePath():
        _selectedSlug = null;
        _booking = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _tokenRefreshSubscription.cancel();
    _foregroundMessageSubscription.cancel();
    _connectivitySubscription.cancel();
    _notificationTapSubscription.cancel();
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
