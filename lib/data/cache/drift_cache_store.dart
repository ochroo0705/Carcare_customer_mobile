import 'dart:convert';

import 'package:carcare_customer_mobile/data/cache/cache_database.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:drift/drift.dart';

/// Drift-backed [CacheStore]. Every write replaces the whole collection inside a
/// transaction (delete-all then bulk insert), so a cached list always reflects
/// exactly the last successful fetch. All operations are wrapped so a storage
/// failure degrades to "no cache" rather than propagating.
class DriftCacheStore implements CacheStore {
  DriftCacheStore(this._db);

  final CacheDatabase _db;

  // --- Organizations -------------------------------------------------------

  @override
  Future<List<Organization>?> readOrganizations() async {
    try {
      final rows =
          await (_db.select(_db.cachedOrganizations)
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      if (rows.isEmpty) return null;
      return rows.map(_organizationFromRow).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeOrganizations(List<Organization> organizations) async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.cachedOrganizations).go();
        final now = DateTime.now();
        await _db.batch((batch) {
          batch.insertAll(_db.cachedOrganizations, [
            for (var i = 0; i < organizations.length; i++)
              _organizationToCompanion(organizations[i], i, now),
          ]);
        });
      });
    } catch (_) {
      // Best-effort — a write failure must never surface as a load failure.
    }
  }

  @override
  Future<void> clearOrganizations() => _clear(_db.cachedOrganizations);

  // --- Vehicles ------------------------------------------------------------

  @override
  Future<List<Vehicle>?> readVehicles() async {
    try {
      final rows =
          await (_db.select(_db.cachedVehicles)
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      if (rows.isEmpty) return null;
      return rows.map(_vehicleFromRow).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeVehicles(List<Vehicle> vehicles) async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.cachedVehicles).go();
        final now = DateTime.now();
        await _db.batch((batch) {
          batch.insertAll(_db.cachedVehicles, [
            for (var i = 0; i < vehicles.length; i++)
              _vehicleToCompanion(vehicles[i], i, now),
          ]);
        });
      });
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> clearVehicles() => _clear(_db.cachedVehicles);

  // --- Appointments --------------------------------------------------------

  @override
  Future<List<Appointment>?> readAppointments() async {
    try {
      final rows =
          await (_db.select(_db.cachedAppointments)
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      if (rows.isEmpty) return null;
      return rows.map(_appointmentFromRow).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeAppointments(List<Appointment> appointments) async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.cachedAppointments).go();
        final now = DateTime.now();
        await _db.batch((batch) {
          batch.insertAll(_db.cachedAppointments, [
            for (var i = 0; i < appointments.length; i++)
              _appointmentToCompanion(appointments[i], i, now),
          ]);
        });
      });
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> clearAppointments() => _clear(_db.cachedAppointments);

  // --- Service history -----------------------------------------------------

  @override
  Future<List<ServiceOrder>?> readServiceOrders() async {
    try {
      final rows =
          await (_db.select(_db.cachedServiceOrders)
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      if (rows.isEmpty) return null;
      return rows.map(_serviceOrderFromRow).toList(growable: false);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeServiceOrders(List<ServiceOrder> orders) async {
    try {
      await _db.transaction(() async {
        await _db.delete(_db.cachedServiceOrders).go();
        final now = DateTime.now();
        await _db.batch((batch) {
          batch.insertAll(_db.cachedServiceOrders, [
            for (var i = 0; i < orders.length; i++)
              _serviceOrderToCompanion(orders[i], i, now),
          ]);
        });
      });
    } catch (_) {
      // Best-effort.
    }
  }

  @override
  Future<void> clearServiceOrders() => _clear(_db.cachedServiceOrders);

  // --- Helpers -------------------------------------------------------------

  Future<void> _clear(TableInfo<Table, dynamic> table) async {
    try {
      await _db.delete(table).go();
    } catch (_) {
      // Best-effort.
    }
  }
}

// --- Organization <-> row ---------------------------------------------------

CachedOrganizationsCompanion _organizationToCompanion(
  Organization organization,
  int position,
  DateTime cachedAt,
) {
  final branches = organization.branches
      .map(
        (branch) => <String, dynamic>{
          'id': branch.id,
          'name': branch.name,
          'city': branch.city,
          'district': branch.district,
          'latitude': branch.latitude,
          'longitude': branch.longitude,
        },
      )
      .toList();
  return CachedOrganizationsCompanion.insert(
    position: position,
    slug: organization.slug,
    name: organization.name,
    logoUrl: Value(organization.logoUrl),
    branchesJson: jsonEncode(branches),
    cachedAt: cachedAt,
  );
}

Organization _organizationFromRow(CachedOrganizationRow row) {
  final decoded = jsonDecode(row.branchesJson);
  final branches = <Branch>[];
  if (decoded is List) {
    for (final entry in decoded) {
      if (entry is! Map) continue;
      final id = entry['id'];
      final name = entry['name'];
      final city = entry['city'];
      final district = entry['district'];
      if (id is! String ||
          name is! String ||
          city is! String ||
          district is! String) {
        continue;
      }
      branches.add(
        Branch(
          id: id,
          name: name,
          city: city,
          district: district,
          latitude: entry['latitude'] is num
              ? (entry['latitude'] as num).toDouble()
              : null,
          longitude: entry['longitude'] is num
              ? (entry['longitude'] as num).toDouble()
              : null,
        ),
      );
    }
  }
  return Organization(
    slug: row.slug,
    name: row.name,
    logoUrl: row.logoUrl,
    branches: branches,
  );
}

// --- Vehicle <-> row --------------------------------------------------------

CachedVehiclesCompanion _vehicleToCompanion(
  Vehicle vehicle,
  int position,
  DateTime cachedAt,
) => CachedVehiclesCompanion.insert(
  position: position,
  id: vehicle.id,
  plate: vehicle.plate,
  make: vehicle.make,
  model: vehicle.model,
  year: Value(vehicle.year),
  vin: Value(vehicle.vin),
  cachedAt: cachedAt,
);

Vehicle _vehicleFromRow(CachedVehicleRow row) => Vehicle(
  id: row.id,
  plate: row.plate,
  make: row.make,
  model: row.model,
  year: row.year,
  vin: row.vin,
);

// --- Appointment <-> row ----------------------------------------------------
// Note: the booking-fee `payment` is intentionally not cached (it never was),
// so a cached appointment round-trips with `payment == null`.

CachedAppointmentsCompanion _appointmentToCompanion(
  Appointment appointment,
  int position,
  DateTime cachedAt,
) => CachedAppointmentsCompanion.insert(
  position: position,
  id: appointment.id,
  status: appointment.status.name,
  requestedAt: appointment.requestedAt.toIso8601String(),
  tenantName: appointment.tenantName,
  tenantSlug: appointment.tenantSlug,
  branchName: appointment.branchName,
  note: Value(appointment.note),
  categoryName: Value(appointment.categoryName),
  vehiclePlate: Value(appointment.vehiclePlate),
  cachedAt: cachedAt,
);

Appointment _appointmentFromRow(CachedAppointmentRow row) => Appointment(
  id: row.id,
  status: AppointmentStatus.values.firstWhere(
    (status) => status.name == row.status,
    orElse: () => AppointmentStatus.unknown,
  ),
  requestedAt: DateTime.parse(row.requestedAt),
  tenantName: row.tenantName,
  tenantSlug: row.tenantSlug,
  branchName: row.branchName,
  note: row.note,
  categoryName: row.categoryName,
  vehiclePlate: row.vehiclePlate,
);

// --- ServiceOrder <-> row ---------------------------------------------------

CachedServiceOrdersCompanion _serviceOrderToCompanion(
  ServiceOrder order,
  int position,
  DateTime cachedAt,
) => CachedServiceOrdersCompanion.insert(
  position: position,
  id: order.id,
  tenantName: order.tenantName,
  tenantSlug: order.tenantSlug,
  branchName: order.branchName,
  completedAt: order.completedAt.toIso8601String(),
  status: order.status.name,
  totalAmount: order.totalAmount,
  paidAmount: order.paidAmount,
  vehiclePlate: Value(order.vehiclePlate),
  cachedAt: cachedAt,
);

ServiceOrder _serviceOrderFromRow(CachedServiceOrderRow row) => ServiceOrder(
  id: row.id,
  tenantName: row.tenantName,
  tenantSlug: row.tenantSlug,
  branchName: row.branchName,
  completedAt: DateTime.parse(row.completedAt),
  status: ServiceOrderStatus.values.firstWhere(
    (status) => status.name == row.status,
    orElse: () => ServiceOrderStatus.unpaid,
  ),
  totalAmount: row.totalAmount,
  paidAmount: row.paidAmount,
  vehiclePlate: row.vehiclePlate,
);
