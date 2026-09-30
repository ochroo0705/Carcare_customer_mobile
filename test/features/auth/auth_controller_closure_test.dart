import 'dart:async';

import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auth repo whose `deactivateAccount`/`deleteAccount` only completes once
/// the test tells it to — lets a test fire the remote `account_closed`
/// handler while `closeAccount` is still awaiting the server, reproducing
/// the backend's push-before-HTTP-response race.
class _SlowClosureRepo extends Fake implements AuthRepository {
  _SlowClosureRepo({Account? account})
    : _account =
          account ?? const Account(id: 'fake-account', phone: '99112233');

  Account? _account;
  final _gate = Completer<void>();
  int signOutCalls = 0;

  void releaseClosure() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Stream<void> get onSessionInvalidated => const Stream.empty();

  @override
  Future<Account?> restoreSession() async => _account;

  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<({Account account, bool reactivated})> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async => (account: _account!, reactivated: false);

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _account = null;
  }

  @override
  Future<String> requestClosureOtp() async => '****1234';

  @override
  Future<void> deactivateAccount(String code) async {
    await _gate.future;
    _account = null;
  }

  @override
  Future<void> deleteAccount(String code) async {
    await _gate.future;
    _account = null;
  }
}

void main() {
  test('closeAccount deactivate signs out on success', () async {
    final repo = FakeAuthRepository(signedIn: true);
    final c = AuthController(repo);
    await c.restore();

    expect(await c.closeAccount(deleteForever: false, code: '123456'), isTrue);
    expect(repo.lastClosure, ('deactivate', '123456'));
    expect(c.account, isNull);
  });

  test('closeAccount delete forever signs out on success', () async {
    final repo = FakeAuthRepository(signedIn: true);
    final c = AuthController(repo);
    await c.restore();

    expect(await c.closeAccount(deleteForever: true, code: '123456'), isTrue);
    expect(repo.lastClosure, ('delete', '123456'));
    expect(c.account, isNull);
  });

  test(
    'closeAccount skips device removal and flags the closure kind',
    () async {
      for (final deleteForever in [false, true]) {
        final repo = FakeAuthRepository(signedIn: true);
        var removalCalls = 0;
        final c = AuthController(repo)
          ..beforeSignOut = () async => removalCalls++;
        await c.restore();

        await c.closeAccount(deleteForever: deleteForever, code: '123456');
        expect(removalCalls, 0);
        expect(
          c.sessionEvent,
          deleteForever ? SessionEvent.deleted : SessionEvent.deactivated,
        );
      }
    },
  );

  test('failed closeAccount leaves sessionEvent unset', () async {
    final repo = FakeAuthRepository(signedIn: true)..closureShouldFail = true;
    final c = AuthController(repo);
    await c.restore();

    await c.closeAccount(deleteForever: false, code: '000000');
    expect(c.sessionEvent, isNull);
  });

  test(
    'closeAccount with wrong code keeps session and exposes error',
    () async {
      final repo = FakeAuthRepository(signedIn: true)..closureShouldFail = true;
      final c = AuthController(repo);
      await c.restore();

      expect(
        await c.closeAccount(deleteForever: true, code: '000000'),
        isFalse,
      );
      expect(c.account, isNotNull);
      expect(c.errorMessage, isNotNull);
    },
  );

  test('requestClosureOtp returns masked phone', () async {
    final repo = FakeAuthRepository(signedIn: true);
    final c = AuthController(repo);
    await c.restore();

    expect(await c.requestClosureOtp(), isNotNull);
  });

  test('verifyOtp surfaces reactivated flag', () async {
    final repo = FakeAuthRepository()..nextVerifyReactivated = true;
    final c = AuthController(repo);

    await c.requestOtp('99112233');
    expect(await c.verifyOtp('123456'), isTrue);
    expect(c.sessionEvent, SessionEvent.reactivated);
  });

  test('verifyOtp defaults reactivated to false', () async {
    final repo = FakeAuthRepository();
    final c = AuthController(repo);

    await c.requestOtp('99112233');
    expect(await c.verifyOtp('123456'), isTrue);
    expect(c.sessionEvent, isNull);
  });

  test('handleRemoteAccountClosed(deleted: true) signs out locally and flags deleted', () async {
    final repo = FakeAuthRepository(signedIn: true);
    var removalCalls = 0;
    final c = AuthController(repo)..beforeSignOut = () async => removalCalls++;
    await c.restore();

    await c.handleRemoteAccountClosed(deleted: true);

    expect(c.account, isNull);
    expect(c.sessionEvent, SessionEvent.remoteDeleted);
    // No device-removal call — the server already revoked the token, so a
    // call here would only 401.
    expect(removalCalls, 0);
  });

  test('handleRemoteAccountClosed(deleted: false) flags deactivated', () async {
    final repo = FakeAuthRepository(signedIn: true);
    final c = AuthController(repo);
    await c.restore();

    await c.handleRemoteAccountClosed(deleted: false);

    expect(c.account, isNull);
    expect(c.sessionEvent, SessionEvent.remoteDeactivated);
  });

  test(
    'handleRemoteAccountClosed is a no-op when already signed out',
    () async {
      final repo = FakeAuthRepository();
      final c = AuthController(repo);
      await c.restore();
      expect(c.isAuthenticated, isFalse);

      await c.handleRemoteAccountClosed(deleted: true);

      expect(c.sessionEvent, isNull);
    },
  );

  test('a remote account_closed push arriving mid-closeAccount is a no-op: '
      'exactly one sign-out, justClosedAccount set (not stale), and the remote '
      'flag never set', () async {
    final repo = _SlowClosureRepo();
    final c = AuthController(repo);
    await c.restore();
    expect(c.isAuthenticated, isTrue);

    final closeFuture = c.closeAccount(deleteForever: true, code: '123456');
    // closeAccount is now awaiting the server — fire this device's own
    // account_closed push, exactly like the backend's early delivery.
    await c.handleRemoteAccountClosed(deleted: true);
    // The push must have been ignored: closeAccount still owns the flow.
    expect(c.isAuthenticated, isTrue);
    expect(c.sessionEvent, isNull);

    repo.releaseClosure();
    expect(await closeFuture, isTrue);

    // Exactly one sign-out, caused by closeAccount, with a fresh (not
    // stale) flag.
    expect(repo.signOutCalls, 0); // closeAccount doesn't call signOut()
    expect(c.account, isNull);
    expect(c.sessionEvent, SessionEvent.deleted);
  });

  test(
    'a remote push arriving mid-closeAccount does not leak a stale flag into '
    'the next ordinary sign-out',
    () async {
      final repo = _SlowClosureRepo();
      final c = AuthController(repo);
      await c.restore();

      final closeFuture = c.closeAccount(deleteForever: false, code: '123456');
      await c.handleRemoteAccountClosed(deleted: false);
      repo.releaseClosure();
      await closeFuture;

      expect(c.sessionEvent, SessionEvent.deactivated);
      // Consume it, as the services would.
      c.takeSessionEvent();

      // A later remote push (e.g. this device's own push arriving very late)
      // must still be a no-op now that the session is already gone, and must
      // not resurrect justClosedAccount.
      await c.handleRemoteAccountClosed(deleted: true);
      expect(c.sessionEvent, isNull);
    },
  );
}
