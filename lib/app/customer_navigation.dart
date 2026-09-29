import 'package:carcare_customer_mobile/app/customer_app_services.dart';
import 'package:carcare_customer_mobile/app/customer_routes.dart';
import 'package:carcare_customer_mobile/app/customer_shell.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Hosts the flows that open several pages in sequence — push-tap
/// deep-linking, booking completion, and the "request login" entry point —
/// plus the shell key and router the rest of the app reaches through.
///
/// `router` is assigned right after `buildCustomerRouter(services, this)`
/// returns, since the router itself needs a `CustomerNavigation` to close
/// the circular reference.
class CustomerNavigation {
  CustomerNavigation(this.services);

  final CustomerAppServices services;
  final shellKey = GlobalKey<CustomerShellState>();

  /// Matches `CustomerShell`'s `destinations` order (Хайх · Захиалах ·
  /// Захиалгууд · Түүх · Профайл).
  static const appointmentsTabIndex = 2;

  late final GoRouter router;

  /// Public entry point for showing the login screen — used by onboarding's
  /// "Бүртгэлдээ нэвтрэх" soft-login hand-off.
  void requestLogin() => router.push(CustomerRoutes.login());

  /// Opens an appointment's detail page and reloads the appointments list so
  /// the detail page resolves against the freshest state — same reasoning as
  /// the old delegate's `_openAppointmentDetail` (router.dart:582-592).
  void openAppointment(String id) {
    router.push(CustomerRoutes.appointment(id));
    services.appointmentsController.load();
  }

  /// Reloads the given vehicle from HUR and surfaces the result as a
  /// snackbar — same sequence and copy as the old delegate's
  /// `_refreshSelectedVehicleFromHur` (router.dart:552-565).
  Future<void> refreshVehicleFromHur(String id) async {
    final error = await services.vehiclesController.refresh(id);
    if (error != null) {
      services.showMessage?.call(error);
      return;
    }
    services.showMessage?.call('Машины мэдээлэл HUR-аас шинэчлэгдлээ.');
  }

  /// Routes a tapped push notification (or a tap on a row of the in-app
  /// list, via [fromList]) to the relevant screen — same contract as the old
  /// delegate's `_handleNotificationTap` (router.dart:607-629).
  void openFromPush(Map<String, dynamic> data, {bool fromList = false}) {
    final appointmentId = data['appointmentId'];
    if (appointmentId is String &&
        appointmentId.isNotEmpty &&
        services.authController.isAuthenticated) {
      router.go(CustomerRoutes.shell); // == _clearOverlays
      services.reloadListsForPushType(data['type'] as String?);
      shellKey.currentState?.selectDestination(appointmentsTabIndex);
      openAppointment(appointmentId);
      return;
    }
    // No routable appointment (broadcast, missing id, or signed out): surface
    // the in-app notifications list, where the message already landed. A tap
    // that came from that list stays put instead.
    if (fromList) return;
    router.go(CustomerRoutes.shell);
    router.push(CustomerRoutes.notifications);
  }

  /// Same sequence as the old delegate's `onCompleted` (router.dart:365-398):
  /// haptic, reload appointments, clear back to the shell, jump to the
  /// Appointments tab, open the new appointment's detail, show the snackbar,
  /// and — when the appointment carries a booking fee — open payment on top.
  /// Takes `CreatedAppointment` — `BookingRequestScreen.onCompleted`'s actual
  /// payload type, not the list/detail `Appointment` domain model the brief's
  /// snippet used. Both carry `id` and `payment`, which is all this needs.
  void completeBooking(CreatedAppointment appointment) {
    HapticFeedback.mediumImpact();
    services.appointmentsController.load();
    router.go(CustomerRoutes.shell);
    shellKey.currentState?.selectDestination(appointmentsTabIndex);
    openAppointment(appointment.id);
    services.showMessage?.call('Цагийн хүсэлт амжилттай илгээгдлээ.');
    if (appointment.payment != null) {
      router.push(CustomerRoutes.payment(appointment.id), extra: appointment.payment);
    }
  }
}
