import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter/foundation.dart';

class AppointmentsController extends ChangeNotifier {
  AppointmentsController(this._repository);

  final AppointmentRepository _repository;
  AppointmentsState _state = const AppointmentsState();
  final Set<String> _cancellingIds = {};

  AppointmentsState get state => _state;

  bool isCancelling(String id) => _cancellingIds.contains(id);

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
      final appointments = await _repository.getAppointments();
      _state = AppointmentsState(
        status: appointments.isEmpty
            ? AppointmentsStatus.empty
            : AppointmentsStatus.data,
        appointments: appointments,
      );
    } on AppFailure catch (failure) {
      _state = AppointmentsState(
        status: AppointmentsStatus.error,
        message: failure.message,
      );
    } catch (_) {
      _state = const AppointmentsState(
        status: AppointmentsStatus.error,
        message: 'Тодорхойгүй алдаа гарлаа.',
      );
    }
    notifyListeners();
  }

  /// Resets to the initial state, e.g. after the customer signs out.
  void reset() {
    _state = const AppointmentsState();
    _cancellingIds.clear();
    notifyListeners();
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
