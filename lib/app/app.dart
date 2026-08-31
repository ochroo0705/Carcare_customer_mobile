import 'package:carcare_customer_mobile/app/router.dart';
import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:flutter/material.dart';

class CarCareCustomerApp extends StatefulWidget {
  const CarCareCustomerApp({
    required this.organizationRepository,
    required this.serviceRepository,
    super.key,
  });
  final OrganizationRepository organizationRepository;
  final ServiceRepository serviceRepository;

  @override
  State<CarCareCustomerApp> createState() => _CarCareCustomerAppState();
}

class _CarCareCustomerAppState extends State<CarCareCustomerApp> {
  late final CustomerRouterDelegate _routerDelegate;
  final _parser = CustomerRouteInformationParser();

  @override
  void initState() {
    super.initState();
    _routerDelegate = CustomerRouterDelegate(
      widget.organizationRepository,
      widget.serviceRepository,
    );
  }

  @override
  void dispose() {
    _routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'CarCare',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.system,
    routerDelegate: _routerDelegate,
    routeInformationParser: _parser,
  );
}
