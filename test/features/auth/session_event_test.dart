import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('session listenable (router refresh)', () {
    test('does not fire on busy, error or step changes', () async {
      final c = AuthController(FakeAuthRepository());
      var fired = 0;
      c.session.addListener(() => fired++);

      await c.requestOtp('abc'); // error path
      expect(c.errorMessage, isNotNull);
      await c.requestOtp('99112233'); // busy + step change
      expect(c.step, AuthStep.otp);
      c.editPhone();
      expect(fired, 0);
    });

    test('fires on sign-in, sign-out and account swap only', () async {
      final c = AuthController(FakeAuthRepository());
      var fired = 0;
      c.session.addListener(() => fired++);

      await c.requestOtp('99112233');
      await c.verifyOtp('123456');
      expect(fired, 1);
      await c.signOut();
      expect(fired, 2);
    });
  });

  group('session event', () {
    test('reactivation is consumed exactly once', () async {
      final c = AuthController(
        FakeAuthRepository()..nextVerifyReactivated = true,
      );
      await c.requestOtp('99112233');
      await c.verifyOtp('123456');
      expect(c.takeSessionEvent(), SessionEvent.reactivated);
      expect(c.takeSessionEvent(), isNull);
    });

    test(
      'closure and remote closure reasons do not leak into a later sign-out',
      () async {
        final repo = FakeAuthRepository(signedIn: true);
        final c = AuthController(repo);
        await c.restore();
        await c.closeAccount(deleteForever: true, code: '123456');
        expect(c.takeSessionEvent(), SessionEvent.deleted);
        expect(c.takeSessionEvent(), isNull);

        final c2 = AuthController(FakeAuthRepository(signedIn: true));
        await c2.restore();
        await c2.handleRemoteAccountClosed(deleted: false);
        expect(c2.takeSessionEvent(), SessionEvent.remoteDeactivated);
        await c2.requestOtp('99112233');
        await c2.verifyOtp('123456');
        await c2.signOut();
        // Plain user sign-out: only "device removal handled", never a stale
        // closure notice.
        expect(c2.takeSessionEvent(), isNot(SessionEvent.remoteDeactivated));
      },
    );

    test('reason is visible to listeners during sign-out', () async {
      final c = AuthController(FakeAuthRepository(signedIn: true));
      await c.restore();
      SessionEvent? seen;
      c.addListener(() {
        if (c.account == null) seen = c.sessionEvent;
      });
      await c.handleRemoteAccountClosed(deleted: true);
      expect(seen, SessionEvent.remoteDeleted);
    });
  });
}
