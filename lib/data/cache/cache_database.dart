import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'cache_database.g.dart';

/// On-disk offline read cache for the discovery, vehicles, appointments and
/// service-history lists. This is a *cache*, never a source of truth: every
/// row is a denormalized copy of a domain object last fetched from the API, so
/// each successful `load()` replaces the whole collection. Nested data that no
/// screen filters on server-side (a branch list) is stored as a JSON column
/// rather than a child table — the controllers already filter/sort in memory.
///
/// `position` preserves the exact list order the controller saved, so a cached
/// list reconstructs byte-identically to what was shown online. `cachedAt` is
/// unused today but gives a future TTL/eviction pass something to key on.
@DataClassName('CachedOrganizationRow')
class CachedOrganizations extends Table {
  IntColumn get position => integer()();
  TextColumn get slug => text()();
  TextColumn get name => text()();
  TextColumn get logoUrl => text().nullable()();

  /// JSON array of branches: `{id, name, city, district, latitude?, longitude?}`.
  TextColumn get branchesJson => text()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {slug};
}

@DataClassName('CachedVehicleRow')
class CachedVehicles extends Table {
  IntColumn get position => integer()();
  TextColumn get id => text()();
  TextColumn get plate => text()();
  TextColumn get make => text()();
  TextColumn get model => text()();
  IntColumn get year => integer().nullable()();
  TextColumn get vin => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CachedAppointmentRow')
class CachedAppointments extends Table {
  IntColumn get position => integer()();
  TextColumn get id => text()();
  TextColumn get status => text()();

  /// ISO-8601 string, stored verbatim so the DateTime round-trips with its
  /// UTC/local flag intact — the appointments screen formats `requestedAt`'s
  /// raw fields without `toLocal()`, so a UTC-origin value must not silently
  /// become local (which Drift's default int DateTime storage would do).
  TextColumn get requestedAt => text()();
  TextColumn get tenantName => text()();
  TextColumn get tenantSlug => text()();
  TextColumn get branchName => text()();
  TextColumn get note => text().nullable()();
  TextColumn get categoryName => text().nullable()();
  TextColumn get vehiclePlate => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CachedServiceOrderRow')
class CachedServiceOrders extends Table {
  IntColumn get position => integer()();
  TextColumn get id => text()();
  TextColumn get tenantName => text()();
  TextColumn get tenantSlug => text()();
  TextColumn get branchName => text()();

  /// ISO-8601 string — see the note on [CachedAppointments.requestedAt]. The
  /// history screen formats `completedAt`'s raw fields too.
  TextColumn get completedAt => text()();
  TextColumn get status => text()();
  IntColumn get totalAmount => integer()();
  IntColumn get paidAmount => integer()();
  TextColumn get vehiclePlate => text().nullable()();
  DateTimeColumn get cachedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    CachedOrganizations,
    CachedVehicles,
    CachedAppointments,
    CachedServiceOrders,
  ],
)
class CacheDatabase extends _$CacheDatabase {
  CacheDatabase() : super(driftDatabase(name: 'carcare_cache'));

  /// For tests: pass a `NativeDatabase.memory()` executor.
  CacheDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;
}
