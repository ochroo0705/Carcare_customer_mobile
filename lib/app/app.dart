import 'package:carcare_customer_mobile/app/router.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/app/theme/theme_controller.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:flutter/material.dart';

class CarCareCustomerApp extends StatefulWidget {
  CarCareCustomerApp({
    required this.organizationRepository,
    required this.serviceRepository,
    AuthRepository? authRepository,
    AppointmentRepository? appointmentRepository,
    super.key,
  }) : authRepository = authRepository ?? FakeAuthRepository(),
       appointmentRepository =
           appointmentRepository ?? FakeAppointmentRepository();
  final OrganizationRepository organizationRepository;
  final ServiceRepository serviceRepository;
  final AuthRepository authRepository;
  final AppointmentRepository appointmentRepository;

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
      widget.serviceRepository,
      _themeController,
      widget.authRepository,
      widget.appointmentRepository,
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
