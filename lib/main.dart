import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_service_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    CarCareCustomerApp(
      organizationRepository: FakeOrganizationRepository(),
      serviceRepository: FakeServiceRepository(),
    ),
  );
}
