import 'dart:async';

import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_controller.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/controllers/appointments_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_controller.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/discovery_state.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/controllers/organization_detail_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_controller.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_controller.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/controllers/vehicles_state.dart';
import 'package:flutter/foundation.dart';

/// Clock used for the resume throttle. Tests replace it to move time.
@visibleForTesting
DateTime Function() reloadClock = DateTime.now;

/// Resume reloads are skipped for a controller that loaded successfully less
/// than this long ago.
const resumeReloadThrottle = Duration(seconds: 30);

/// Which controllers a given trigger reloads, in one place. Triggers:
///
/// | trigger      | reloads                                                    |
/// |--------------|------------------------------------------------------------|
/// | signIn       | appointments, vehicles, history, notifications             |
/// | reconnect    | org detail (if failed); discovery/appointments/vehicles/   |
/// |              | history when cached or errored; notifications when errored |
/// | resume       | appointments, history (throttled, signed in only)          |
/// | push(type)   | terminal: appointments+history+vehicles; active-only:     |
/// |              | appointments; anything else: nothing (signed in only)      |
///
/// Last-success times are tracked here, not in the controllers: a load counts
/// as successful when it ends in neither an error nor a cached/loading state.
class ReloadCoordinator {
  ReloadCoordinator({
    required this.discovery,
    required this.organizationDetail,
    required this.appointments,
    required this.vehicles,
    required this.history,
    required this.notifications,
    required this.isAuthenticated,
  });

  final DiscoveryController discovery;
  final OrganizationDetailController organizationDetail;
  final AppointmentsController appointments;
  final VehiclesController vehicles;
  final HistoryController history;
  final NotificationsController notifications;
  final bool Function() isAuthenticated;

  final ValueNotifier<int> _reconnects = ValueNotifier(0);
  final Map<Object, DateTime> _lastSuccess = {};
  bool _wasOnline = true;

  /// Ticks on each offline -> online transition, for screen-owned controllers
  /// this class can't reach (e.g. diagnostics inside `HistoryScreen`).
  ValueListenable<int> get reconnects => _reconnects;

  // Terminal-status push types move an appointment/order OUT of the active
  // Appointments list and INTO History (D-085), so both reload. Everything in
  // the active-only set changes a field on an already-active item, so
  // Appointments alone covers it. feedback_replied / broadcast / unknown touch
  // neither list.
  static const _terminalPushTypes = {
    'appointment_rejected',
    'appointment_expired',
    'appointment_no_show',
    'order_completed',
    'order_cancelled',
  };
  static const _activeOnlyPushTypes = {
    'appointment_confirmed',
    'appointment_booked_by_staff',
    'appointment_reminder',
    'appointment_rescheduled',
    'order_in_progress',
    'order_payment_received',
    'order_rescheduled',
    'expected_finish_revised',
  };

  void _run(Object key, Future<void> Function() load, bool Function() ok) {
    unawaited(
      load().then((_) {
        if (ok()) _lastSuccess[key] = reloadClock();
      }),
    );
  }

  void _loadAppointments() =>
      _run(appointments, appointments.load, () => _appointmentsOk);
  void _loadVehicles() => _run(vehicles, vehicles.load, () => _vehiclesOk);
  void _loadHistory() => _run(history, history.load, () => _historyOk);
  void _loadNotifications() =>
      _run(notifications, notifications.load, () => _notificationsOk);

  bool get _appointmentsOk =>
      appointments.state.status != AppointmentsStatus.error &&
      appointments.state.status != AppointmentsStatus.loading &&
      !appointments.state.isFromCache &&
      appointments.state.message == null;
  bool get _vehiclesOk =>
      vehicles.state.status != VehiclesStatus.error &&
      vehicles.state.status != VehiclesStatus.loading &&
      !vehicles.state.isFromCache &&
      vehicles.state.message == null;
  bool get _historyOk =>
      history.state.status != HistoryStatus.error &&
      history.state.status != HistoryStatus.loading &&
      !history.state.isFromCache &&
      history.state.message == null;
  bool get _notificationsOk =>
      notifications.state.status != NotificationsStatus.error &&
      notifications.state.status != NotificationsStatus.loading &&
      notifications.state.message == null;

  bool _fresh(Object key) {
    final at = _lastSuccess[key];
    return at != null && reloadClock().difference(at) < resumeReloadThrottle;
  }

  /// Forget throttle history, e.g. after sign-out reset the controllers.
  void clearHistory() => _lastSuccess.clear();

  void onSignIn() {
    _loadAppointments();
    _loadVehicles();
    _loadHistory();
    _loadNotifications();
  }

  /// Connectivity result from the probe. Only an offline -> online transition
  /// is a reconnect; the initial `true` at startup is not.
  void onConnectivity(bool online) {
    final reconnected = online && !_wasOnline;
    _wasOnline = online;
    if (reconnected) onReconnect();
  }

  void onReconnect() {
    _reconnects.value++;
    organizationDetail.retryIfFailed();
    if (discovery.state.isFromCache ||
        discovery.state.status == DiscoveryStatus.error) {
      discovery.load();
    }
    if (!isAuthenticated()) return;
    if (appointments.state.isFromCache ||
        appointments.state.status == AppointmentsStatus.error) {
      _loadAppointments();
    }
    if (vehicles.state.isFromCache ||
        vehicles.state.status == VehiclesStatus.error) {
      _loadVehicles();
    }
    if (history.state.isFromCache ||
        history.state.status == HistoryStatus.error) {
      _loadHistory();
    }
    if (notifications.state.status == NotificationsStatus.error) {
      _loadNotifications();
    }
  }

  /// Reconciles after a foreground return: a missed push leaves state looking
  /// normal, so nothing else would catch it. Skips a controller that loaded
  /// successfully within [resumeReloadThrottle].
  void onResume() {
    if (!isAuthenticated()) return;
    if (!_fresh(appointments)) _loadAppointments();
    if (!_fresh(history)) _loadHistory();
  }

  void onPush(String? type) {
    if (!isAuthenticated()) return;
    if (_terminalPushTypes.contains(type)) {
      _loadAppointments();
      _loadHistory();
      // The vehicles list embeds per-vehicle completed-order / report counts
      // and VehicleDetailScreen never refetches; a terminal order push is
      // exactly what invalidates them.
      _loadVehicles();
    } else if (_activeOnlyPushTypes.contains(type)) {
      _loadAppointments();
    }
  }

  void dispose() => _reconnects.dispose();
}
