import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/data/cache/cache_store.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter/foundation.dart';

class AppointmentsController extends ChangeNotifier {
  AppointmentsController(this._repository, {CacheStore? cache})
    : _cache = cache ?? const NoopCacheStore();

  final AppointmentRepository _repository;
  final CacheStore _cache;
  AppointmentsState _state = const AppointmentsState();
  final Set<String> _cancellingIds = {};

  AppointmentsState get state => _state;

  bool isCancelling(String id) => _cancellingIds.contains(id);

  /// Active хүсэлтүүдийг ойрын цагаар нь, эцсийн төлөвүүдийг сүүлийн өөрчлөлт
  /// гэж үзэн шинэ огноогоор нь харуулна. Repository-ийн буцаасан list нь
  /// unmodifiable байж болох тул энд заавал хуулж байж sort хийнэ.
  List<Appointment> get sortedAppointments {
    final active =
        _state.appointments
            .where((appointment) => appointment.status.isActive)
            .toList()
          ..sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    final inactive =
        _state.appointments
            .where((appointment) => !appointment.status.isActive)
            .toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return [...active, ...inactive];
  }

  Future<void> load() async {
    _state = AppointmentsState(
      status: AppointmentsStatus.loading,
      appointments: _state.appointments,
    );
    notifyListeners();
    try {
      // Network амжилттай үед cache-г бүхэлд нь солих нь өмнөх Account-ийн
      // үлдэгдэл болон шинэ response холилдохоос сэргийлнэ.
      final appointments = await _repository.getAppointments();
      _state = AppointmentsState(
        status: appointments.isEmpty
            ? AppointmentsStatus.empty
            : AppointmentsStatus.data,
        appointments: appointments,
      );
      await _cache.writeAppointments(appointments);
    } on AppFailure catch (failure) {
      // Cache нь source of truth биш: зөвхөн сүүлийн амжилттай fetch-ийг
      // offline үед харуулна, failure message-г state дээр хадгална.
      _state = await _fallbackToCache(failure.message);
    } catch (_) {
      _state = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
    }
    notifyListeners();
  }

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached appointments.
  Future<void> reset() async {
    _state = const AppointmentsState();
    _cancellingIds.clear();
    notifyListeners();
    await _cache.clearAppointments();
  }

  Future<AppointmentsState> _fallbackToCache(String failureMessage) async {
    final cached = await _cache.readAppointments();
    if (cached == null || cached.isEmpty) {
      return AppointmentsState(
        status: AppointmentsStatus.error,
        message: failureMessage,
      );
    }
    return AppointmentsState(
      status: AppointmentsStatus.data,
      appointments: cached,
      isFromCache: true,
      message: failureMessage,
    );
  }

  /// Cancels an appointment and reloads the list. Returns an error message on
  /// failure, or `null` on success.
  Future<String?> cancel(String id) async {
    if (_cancellingIds.contains(id)) return null;
    _cancellingIds.add(id);
    notifyListeners();
    try {
      await _repository.cancelAppointment(id);
      await load();
      return null;
    } on AppFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Тодорхойгүй алдаа гарлаа.';
    } finally {
      _cancellingIds.remove(id);
      notifyListeners();
    }
  }
}
