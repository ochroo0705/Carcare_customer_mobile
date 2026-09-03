import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';

/// Pure-Dart [CacheStore] that keeps collections in memory. Lets unit tests
/// exercise the offline-cache fallback (persistence across controller
/// instances that share one store) without a native sqlite dependency in the
/// `flutter test` VM. Empty collections read back as `null`, matching
/// [DriftCacheStore] and the original SharedPreferences behaviour.
class InMemoryCacheStore implements CacheStore {
  List<Organization>? _organizations;
  List<Vehicle>? _vehicles;
  List<Appointment>? _appointments;
  List<ServiceOrder>? _serviceOrders;

  static List<T>? _readable<T>(List<T>? stored) =>
      (stored == null || stored.isEmpty) ? null : List<T>.unmodifiable(stored);

  @override
  Future<List<Organization>?> readOrganizations() async =>
      _readable(_organizations);
  @override
  Future<void> writeOrganizations(List<Organization> organizations) async =>
      _organizations = List.of(organizations);
  @override
  Future<void> clearOrganizations() async => _organizations = null;

  @override
  Future<List<Vehicle>?> readVehicles() async => _readable(_vehicles);
  @override
  Future<void> writeVehicles(List<Vehicle> vehicles) async =>
      _vehicles = List.of(vehicles);
  @override
  Future<void> clearVehicles() async => _vehicles = null;

  @override
  Future<List<Appointment>?> readAppointments() async =>
      _readable(_appointments);
  @override
  Future<void> writeAppointments(List<Appointment> appointments) async =>
      _appointments = List.of(appointments);
  @override
  Future<void> clearAppointments() async => _appointments = null;

  @override
  Future<List<ServiceOrder>?> readServiceOrders() async =>
      _readable(_serviceOrders);
  @override
  Future<void> writeServiceOrders(List<ServiceOrder> orders) async =>
      _serviceOrders = List.of(orders);
  @override
  Future<void> clearServiceOrders() async => _serviceOrders = null;
}
