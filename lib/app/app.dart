import 'package:carcare_customer_mobile/core/notifications/local_push_service.dart';
import 'package:carcare_customer_mobile/app/app_dependencies.dart';
import 'package:carcare_customer_mobile/core/widgets/network_status_strip.dart';
import 'package:carcare_customer_mobile/core/analytics/analytics_service.dart';
import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/app/customer_navigation.dart';
import 'package:carcare_customer_mobile/app/customer_router.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/fake_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/onboarding/presentation/onboarding_gate.dart';
import 'package:carcare_customer_mobile/features/splash/presentation/splash_gate.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class CarCareCustomerApp extends StatefulWidget {
  /// Production entry point: every dependency comes from the composition root.
  CarCareCustomerApp.fromDependencies(AppDependencies dependencies, {Key? key})
    : this(
        organizationRepository: dependencies.organizationRepository,
        authRepository: dependencies.authRepository,
        appointmentRepository: dependencies.appointmentRepository,
        vehicleRepository: dependencies.vehicleRepository,
        historyRepository: dependencies.historyRepository,
        diagnosticsRepository: dependencies.diagnosticsRepository,
        notificationsRepository: dependencies.notificationsRepository,
        deviceRepository: dependencies.deviceRepository,
        remotePushService: dependencies.remotePushService,
        analytics: dependencies.analytics,
        connectivityService: dependencies.connectivityService,
        cacheStore: dependencies.cacheStore,
        key: key,
      );

  /// The Fake/Noop defaults below exist for widget tests only; production goes
  /// through [CarCareCustomerApp.fromDependencies] and passes everything.
  CarCareCustomerApp({
    required this.organizationRepository,
    AuthRepository? authRepository,
    AppointmentRepository? appointmentRepository,
    VehicleRepository? vehicleRepository,
    ServiceHistoryRepository? historyRepository,
    DiagnosticsRepository? diagnosticsRepository,
    NotificationsRepository? notificationsRepository,
    DeviceRepository? deviceRepository,
    RemotePushService? remotePushService,
    AnalyticsService? analytics,
    DeviceIdStore? deviceIdStore,
    ConnectivityService? connectivityService,
    CacheStore? cacheStore,
    super.key,
  }) : authRepository = authRepository ?? FakeAuthRepository(),
       appointmentRepository =
           appointmentRepository ?? FakeAppointmentRepository(),
       vehicleRepository = vehicleRepository ?? FakeVehicleRepository(),
       historyRepository = historyRepository ?? FakeServiceHistoryRepository(),
       diagnosticsRepository =
           diagnosticsRepository ?? FakeDiagnosticsRepository(),
       notificationsRepository =
           notificationsRepository ?? FakeNotificationsRepository(),
       deviceRepository = deviceRepository ?? FakeDeviceRepository(),
       remotePushService = remotePushService ?? const NoopRemotePushService(),
       analytics = analytics ?? const NoopAnalyticsService(),
       deviceIdStore = deviceIdStore ?? DeviceIdStore(),
       connectivityService =
           connectivityService ?? const NoopConnectivityService(),
       cacheStore = cacheStore ?? const NoopCacheStore();
  final OrganizationRepository organizationRepository;
  final AuthRepository authRepository;
  final AppointmentRepository appointmentRepository;
  final VehicleRepository vehicleRepository;
  final ServiceHistoryRepository historyRepository;
  final DiagnosticsRepository diagnosticsRepository;
  final NotificationsRepository notificationsRepository;
  final DeviceRepository deviceRepository;
  final RemotePushService remotePushService;
  final AnalyticsService analytics;
  final DeviceIdStore deviceIdStore;
  final ConnectivityService connectivityService;
  final CacheStore cacheStore;

  @override
  State<CarCareCustomerApp> createState() => _CarCareCustomerAppState();
}

class _CarCareCustomerAppState extends State<CarCareCustomerApp> {
  late final CustomerAppServices _services;
  late final CustomerNavigation _navigation;
  late final GoRouter _router;
  late final ThemeController _themeController;
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController()..addListener(_onThemeChanged);
    _themeController.load();
    _services = CustomerAppServices(
      organizationRepository: widget.organizationRepository,
      authRepository: widget.authRepository,
      appointmentRepository: widget.appointmentRepository,
      vehicleRepository: widget.vehicleRepository,
      historyRepository: widget.historyRepository,
      diagnosticsRepository: widget.diagnosticsRepository,
      notificationsRepository: widget.notificationsRepository,
      deviceRepository: widget.deviceRepository,
      remotePushService: widget.remotePushService,
      deviceIdStore: widget.deviceIdStore,
      connectivityService: widget.connectivityService,
      cacheStore: widget.cacheStore,
    );
    _services.showMessage = (m) =>
        _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(m)));
    _navigation = CustomerNavigation(_services);
    _router = buildCustomerRouter(_services, _navigation);
    _navigation.router = _router;
    _services.onNotificationTap = _navigation.openFromPush;
    // Local foreground banners route exactly like OS push taps.
    LocalPushService.instance.onTap = _services.push.handleTap;
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _themeController
      ..removeListener(_onThemeChanged)
      ..dispose();
    LocalPushService.instance.onTap = null;
    _router.dispose();
    _services.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: _themeController),
      ChangeNotifierProvider.value(value: _services.discoveryController),
      ChangeNotifierProvider.value(
        value: _services.organizationDetailController,
      ),
      ChangeNotifierProvider.value(value: _services.authController),
      ChangeNotifierProvider.value(value: _services.appointmentsController),
      ChangeNotifierProvider.value(value: _services.vehiclesController),
      ChangeNotifierProvider.value(value: _services.historyController),
      ChangeNotifierProvider.value(value: _services.notificationsController),
    ],
    child: MaterialApp.router(
      title: 'Carservice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeController.mode,
      scaffoldMessengerKey: _messengerKey,
      routerConfig: _router,
      builder: (context, child) => SplashGate(
        child: OnboardingGate(
          onRequestLogin: _navigation.requestLogin,
          analytics: widget.analytics,
          child: NetworkStatusStrip(
            isOnline: _services.isOnline,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}
