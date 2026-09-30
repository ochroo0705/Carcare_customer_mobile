import 'package:carcare_customer_mobile/core/analytics/analytics_service.dart';
import 'package:carcare_customer_mobile/core/config/app_environment.dart';
import 'package:carcare_customer_mobile/core/connectivity/connectivity_service.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/remote_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/remote_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/fake_device_repository.dart';
import 'package:carcare_customer_mobile/features/devices/data/remote_device_repository.dart';
import 'package:carcare_customer_mobile/features/devices/domain/device_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/fake_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/data/remote_diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/diagnostics/domain/diagnostics_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/caching_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/data/remote_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/remote_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/fake_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/data/remote_notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/remote_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';

/// Builds an [ApiClient]. Authenticated clients attach the session token and
/// clear the session on a 401; unauthenticated ones send no `Authorization`.
/// Injectable so tests can observe what the composition root creates.
typedef ApiClientFactory = ApiClient Function({required bool authenticated});

/// The composition root: every repository and service the app runs on, built
/// in one place. The fake-vs-remote decision lives here (and only here).
class AppDependencies {
  const AppDependencies({
    required this.organizationRepository,
    required this.authRepository,
    required this.appointmentRepository,
    required this.vehicleRepository,
    required this.historyRepository,
    required this.diagnosticsRepository,
    required this.notificationsRepository,
    required this.deviceRepository,
    required this.remotePushService,
    required this.analytics,
    required this.connectivityService,
    required this.cacheStore,
  });

  /// Picks [AppDependencies.fake] or [AppDependencies.remote] from
  /// `USE_FAKE_API`, so every feature switches together (never one feature
  /// fake and another remote).
  factory AppDependencies.build({
    required CacheStore cacheStore,
    required RemotePushService remotePushService,
    required AnalyticsService analytics,
    SecureSessionStore? sessionStore,
    ConnectivityService? connectivityService,
    String baseUrl = AppEnvironment.apiBaseUrl,
    bool useFakeApi = AppEnvironment.useFakeApi,
    ApiClientFactory? clientFactory,
  }) {
    final connectivity =
        connectivityService ??
        PlatformConnectivityService(probe: ApiReachabilityProbe(baseUrl).call);
    return useFakeApi
        ? AppDependencies.fake(
            cacheStore: cacheStore,
            remotePushService: remotePushService,
            analytics: analytics,
            connectivityService: connectivity,
          )
        : AppDependencies.remote(
            cacheStore: cacheStore,
            remotePushService: remotePushService,
            analytics: analytics,
            connectivityService: connectivity,
            sessionStore: sessionStore ?? SecureSessionStore(),
            baseUrl: baseUrl,
            clientFactory: clientFactory,
          );
  }

  /// Seed-data repositories for `USE_FAKE_API` builds.
  factory AppDependencies.fake({
    required CacheStore cacheStore,
    required RemotePushService remotePushService,
    required AnalyticsService analytics,
    required ConnectivityService connectivityService,
  }) => AppDependencies(
    organizationRepository: CachingOrganizationRepository(
      FakeOrganizationRepository(),
      cacheStore,
    ),
    authRepository: FakeAuthRepository(),
    appointmentRepository: FakeAppointmentRepository(),
    vehicleRepository: FakeVehicleRepository(),
    historyRepository: FakeServiceHistoryRepository(),
    diagnosticsRepository: FakeDiagnosticsRepository(),
    notificationsRepository: FakeNotificationsRepository(),
    deviceRepository: FakeDeviceRepository(),
    remotePushService: remotePushService,
    analytics: analytics,
    connectivityService: connectivityService,
    cacheStore: cacheStore,
  );

  /// Real-API repositories. One authenticated [ApiClient] serves every
  /// repository that needs the session token (auth's account-closure calls
  /// included; its public OTP calls simply send no header while signed out),
  /// and one unauthenticated client serves the public organization endpoints.
  factory AppDependencies.remote({
    required CacheStore cacheStore,
    required RemotePushService remotePushService,
    required AnalyticsService analytics,
    required ConnectivityService connectivityService,
    required SecureSessionStore sessionStore,
    String baseUrl = AppEnvironment.apiBaseUrl,
    ApiClientFactory? clientFactory,
  }) {
    final make =
        clientFactory ??
        ({required bool authenticated}) => authenticated
            ? ApiClient(
                baseUrl: baseUrl,
                accessTokenProvider: sessionStore.readToken,
                onUnauthorized: sessionStore.clear,
              )
            : ApiClient(baseUrl: baseUrl);
    final authed = make(authenticated: true);
    final public = make(authenticated: false);
    return AppDependencies(
      // Cache-first-with-TTL for org detail (hours/address/phone) - served from
      // the local DB when recently seen, so the appointment detail's location
      // card and the discovery detail page skip a round-trip and work offline.
      organizationRepository: CachingOrganizationRepository(
        RemoteOrganizationRepository(public),
        cacheStore,
      ),
      authRepository: RemoteAuthRepository(authed, sessionStore),
      appointmentRepository: RemoteAppointmentRepository(authed),
      vehicleRepository: RemoteVehicleRepository(authed),
      // History has a real /api/v1/app/orders endpoint (web commit 79f0e9e).
      historyRepository: RemoteServiceHistoryRepository(authed),
      diagnosticsRepository: RemoteDiagnosticsRepository(authed),
      // Notifications are served by /api/v1/app/notifications (D-014
      // superseded). UnavailableNotificationsRepository is kept, unwired, for
      // a build that has to point at a server predating those routes.
      notificationsRepository: RemoteNotificationsRepository(authed),
      deviceRepository: RemoteDeviceRepository(authed),
      remotePushService: remotePushService,
      analytics: analytics,
      connectivityService: connectivityService,
      cacheStore: cacheStore,
    );
  }

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
  final ConnectivityService connectivityService;
  final CacheStore cacheStore;
}
