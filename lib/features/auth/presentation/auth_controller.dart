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

  bool get isAuthenticated => account != null;

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
  Future<bool> verifyOtp(String code) => _run(() async {
    account = await _repository.verifyOtp(phone: phone, code: code.trim());
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
    isBusy = false;
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
