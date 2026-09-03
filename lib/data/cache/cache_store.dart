import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';

/// A cached organization detail plus when it was stored, so a reader can decide
/// whether it is still fresh (see `CachingOrganizationRepository`).
typedef CachedOrganizationDetail = ({
  OrganizationDetail detail,
  DateTime cachedAt,
});

/// Persistence port for the offline read cache. Each `read*` returns the last
/// successfully-cached list, or `null` when nothing usable is stored (an empty
/// collection reads back as `null`, matching the original SharedPreferences
/// behaviour where an empty cache was treated as no cache). `write*` replaces
/// the whole collection; `clear*` drops it (e.g. on sign-out).
///
/// Reads and writes are best-effort: an implementation must swallow storage
/// errors and never let a cache failure surface as a load failure.
abstract interface class CacheStore {
  Future<List<Organization>?> readOrganizations();
  Future<void> writeOrganizations(List<Organization> organizations);
  Future<void> clearOrganizations();

  Future<List<Vehicle>?> readVehicles();
  Future<void> writeVehicles(List<Vehicle> vehicles);
  Future<void> clearVehicles();

  Future<List<Appointment>?> readAppointments();
  Future<void> writeAppointments(List<Appointment> appointments);
  Future<void> clearAppointments();

  Future<List<ServiceOrder>?> readServiceOrders();
  Future<void> writeServiceOrders(List<ServiceOrder> orders);
  Future<void> clearServiceOrders();

  /// Full organization detail (hours/address/phone), keyed by slug. Unlike the
  /// collection reads above, this is a per-org upsert with a timestamp — the
  /// caller decides freshness. Returns `null` when nothing is stored.
  Future<CachedOrganizationDetail?> readOrganizationDetail(String slug);
  Future<void> writeOrganizationDetail(OrganizationDetail detail);
}

/// A cache that stores nothing. Used as the default when a controller is
/// constructed without a cache (e.g. in unit tests that don't exercise the
/// offline path), so caching is opt-in rather than mandatory.
class NoopCacheStore implements CacheStore {
  const NoopCacheStore();

  @override
  Future<List<Organization>?> readOrganizations() async => null;
  @override
  Future<void> writeOrganizations(List<Organization> organizations) async {}
  @override
  Future<void> clearOrganizations() async {}

  @override
  Future<List<Vehicle>?> readVehicles() async => null;
  @override
  Future<void> writeVehicles(List<Vehicle> vehicles) async {}
  @override
  Future<void> clearVehicles() async {}

  @override
  Future<List<Appointment>?> readAppointments() async => null;
  @override
  Future<void> writeAppointments(List<Appointment> appointments) async {}
  @override
  Future<void> clearAppointments() async {}

  @override
  Future<List<ServiceOrder>?> readServiceOrders() async => null;
  @override
  Future<void> writeServiceOrders(List<ServiceOrder> orders) async {}
  @override
  Future<void> clearServiceOrders() async {}

  @override
  Future<CachedOrganizationDetail?> readOrganizationDetail(String slug) async =>
      null;
  @override
  Future<void> writeOrganizationDetail(OrganizationDetail detail) async {}
}
