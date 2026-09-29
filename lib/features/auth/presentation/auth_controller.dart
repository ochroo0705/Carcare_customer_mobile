import 'dart:async';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:flutter/foundation.dart';

enum AuthStep { phone, otp }

/// Account realm-ийн OTP flow болон app-ийн authenticated state-г удирдана.
/// UI зөвхөн энэ state-ийг ажиглана; token хадгалалт, server contract-ийг
/// [AuthRepository] хэрэгжүүлдэг.
class AuthController extends ChangeNotifier {
  AuthController(this._repository) {
    // Any authenticated repository can clear the session on a 401, not just
    // the screen that happened to make the failing call — listen at this
    // single point so `account` never drifts out of sync with storage.
    _invalidatedSubscription = _repository.onSessionInvalidated.listen(
      (_) => _handleSessionInvalidated(),
    );
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _invalidatedSubscription;

  /// Runs, while the session is still valid, right before [signOut] clears
  /// it — e.g. deregistering the device for push. Set by whoever owns the
  /// side effects that need the still-live token (see `AppRouter`); signing
  /// out after a 401 skips this since the token is already invalid there.
  Future<void> Function()? beforeSignOut;
  Account? account;
  AuthStep step = AuthStep.phone;
  String phone = '';
  String? errorMessage;
  bool isBusy = false;

  /// Set by [verifyOtp] from the server's `reactivated` flag: true when this
  /// sign-in cleared a previous self-service deactivation. Not persisted —
  /// only meaningful right after a successful [verifyOtp] call, for a
  /// one-time "welcome back" notice.
  bool justReactivated = false;

  /// Set by [closeAccount] on success: `false` = deactivated, `true` =
  /// deleted forever, `null` = the last sign-out was not a closure. The
  /// router consumes it once to show a notice and to skip the device-removal
  /// call (the server already dropped the devices and the token is dead).
  bool? justClosedAccount;

  /// Set by [handleRemoteAccountClosed]: `'deleted'` or `'deactivated'` when
  /// this device's still-signed-in session just learned (via a silent push)
  /// that the account was closed elsewhere — e.g. from the website. Distinct
  /// from [justClosedAccount], which is this device's own in-app closure
  /// flow; the router uses the two to pick between "Бүртгэл тань ..." (remote)
  /// and "Бүртгэл ... боллоо/лээ" (local) wording. Consumed once by the router.
  String? justRemoteClosedAccount;

  /// True for the duration of this device's own [closeAccount] call. The
  /// backend sends the `account_closed` push right after its DB transaction
  /// commits but *before* the closure HTTP response returns, so on the
  /// device that requested the closure, the push can arrive while
  /// `closeAccount` is still awaiting that response. Without this guard,
  /// [handleRemoteAccountClosed] would run mid-`closeAccount`, sign out and
  /// show the remote snackbar, and then `closeAccount` would resume and set
  /// [justClosedAccount] after the sign-out transition already fired — a
  /// flag nobody ever consumes, left to leak into the *next* sign-out as a
  /// stale "Бүртгэл устгагдлаа" notice.
  bool _closingAccount = false;

  // Storage was cleared (a 401, or the closure call's own clear) while
  // [closeAccount] was running. That call decides what the sign-out means;
  // this only records that one is owed if the closure itself failed.
  bool _invalidatedWhileClosing = false;

  bool get isAuthenticated => account != null;

  /// Handles the backend's silent `account_closed` data push (sent on
  /// deactivation/deletion, including from the website). Local-only: the
  /// server already revoked the token and dropped this device's row, so no
  /// network call is made here (one would just 401). Idempotent — a no-op
  /// once already signed out (covers this device's own push arriving after
  /// [closeAccount] already finished), and also a no-op while [closeAccount]
  /// is still in flight (see [_closingAccount]) — that call owns the
  /// sign-out and its own "Бүртгэл ... боллоо/лээ" notice in that case.
  Future<void> handleRemoteAccountClosed({required bool deleted}) async {
    if (_closingAccount) return;
    if (!isAuthenticated) return;
    await _repository.signOut();
    justRemoteClosedAccount = deleted ? 'deleted' : 'deactivated';
    account = null;
    notifyListeners();
  }

  /// Launch үед secure session-ийг нэг удаа сэргээнэ. Token эвдэрсэн эсвэл
  /// session байхгүй бол account null хэвээр үлдэж public discovery ажиллана.
  Future<void> restore() async {
    account = await _repository.restoreSession();
    notifyListeners();
  }

  /// Phone-г API руу явуулахаас өмнө Монголын 8 оронтой хэлбэрийг шалгана.
  /// Амжилттай request-ийн дараа л OTP алхам руу шилжинэ.
  Future<bool> requestOtp(String value) async {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (!RegExp(r'^\d{8}$').hasMatch(normalized)) {
      errorMessage = '8 оронтой утасны дугаар оруулна уу.';
      notifyListeners();
      return false;
    }
    return _run(() async {
      await _repository.requestOtp(normalized);
      phone = normalized;
      step = AuthStep.otp;
    });
  }

  /// OTP-г repository-д баталгаажуулж, амжилттай бол account state-г солино.
  Future<bool> verifyOtp(String code) async {
    final trimmed = code.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(trimmed)) {
      errorMessage = '6 оронтой кодоо оруулна уу.';
      notifyListeners();
      return false;
    }
    return _run(() => _verify(trimmed));
  }

