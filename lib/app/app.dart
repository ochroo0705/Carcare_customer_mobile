import 'package:carcare_customer_mobile/app/router.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/device_id_store.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:flutter/material.dart';

class CarCareCustomerApp extends StatefulWidget {
  CarCareCustomerApp({
    required this.organizationRepository,
    AuthRepository? authRepository,
    AppointmentRepository? appointmentRepository,
    VehicleRepository? vehicleRepository,
    ServiceHistoryRepository? historyRepository,
    NotificationsRepository? notificationsRepository,
    DeviceRepository? deviceRepository,
    RemotePushService? remotePushService,
    DeviceIdStore? deviceIdStore,
    super.key,
  }) : authRepository = authRepository ?? FakeAuthRepository(),
       appointmentRepository =
           appointmentRepository ?? FakeAppointmentRepository(),
       vehicleRepository = vehicleRepository ?? FakeVehicleRepository(),
       historyRepository = historyRepository ?? FakeServiceHistoryRepository(),
       notificationsRepository =
           notificationsRepository ?? FakeNotificationsRepository(),
       deviceRepository = deviceRepository ?? FakeDeviceRepository(),
       remotePushService = remotePushService ?? const NoopRemotePushService(),
       deviceIdStore = deviceIdStore ?? DeviceIdStore();
  final OrganizationRepository organizationRepository;
  final AuthRepository authRepository;
  final AppointmentRepository appointmentRepository;
  final VehicleRepository vehicleRepository;
  final ServiceHistoryRepository historyRepository;
  final NotificationsRepository notificationsRepository;
  final DeviceRepository deviceRepository;
  final RemotePushService remotePushService;
  final DeviceIdStore deviceIdStore;

  @override
  State<CarCareCustomerApp> createState() => _CarCareCustomerAppState();
}

class _CarCareCustomerAppState extends State<CarCareCustomerApp> {
  late final CustomerRouterDelegate _routerDelegate;
  late final ThemeController _themeController;
  final _parser = CustomerRouteInformationParser();

  @override
  void initState() {
    super.initState();
    _themeController = ThemeController()..addListener(_onThemeChanged);
    _themeController.load();
    _routerDelegate = CustomerRouterDelegate(
      widget.organizationRepository,
      _themeController,
      widget.authRepository,
      widget.appointmentRepository,
      widget.vehicleRepository,
      widget.historyRepository,
      widget.notificationsRepository,
      widget.deviceRepository,
      widget.remotePushService,
      widget.deviceIdStore,
    );
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    _themeController
      ..removeListener(_onThemeChanged)
      ..dispose();
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'CarCare',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: _themeController.mode,
    routerDelegate: _routerDelegate,
    routeInformationParser: _parser,
  );
}
