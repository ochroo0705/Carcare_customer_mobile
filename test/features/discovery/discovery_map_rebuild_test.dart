import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/discovery_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/widgets/discovery_map.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_page.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../support/mocks.dart';

const _mapChannel = MethodChannel(
  'mn.carcare.carcare_customer_mobile/map_configuration',
);

OrganizationMapMarker _marker(String id, double lat) => OrganizationMapMarker(
  id: id,
  orgSlug: 'org-$id',
  orgName: 'Org $id',
  branchName: 'Branch $id',
  latitude: lat,
  longitude: 106.9,
);

/// Catalogue from the fake repository; map markers come from [markers].
class _MapRepo extends Fake implements OrganizationRepository {
  final _inner = FakeOrganizationRepository(delay: Duration.zero);
  List<OrganizationMapMarker> markers = [_marker('a', 47.9)];

  @override
  Future<OrganizationPage> getOrganizations({OrganizationFilter? filter}) =>
      _inner.getOrganizations(filter: filter);

  @override
  Future<OrganizationMapPage> getMapMarkers({
    required MapViewport viewport,
    OrganizationFilter? filter,
  }) async => OrganizationMapPage(
    markers: markers,
    count: markers.length,
    truncated: false,
    max: 500,
  );

  @override
  Future<List<BranchTagOption>> getBranchTags() async => const [];

  @override
  Future<List<ServiceKey>> getServiceKeys() async => const [];
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(
          _mapChannel,
          (call) async => call.method == 'isConfigured' ? false : null,
        );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger
        .setMockMethodCallHandler(_mapChannel, null);
  });

  Future<
    ({
      DiscoveryController discovery,
      NotificationsController notifications,
      _MapRepo repo,
      MockNotificationsRepository notificationsRepo,
    })
  >
  pumpScreen(WidgetTester tester) async {
    final repo = _MapRepo();
    final discovery = DiscoveryController(repo);
    final detail = OrganizationDetailController(repo);
    final auth = MockAuthRepository();
    when(() => auth.onSessionInvalidated)
        .thenAnswer((_) => const Stream.empty());
    final authController = AuthController(auth)..account = testAccount;
    final notificationsRepo = MockNotificationsRepository();
    var unread = 0;
    when(() => notificationsRepo.getNotifications()).thenAnswer(
      (_) async => NotificationsPage(items: const [], unreadCount: unread),
    );
    final notifications = NotificationsController(notificationsRepo);
    addTearDown(() {
      discovery.dispose();
      detail.dispose();
      authController.dispose();
      notifications.dispose();
    });
    await discovery.load();
    discovery.requestMapMarkers(
      const MapViewport(north: 48, south: 47.8, east: 107, west: 106.8),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: discovery),
          ChangeNotifierProvider.value(value: detail),
          ChangeNotifierProvider.value(value: authController),
          ChangeNotifierProvider.value(value: notifications),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: DiscoveryScreen(
              onBranchSelected: (_, _) {},
              onNotificationsRequested: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();
    // Stash the unread value the next `load()` should report.
    when(() => notificationsRepo.getNotifications()).thenAnswer(
      (_) async => NotificationsPage(items: const [], unreadCount: unread),
    );
    return (
      discovery: discovery,
      notifications: notifications,
      repo: repo,
      notificationsRepo: notificationsRepo,
    );
  }

  testWidgets('an unread-count change does not rebuild the map', (
    tester,
  ) async {
    final h = await pumpScreen(tester);
    final before = tester.widget<DiscoveryMap>(find.byType(DiscoveryMap));
    expect(before.organizations, isNotEmpty);

    when(() => h.notificationsRepo.getNotifications()).thenAnswer(
      (_) async => const NotificationsPage(items: [], unreadCount: 3),
    );
    await h.notifications.load();
    await tester.pumpAndSettle();

    // The bell badge picked the new count up...
    expect(find.text('3'), findsOneWidget);
    // ...without the screen handing the map a new widget (a new widget would
    // rebuild it and re-derive every marker).
    final after = tester.widget<DiscoveryMap>(find.byType(DiscoveryMap));
    expect(identical(before, after), isTrue);
  });

  testWidgets('markers recompute when mapMarkers changes', (tester) async {
    final h = await pumpScreen(tester);
    final before = tester.widget<DiscoveryMap>(find.byType(DiscoveryMap));
    expect(before.organizations.map((o) => o.slug), ['org-a']);

    h.repo.markers = [_marker('b', 47.95), _marker('c', 47.96)];
    h.discovery.requestMapMarkers(
      const MapViewport(north: 60, south: 30, east: 120, west: 90),
      force: true,
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final after = tester.widget<DiscoveryMap>(find.byType(DiscoveryMap));
    expect(after.organizations.map((o) => o.slug), ['org-b', 'org-c']);
  });
}