  Future<void> _verify(String code) async {
    final result = await _repository.verifyOtp(phone: phone, code: code);
    account = result.account;
    justReactivated = result.reactivated;
  }

  /// Account closure OTP хүсэж, masked утасны дугаар буцаана. Алдаа гарвал
  /// `null` буцааж [errorMessage]-г тохируулна.
  Future<String?> requestClosureOtp() async {
    if (isBusy) return null;
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _repository.requestClosureOtp();
    } on AppFailure catch (failure) {
      errorMessage = failure.message;
      return null;
    } catch (_) {
      errorMessage = 'Тодорхойгүй алдаа гарлаа.';
      return null;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Deactivate (`deleteForever: false`) эсвэл delete forever
  /// (`deleteForever: true`) хийж, амжилттай бол local session-г гаргана.
  /// Буруу код өгвөл session хэвээр үлдэж [errorMessage] тавигдана.
  Future<bool> closeAccount({
    required bool deleteForever,
    required String code,
  }) => _run(() async {
    _closingAccount = true;
    _invalidatedWhileClosing = false;
    try {
      if (deleteForever) {
        await _repository.deleteAccount(code);
      } else {
        await _repository.deactivateAccount(code);
      }
      // beforeSignOut (device removal) is skipped on purpose: the server
      // already deleted this account's devices and the token is now
      // rejected, so the call could only 401.
      //
      // Guard against the account_closed push's own race (see
      // `_closingAccount`'s doc): with the guard in place this is always
      // true in practice (`handleRemoteAccountClosed` cannot have nulled
      // `account` while `_closingAccount` was true) — kept as a defensive
      // belt-and-suspenders check so a transition is never fired, and the
      // flag never set, for a sign-out this call didn't actually cause.
      if (account != null) {
        justClosedAccount = deleteForever;
        account = null;
      }
    } finally {
      _closingAccount = false;
      // The closure failed but its request 401'd and wiped the session:
      // still sign out, as a plain sign-out (no closure notice).
      if (_invalidatedWhileClosing && account != null) {
        account = null;
        notifyListeners();
      }
      _invalidatedWhileClosing = false;
    }
  });

  void editPhone() {
    step = AuthStep.phone;
    errorMessage = null;
    notifyListeners();
  }

  void resetFlow() {
    step = AuthStep.phone;
    phone = '';
    errorMessage = null;
    // isBusy is deliberately left alone: a request still in flight clears it
    // when it finishes. Resetting it here let a second request start
    // alongside the first.
  }

  Future<void> signOut() async {
    // Must run before the token is cleared below — device deregistration
    // needs a still-valid Authorization header, otherwise the server 401s
    // the DELETE before it ever removes the row, leaving push notifications
    // arriving on a signed-out device indefinitely.
    await beforeSignOut?.call();
    await _repository.signOut();
    account = null;
    notifyListeners();
  }

  /// Signs out after a confirmed `401`. Same effect as [signOut], except the
  /// token is already invalid server-side at this point, so [beforeSignOut]
  /// (e.g. device deregistration) is expected to fail there too — kept as a
  /// separate name so call sites document why the session was cleared.
  Future<void> clearConfirmedUnauthorized() => signOut();

  /// Storage has already been cleared by the repository that hit the 401 —
  /// this only needs to drop the in-memory `account` so the UI catches up.
  void _handleSessionInvalidated() {
    // The closure's own storage clear fires this too, and the event may land
    // before closeAccount resumes — nulling `account` here would make it
    // skip `justClosedAccount`, losing the "Бүртгэл ... боллоо" notice.
    if (_closingAccount) {
      _invalidatedWhileClosing = true;
      return;
    }
    if (account == null) return;
    account = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _invalidatedSubscription.cancel();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (isBusy) return false;
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on AppFailure catch (failure) {
      errorMessage = failure.message;
      return false;
    } catch (_) {
      errorMessage = 'Тодорхойгүй алдаа гарлаа.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
