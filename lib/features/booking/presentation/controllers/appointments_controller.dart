import 'dart:convert';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppointmentsController extends ChangeNotifier {
  AppointmentsController(this._repository);

  static const _cacheKey = 'appointments_cache_v1';

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
      await _saveCache(appointments);
    } on AppFailure catch (failure) {
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
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_cacheKey);
    } catch (_) {
      // Best-effort — a stale cache is overwritten by the next load() anyway.
    }
  }

  Future<AppointmentsState> _fallbackToCache(String failureMessage) async {
    final cached = await _readCache();
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

  Future<void> _saveCache(List<Appointment> appointments) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final json = jsonEncode(appointments.map(_appointmentToJson).toList());
      await preferences.setString(_cacheKey, json);
    } catch (_) {
      // Persisting the cache is a best-effort convenience; a write failure
      // here must never surface as a load failure.
    }
  }

  Future<List<Appointment>?> _readCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final appointments = decoded
          .map(_appointmentFromJson)
          .whereType<Appointment>()
          .toList();
      return appointments.isEmpty ? null : appointments;
    } catch (_) {
      return null;
    }
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

Map<String, dynamic> _appointmentToJson(Appointment appointment) => {
  'id': appointment.id,
  'status': appointment.status.name,
  'requestedAt': appointment.requestedAt.toIso8601String(),
  'tenantName': appointment.tenantName,
  'tenantSlug': appointment.tenantSlug,
  'branchName': appointment.branchName,
  'note': appointment.note,
  'categoryName': appointment.categoryName,
  'vehiclePlate': appointment.vehiclePlate,
};

Appointment? _appointmentFromJson(Object? value) {
  if (value is! Map) return null;
  final id = value['id'];
  final statusName = value['status'];
  final requestedAtRaw = value['requestedAt'];
  final tenantName = value['tenantName'];
  final tenantSlug = value['tenantSlug'];
  final branchName = value['branchName'];
  if (id is! String ||
      statusName is! String ||
      requestedAtRaw is! String ||
      tenantName is! String ||
      tenantSlug is! String ||
      branchName is! String) {
    return null;
  }
  final requestedAt = DateTime.tryParse(requestedAtRaw);
  if (requestedAt == null) return null;
  return Appointment(
    id: id,
    status: AppointmentStatus.values.firstWhere(
      (status) => status.name == statusName,
      orElse: () => AppointmentStatus.unknown,
    ),
    requestedAt: requestedAt,
    tenantName: tenantName,
    tenantSlug: tenantSlug,
    branchName: branchName,
    note: value['note'] is String ? value['note'] as String : null,
    categoryName: value['categoryName'] is String
        ? value['categoryName'] as String
        : null,
    vehiclePlate: value['vehiclePlate'] is String
        ? value['vehiclePlate'] as String
        : null,
  );
}
