import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/config/app_environment.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/remote_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/remote_organization_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/remote_vehicle_repository.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final organizationRepository = AppEnvironment.useFakeApi
      ? FakeOrganizationRepository()
      : RemoteOrganizationRepository(
          ApiClient(baseUrl: AppEnvironment.apiBaseUrl),
        );
  final sessionStore = SecureSessionStore();
  final authRepository = AppEnvironment.useFakeApi
      ? FakeAuthRepository()
      : RemoteAuthRepository(
          ApiClient(baseUrl: AppEnvironment.apiBaseUrl),
          sessionStore,
        );
  final appointmentRepository = AppEnvironment.useFakeApi
      ? FakeAppointmentRepository()
      : RemoteAppointmentRepository(
          ApiClient(
            baseUrl: AppEnvironment.apiBaseUrl,
            accessTokenProvider: sessionStore.readToken,
            onUnauthorized: sessionStore.clear,
          ),
        );
  final vehicleRepository = AppEnvironment.useFakeApi
      ? FakeVehicleRepository()
      : RemoteVehicleRepository(
          ApiClient(
            baseUrl: AppEnvironment.apiBaseUrl,
            accessTokenProvider: sessionStore.readToken,
            onUnauthorized: sessionStore.clear,
          ),
        );
  runApp(
    CarCareCustomerApp(
      organizationRepository: organizationRepository,
      authRepository: authRepository,
      appointmentRepository: appointmentRepository,
      vehicleRepository: vehicleRepository,
    ),
  );
}
