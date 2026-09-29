import 'dart:async';

import 'package:carcare_customer_mobile/app/theme/app_theme.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/service_key_picker_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The fake catalog, but recording every filter it is asked for and letting
/// a test replace or hold individual responses.
class _RecordingRepository extends FakeOrganizationRepository {
  _RecordingRepository() : super(delay: Duration.zero);

  final List<OrganizationFilter> filters = [];

  /// When set, decides the response for a filter (null = fake catalog).
  Future<OrganizationPage>? Function(OrganizationFilter filter)? respond;

  @override
  Future<OrganizationPage> getOrganizations({
    OrganizationFilter? filter,
  }) async {
    final current = filter ?? const OrganizationFilter();
    filters.add(current);
    final custom = respond?.call(current);
    if (custom != null) return custom;
    return super.getOrganizations(filter: current);
  }
}

class _FakeLocation implements DeviceLocationService {
  _FakeLocation(this.location);
  final DeviceLocation? location;

  @override
  Future<DeviceLocation?> current() async => location;
}

OrganizationPage _page(List<Organization> organizations) => OrganizationPage(
  organizations: organizations,
  pagination: const OrganizationPagination(
    page: 1,
    pageSize: 200,
    total: 0,
    totalPages: 1,
    hasPrev: false,
    hasNext: false,
  ),
);

Future<void> _pump(
  WidgetTester tester,
  OrganizationRepository repository, {
  DeviceLocationService? location,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: ServiceKeyPickerScreen(
          repository: repository,
          onBranchSelected: (_, _, _) {},
          locationService: location ?? _FakeLocation(null),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Picks "Угаалга" (car-wash). In the fake catalog two branches offer it,
/// both in Улаанбаатар: auto-doctor-bzd (Баянзүрх) and auto-doctor-sbd
/// (Сүхбаатар).
Future<void> _pickCarWash(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('service-key-add')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('service-key-car-wash')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('service-key-apply')));
  await tester.pumpAndSettle();
}

Future<void> _openFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('service-key-filters')));
  await tester.pumpAndSettle();
}

Future<void> _closeFilters(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('service-key-filters-done')));
  await tester.pumpAndSettle();
}

