import 'package:carcare_customer_mobile/data/cache/cache_database.dart';
import 'package:carcare_customer_mobile/data/cache/drift_cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CacheDatabase db;
  late DriftCacheStore store;

  setUp(() {
    db = CacheDatabase.forTesting(NativeDatabase.memory());
    store = DriftCacheStore(db);
  });

  tearDown(() => db.close());

  group('organizations', () {
    test('round-trips nested branches and preserves order', () async {
      final input = [
        const Organization(
          slug: 'auto-doctor',
          name: 'Авто Доктор',
          logoUrl: 'https://example.test/logo.png',
          branches: [
            Branch(
              id: 'bzd',
              name: 'Баянзүрх салбар',
              city: 'Улаанбаатар',
              district: 'Баянзүрх',
              latitude: 47.9,
              longitude: 106.9,
            ),
            Branch(
              id: 'shd',
              name: 'Сүхбаатар салбар',
              city: 'Улаанбаатар',
              district: 'Сүхбаатар',
            ),
          ],
        ),
        const Organization(
          slug: 'khurd-motors',
          name: 'Хурд Моторс',
          branches: [],
        ),
      ];

      await store.writeOrganizations(input);
      final cached = await store.readOrganizations();

      expect(cached, hasLength(2));
      // Order preserved.
      expect(cached!.map((o) => o.slug), ['auto-doctor', 'khurd-motors']);
      final first = cached.first;
      expect(first.name, 'Авто Доктор');
      expect(first.logoUrl, 'https://example.test/logo.png');
      expect(first.branches, hasLength(2));
      expect(first.branches.first.district, 'Баянзүрх');
      expect(first.branches.first.latitude, 47.9);
      // Optional coordinates round-trip as null.
      expect(first.branches[1].latitude, isNull);
      // Optional logo round-trips as null.
      expect(cached[1].logoUrl, isNull);
      expect(cached[1].branches, isEmpty);
    });

    test('a later write replaces the whole collection', () async {
      await store.writeOrganizations(const [
        Organization(slug: 'a', name: 'A', branches: []),
        Organization(slug: 'b', name: 'B', branches: []),
      ]);
      await store.writeOrganizations(const [
        Organization(slug: 'c', name: 'C', branches: []),
      ]);

      final cached = await store.readOrganizations();
      expect(cached!.map((o) => o.slug), ['c']);
    });

    test('empty and cleared collections read back as null', () async {
      expect(await store.readOrganizations(), isNull);
      await store.writeOrganizations(const []);
      expect(await store.readOrganizations(), isNull);
      await store.writeOrganizations(const [
        Organization(slug: 'a', name: 'A', branches: []),
      ]);
      await store.clearOrganizations();
      expect(await store.readOrganizations(), isNull);
    });
  });

  test('vehicles round-trip with optional fields', () async {
    await store.writeVehicles(const [
      Vehicle(
        id: 'v1',
        plate: '9911УБЕ',
        make: 'Hyundai',
        model: 'Sonata',
        year: 2019,
        vin: 'VIN123',
      ),
      Vehicle(id: 'v2', plate: '0000УБА', make: 'Toyota', model: 'Prius'),
    ]);

    final cached = await store.readVehicles();
    expect(cached, hasLength(2));
    expect(cached!.first.year, 2019);
    expect(cached.first.vin, 'VIN123');
    expect(cached[1].year, isNull);
    expect(cached[1].vin, isNull);
  });

  test('appointments round-trip; unknown status degrades safely', () async {
    final now = DateTime.utc(2026, 9, 3, 10);
    await store.writeAppointments([
      Appointment(
        id: 'a1',
        status: AppointmentStatus.pending,
        requestedAt: now,
        tenantName: 'Инфосистемс',
        tenantSlug: 'infosystems',
        branchName: 'Үндсэн салбар',
        note: 'дугуй',
        vehiclePlate: '9911УБЕ',
      ),
    ]);

    final cached = await store.readAppointments();
    expect(cached, hasLength(1));
    final a = cached!.single;
    expect(a.status, AppointmentStatus.pending);
    expect(a.requestedAt, now);
    expect(a.note, 'дугуй');
    expect(a.categoryName, isNull);
    // The booking-fee payment is intentionally not cached.
    expect(a.payment, isNull);
  });

  test('service orders round-trip sorted order and amounts', () async {
    await store.writeServiceOrders([
      ServiceOrder(
        id: 'o1',
        tenantName: 'Инфосистемс',
        tenantSlug: 'infosystems',
        branchName: 'Үндсэн салбар',
        completedAt: DateTime.utc(2026, 8, 1),
        status: ServiceOrderStatus.paid,
        totalAmount: 150000,
        paidAmount: 150000,
        vehiclePlate: '9911УБЕ',
      ),
      ServiceOrder(
        id: 'o2',
        tenantName: 'Хурд',
        tenantSlug: 'khurd',
        branchName: 'Салбар',
        completedAt: DateTime.utc(2026, 7, 1),
        status: ServiceOrderStatus.unpaid,
        totalAmount: 80000,
        paidAmount: 0,
      ),
    ]);

    final cached = await store.readServiceOrders();
    expect(cached!.map((o) => o.id), ['o1', 'o2']);
    expect(cached.first.status, ServiceOrderStatus.paid);
    expect(cached.first.totalAmount, 150000);
    expect(cached[1].vehiclePlate, isNull);
  });

  test('organization detail round-trips with a timestamp', () async {
    const detail = OrganizationDetail(
      slug: 'auto-doctor',
      name: 'Auto Doctor',
      logoUrl: 'https://example.test/logo.png',
      phone: '7700 1122',
      branches: [
        BranchDetail(
          id: 'b1',
          name: 'Баянзүрх салбар',
          city: 'Улаанбаатар',
          district: 'Баянзүрх',
          khoroo: '26-р хороо',
          address: 'Нарны зам 18',
          latitude: 47.9187,
          longitude: 106.9684,
          openTime: '09:00',
          closeTime: '19:00',
        ),
      ],
    );

    await store.writeOrganizationDetail(detail);
    final cached = await store.readOrganizationDetail('auto-doctor');

    expect(cached, isNotNull);
    expect(cached!.detail.phone, '7700 1122');
    final branch = cached.detail.branches.single;
    expect(branch.fullAddress, '26-р хороо, Нарны зам 18');
    expect(branch.hoursLabel, '09:00–19:00');
    expect(branch.latitude, 47.9187);
    expect(
      DateTime.now().difference(cached.cachedAt) < const Duration(minutes: 1),
      isTrue,
    );
    expect(await store.readOrganizationDetail('unknown-slug'), isNull);
  });
}
