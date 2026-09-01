import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:flutter/foundation.dart';

enum AuthStep { phone, otp }

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;
  Account? account;
  AuthStep step = AuthStep.phone;
  String phone = '';
  String? errorMessage;
  bool isBusy = false;

  bool get isAuthenticated => account != null;

  Future<void> restore() async {
    account = await _repository.restoreSession();
    notifyListeners();
  }

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
    await _repository.signOut();
    account = null;
    notifyListeners();
  }

  /// Signs out after a confirmed `401`. Same effect as [signOut]; kept as a
  /// separate name so call sites document why the session was cleared.
  Future<void> clearConfirmedUnauthorized() => signOut();

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