Future<void> _choose(
  WidgetTester tester,
  String dropdownKey,
  String item,
) async {
  await tester.tap(find.byKey(ValueKey(dropdownKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

Finder _result(String id) => find.byKey(ValueKey('service-key-result-$id'));

void main() {
  testWidgets('the filter button only appears once a job is picked', (
    tester,
  ) async {
    await _pump(tester, _RecordingRepository());
    expect(find.byKey(const ValueKey('service-key-filters')), findsNothing);

    await _pickCarWash(tester);
    expect(find.byKey(const ValueKey('service-key-filters')), findsOneWidget);
    expect(_result('auto-doctor-bzd'), findsOneWidget);
    expect(_result('auto-doctor-sbd'), findsOneWidget);
  });

  testWidgets(
    'location options only offer places that can do the picked jobs, and '
    'changing the city clears the district',
    (tester) async {
      await _pump(tester, _RecordingRepository());
      await _pickCarWash(tester);
      await _openFilters(tester);

      // Орхон has a branch, but not one that does car-wash.
      await tester.tap(find.byKey(const ValueKey('branch-filter-city')));
      await tester.pumpAndSettle();
      expect(find.text('Улаанбаатар'), findsWidgets);
      expect(find.text('Орхон'), findsNothing);
      await tester.tap(find.text('Улаанбаатар').last);
      await tester.pumpAndSettle();

      // Хан-Уул only has a tire shop.
      await tester.tap(find.byKey(const ValueKey('branch-filter-district')));
      await tester.pumpAndSettle();
      expect(find.text('Хан-Уул'), findsNothing);
      await tester.tap(find.text('Сүхбаатар').last);
      await tester.pumpAndSettle();
      expect(find.text('1 салбар харуулах'), findsOneWidget);

      // Resetting the city resets the district too, back to both branches.
      await _choose(tester, 'branch-filter-city', 'Хот / аймаг');
      expect(find.text('2 салбар харуулах'), findsOneWidget);
      await _closeFilters(tester);
      expect(_result('auto-doctor-bzd'), findsOneWidget);
      expect(_result('auto-doctor-sbd'), findsOneWidget);
    },
  );

  testWidgets(
    'every active filter is sent together, the badge counts them, and '
    '"clear all" resets them in one request',
    (tester) async {
      final repository = _RecordingRepository();
      await _pump(tester, repository);
      await _pickCarWash(tester);
      await _openFilters(tester);

      await _choose(tester, 'branch-filter-city', 'Улаанбаатар');
      await _choose(tester, 'branch-filter-tag', 'Угаалгын газар');
      await tester.tap(find.byKey(const ValueKey('branch-filter-open-now')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('branch-filter-weekend')));
      await tester.pumpAndSettle();

      final combined = repository.filters.last;
      expect(combined.city, 'Улаанбаатар');
      expect(combined.tag, 'car-wash-tag');
      expect(combined.openNow, isTrue);
      expect(combined.weekend, isTrue);

      await _closeFilters(tester);
      expect(find.text('4'), findsOneWidget);

      await _openFilters(tester);
      final before = repository.filters.length;
      await tester.tap(find.byKey(const ValueKey('service-key-filters-clear')));
      await tester.pumpAndSettle();
      expect(repository.filters.length, before + 1);
      final cleared = repository.filters.last;
      expect(cleared.city, isEmpty);
      expect(cleared.tag, isEmpty);
      expect(cleared.openNow, isFalse);
      expect(cleared.weekend, isFalse);
      expect(
        find.byKey(const ValueKey('service-key-filters-clear')),
        findsNothing,
      );
    },
  );

  testWidgets('a slow, superseded response never overwrites a newer one', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    final slow = Completer<OrganizationPage>();
    repository.respond = (filter) => filter.openNow ? slow.future : null;
    await _pump(tester, repository);
    await _pickCarWash(tester);
    await _openFilters(tester);

    // On (held), then off again before the "on" response arrives.
    await tester.tap(find.byKey(const ValueKey('branch-filter-open-now')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('branch-filter-open-now')));
    await tester.pumpAndSettle();
    expect(find.text('2 салбар харуулах'), findsOneWidget);

    // The stale "open now" answer (nothing open) finally lands — ignored.
    slow.complete(_page(const []));
    await tester.pumpAndSettle();
    expect(find.text('2 салбар харуулах'), findsOneWidget);
    await _closeFilters(tester);
    expect(_result('auto-doctor-sbd'), findsOneWidget);
  });

  testWidgets('no matches under a filter offers to clear it, and the location '
      'options stay available meanwhile', (tester) async {
    final repository = _RecordingRepository();
    repository.respond = (filter) =>
        filter.weekend ? Future.value(_page(const [])) : null;
    await _pump(tester, repository);
    await _pickCarWash(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const ValueKey('branch-filter-weekend')));
    await tester.pumpAndSettle();

    // City options come from the unfiltered catalog, not the 0 results.
    expect(find.byKey(const ValueKey('branch-filter-city')), findsOneWidget);
    await _closeFilters(tester);

    expect(find.text('Шүүлтүүрт тохирох салбар алга'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('service-key-empty-clear-filters')),
    );
    await tester.pumpAndSettle();
    expect(_result('auto-doctor-bzd'), findsOneWidget);
    expect(repository.filters.last.weekend, isFalse);
  });

  testWidgets('near me sends the location and sorts nearest first', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    repository.respond = (filter) => filter.lat == null
        ? null
        : Future.value(
            _page(const [
              Organization(
                slug: 'auto-doctor',
                name: 'Auto Doctor Service',
                branches: [
                  Branch(
                    id: 'auto-doctor-bzd',
                    name: 'Баянзүрх салбар',
                    city: 'Улаанбаатар',
                    district: 'Баянзүрх',
                    distanceKm: 5.2,
                    serviceKeyIds: ['car-wash'],
                  ),
                  Branch(
                    id: 'auto-doctor-sbd',
                    name: 'Сүхбаатар салбар',
                    city: 'Улаанбаатар',
                    district: 'Сүхбаатар',
                    distanceKm: 0.8,
                    serviceKeyIds: ['car-wash'],
                  ),
                ],
              ),
            ]),
          );
    await _pump(
      tester,
      repository,
      location: _FakeLocation(const DeviceLocation(47.9, 106.9)),
    );
    await _pickCarWash(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const ValueKey('branch-filter-near-me')));
    await tester.pumpAndSettle();
    await _closeFilters(tester);

    expect(repository.filters.last.lat, 47.9);
    expect(repository.filters.last.lng, 106.9);
    final nearer = tester.getTopLeft(_result('auto-doctor-sbd')).dy;
    final farther = tester.getTopLeft(_result('auto-doctor-bzd')).dy;
    expect(nearer, lessThan(farther));
  });

  testWidgets('near me without a location reverts the chip and explains why', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository);
    await _pickCarWash(tester);
    await _openFilters(tester);
    await tester.tap(find.byKey(const ValueKey('branch-filter-near-me')));
    await tester.pumpAndSettle();

    final chip = tester.widget<FilterChip>(
      find.byKey(const ValueKey('branch-filter-near-me')),
    );
    expect(chip.selected, isFalse);
    expect(find.textContaining('Байршлыг авч чадсангүй'), findsOneWidget);
    expect(repository.filters.every((f) => f.lat == null), isTrue);
  });
}
