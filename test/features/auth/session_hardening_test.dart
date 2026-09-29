// Regression tests for the 2026-09-29 login/session review: stale 401s,
// sign-out racing an in-flight load, unreadable or reinstalled secure
// storage, the closure notice, the `from` redirect, and OTP input.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:carcare_customer_mobile/app/customer_router.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/auth/data/secure_session_store.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Always401 implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({'error': 'unauthorized'}),
    401,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _GatedAppointments extends Fake implements AppointmentRepository {
  final gate = Completer<void>();

  @override
  Future<List<Appointment>> getAppointments() async {
    await gate.future;
    return const [];
  }

  @override
  Future<List<WalkInOrder>> getWalkInOrders() async => const [];
}

class _RecordingCache extends NoopCacheStore {
  int appointmentWrites = 0;

  @override
  Future<void> writeAppointments(List<Appointment> appointments) async {
    appointmentWrites++;
  }
}

/// Closure repo whose storage clear emits on [onSessionInvalidated] — like
/// the real `RemoteAuthRepository`, and unlike the plain fakes.
class _EmittingClosureRepo extends Fake implements AuthRepository {
  _EmittingClosureRepo({this.fail401 = false});
  final bool fail401;
  final _invalidated = StreamController<void>.broadcast();

  @override
  Stream<void> get onSessionInvalidated => _invalidated.stream;

  @override
  Future<Account?> restoreSession() async =>
      const Account(id: 'a', phone: '99112233');

  @override
  Future<void> deactivateAccount(String code) async {
    _invalidated.add(null);
    if (fail401) throw Exception('401');
  }
}

ApiClient _client({
  required Future<String?> Function() token,
  required Future<void> Function() onUnauthorized,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _Always401();
  return ApiClient(
    baseUrl: 'https://api.test',
    dio: dio,
    accessTokenProvider: token,
    onUnauthorized: onUnauthorized,
  );
}

void main() {
  group('ApiClient 401', () {
    test('clears the session when the current token was rejected', () async {
      var cleared = 0;
      final client = _client(
        token: () async => 'token-a',
        onUnauthorized: () async => cleared++,
      );
      await expectLater(client.getJson('/x'), throwsA(anything));
      expect(cleared, 1);
    });

    test('ignores a 401 for a token that is no longer current', () async {
      var cleared = 0;
      var current = 'token-a';
      final client = _client(
        // The first read builds the request; by the time the 401 arrives
        // another account has signed in.
        token: () async {
          final value = current;
          current = 'token-b';
          return value;
        },
        onUnauthorized: () async => cleared++,
      );
      await expectLater(client.getJson('/x'), throwsA(anything));
      expect(cleared, 0);
    });

    test('ignores a 401 on a request sent without a token', () async {
      var cleared = 0;
      final client = _client(
        token: () async => null,
        onUnauthorized: () async => cleared++,
      );
      await expectLater(client.getJson('/x'), throwsA(anything));
      expect(cleared, 0);
    });
  });

  test('a load in flight at sign-out cannot restore state or cache', () async {
    final repository = _GatedAppointments();
    final cache = _RecordingCache();
    final controller = AppointmentsController(repository, cache: cache);

    final load = controller.load();
    await controller.reset();
    repository.gate.complete();
    await load;

    expect(controller.state.status, const AppointmentsState().status);
    expect(cache.appointmentWrites, 0);
  });

  group('SecureSessionStore', () {
    late _MockStorage storage;
    const session = {
      'account_access_token': 't',
      'account_id': 'a',
      'account_phone': '99112233',
    };

    setUp(() {
      storage = _MockStorage();
      when(() => storage.deleteAll()).thenAnswer((_) async {});
    });

    test('a fresh install discards a session left in the keychain', () async {
      SharedPreferences.setMockInitialValues({});
      when(() => storage.readAll()).thenAnswer((_) async => {});
      final store = SecureSessionStore(storage: storage);
      expect(await store.readAccount(), isNull);
      verify(() => storage.deleteAll()).called(1);
    });

    test('an app update keeps the existing session', () async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      when(() => storage.readAll()).thenAnswer((_) async => session);
      final store = SecureSessionStore(storage: storage);
      expect((await store.readAccount())?.id, 'a');
      verifyNever(() => storage.deleteAll());
    });

    test('unreadable storage is wiped and reads as signed out', () async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      when(() => storage.readAll()).thenThrow(Exception('bad key'));
      final store = SecureSessionStore(storage: storage);
      expect(await store.readAccount(), isNull);
      expect(await store.readToken(), isNull);
      verify(() => storage.deleteAll()).called(greaterThan(0));
    });

    test('a half-written session sends no token', () async {
      SharedPreferences.setMockInitialValues({'onboarding_done': true});
      when(() => storage.readAll())
          .thenAnswer((_) async => {'account_access_token': 't'});
      final store = SecureSessionStore(storage: storage);
      expect(await store.readToken(), isNull);
    });
  });

  group('closeAccount', () {
    test('keeps the closure notice when storage clearing races it', () async {
      final controller = AuthController(_EmittingClosureRepo());
      await controller.restore();
      final ok = await controller.closeAccount(
        deleteForever: false,
        code: '123456',
      );
      await Future<void>.delayed(Duration.zero);
      expect(ok, isTrue);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.justClosedAccount, isFalse);
    });

    test('a closure that 401s still signs out, without a notice', () async {
      final controller = AuthController(_EmittingClosureRepo(fail401: true));
      await controller.restore();
      final ok = await controller.closeAccount(
        deleteForever: false,
        code: '123456',
      );
      await Future<void>.delayed(Duration.zero);
      expect(ok, isFalse);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.justClosedAccount, isNull);
    });
  });

  test('login only returns to in-app paths', () {
    expect(
      safeReturnLocation('/organizations/x/book?branch=b'),
      '/organizations/x/book?branch=b',
    );
    expect(safeReturnLocation(null), isNull);
    expect(safeReturnLocation('https://evil.test/'), isNull);
    expect(safeReturnLocation('//evil.test/x'), isNull);
    expect(safeReturnLocation('organizations/x'), isNull);
    expect(safeReturnLocation('/login?from=/x'), isNull);
  });

  test('verifyOtp rejects a code that is not 6 digits', () async {
    final controller = AuthController(_EmittingClosureRepo());
    expect(await controller.verifyOtp('12'), isFalse);
    expect(controller.errorMessage, isNotNull);
  });
}
