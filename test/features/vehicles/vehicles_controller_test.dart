import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/in_memory_cache_store.dart';
import 'package:carcare_customer_mobile/features/vehicles/data/fake_vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle.dart';
import 'package:carcare_customer_mobile/features/vehicles/domain/vehicle_repository.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets a test control exactly when each `getVehicles` call resolves, to
/// reproduce out-of-order responses (e.g. a manual refresh's `load()`
/// resolving after a `delete()`-triggered `load()` that started later).
class _RaceVehicleRepository extends Fake implements VehicleRepository {
  final List<Completer<List<Vehicle>>> completers = [];

  @override
  Future<List<Vehicle>> getVehicles() {
    final completer = Completer<List<Vehicle>>();
    completers.add(completer);
    return completer.future;
  }

  @override
  Future<void> deleteVehicle(String id) async {}
}

Vehicle _vehicle(String id, {String make = 'Toyota'}) =>
    Vehicle(id: id, plate: id, make: make, model: 'Prius');

class _ScriptedVehicleRepository extends Fake implements VehicleRepository {
  bool failLoad = false;
  Completer<Vehicle>? refreshCompleter;

  @override
  Future<List<Vehicle>> getVehicles() async {
    if (failLoad) throw const NetworkFailure('offline');
    return [_vehicle('live')];
  }

  @override
  Future<Vehicle> refreshFromHur(String id) => refreshCompleter!.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads the seeded vehicle', () async {
    final controller = VehiclesController(FakeVehicleRepository());

    await controller.load();

    expect(controller.state.status, VehiclesStatus.data);
    expect(controller.state.vehicles.single.plate, '9911УБЕ');
  });

  test('deletes a vehicle and reloads', () async {
    final controller = VehiclesController(FakeVehicleRepository());
    await controller.load();
    final target = controller.state.vehicles.single;

    final error = await controller.delete(target.id);

    expect(error, isNull);
    expect(controller.state.status, VehiclesStatus.empty);
  });

  test(
    'returns an error message instead of throwing for an unknown id',
    () async {
      final controller = VehiclesController(FakeVehicleRepository());
      await controller.load();

      final error = await controller.delete('does-not-exist');

      expect(error, isNotNull);
    },
  );

  test('reset returns to the initial state', () async {
    final controller = VehiclesController(FakeVehicleRepository());
    await controller.load();
    expect(controller.state.status, VehiclesStatus.data);

    controller.reset();

    expect(controller.state.status, VehiclesStatus.initial);
    expect(controller.state.vehicles, isEmpty);
  });

  test('ignores a stale load() response that arrives after a newer one '
      '(e.g. a manual refresh racing a delete-triggered reload)', () async {
    final repository = _RaceVehicleRepository();
    final controller = VehiclesController(repository);

    // Two overlapping loads: the first mirrors a manual refresh that
    // started first but is slow; the second mirrors the reload triggered
    // right after by a delete.
    unawaited(controller.load());
    final second = controller.load();
    expect(repository.completers, hasLength(2));

    // The SECOND (newer) call's response arrives first...
    repository.completers[1].complete([_vehicle('newer')]);
    await second;
    // ...then the stale first call's response arrives late.
    repository.completers[0].complete([_vehicle('older')]);
    await Future<void>.delayed(Duration.zero);

    // The stale response must not clobber the newer result.
    expect(controller.state.vehicles.single.id, 'newer');
  });

  test(
    'a failed reload keeps live vehicles on screen and sets the message',
    () async {
      final repository = _ScriptedVehicleRepository();
      final cache = InMemoryCacheStore();
      final controller = VehiclesController(repository, cache: cache);
      await controller.load();
      await cache.writeVehicles([_vehicle('cached')]);
      repository.failLoad = true;

      await controller.load();

      expect(controller.state.status, VehiclesStatus.data);
      expect(controller.state.isFromCache, isFalse);
      expect(controller.state.message, isNotNull);
      expect(controller.state.vehicles.single.id, 'live');
    },
  );

  test('refresh(id) drops a result that finishes after reset()', () async {
    final repository = _ScriptedVehicleRepository();
    final cache = InMemoryCacheStore();
    final controller = VehiclesController(repository, cache: cache);
    await controller.load();
    repository.refreshCompleter = Completer<Vehicle>();
    final pending = controller.refresh('live');
    await controller.reset();
    repository.refreshCompleter!.complete(_vehicle('live', make: 'Old'));
    await pending;

    expect(controller.state.status, VehiclesStatus.initial);
    expect(controller.state.vehicles, isEmpty);
    expect(await cache.readVehicles(), isNull);
    expect(controller.isRefreshing('live'), isFalse);
  });

  test('refresh(id) preserves the state message', () async {
    final repository = _ScriptedVehicleRepository();
    final controller = VehiclesController(
      repository,
      cache: InMemoryCacheStore(),
    );
    await controller.load();
    repository.failLoad = true;
    await controller.load(); // live kept, message set
    final message = controller.state.message;
    expect(message, isNotNull);
    repository.refreshCompleter = Completer<Vehicle>()
      ..complete(_vehicle('live', make: 'New'));

    await controller.refresh('live');

    expect(controller.state.message, message);
    expect(controller.state.vehicles.single.make, 'New');
  });

  test('reset() clears refreshing ids', () async {
    final repository = _ScriptedVehicleRepository();
    final controller = VehiclesController(repository);
    await controller.load();
    repository.refreshCompleter = Completer<Vehicle>();
    unawaited(controller.refresh('live'));
    expect(controller.isRefreshing('live'), isTrue);

    await controller.reset();

    expect(controller.isRefreshing('live'), isFalse);
  });
}
