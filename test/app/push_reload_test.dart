import 'dart:async';

import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/app/app.dart';
import 'package:carcare_customer_mobile/core/notifications/remote_push_service.dart';
import 'package:carcare_customer_mobile/features/auth/domain/account.dart';
import 'package:carcare_customer_mobile/features/auth/domain/auth_repository.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/availability.dart';
import 'package:carcare_customer_mobile/features/booking/domain/walk_in_order.dart';
import 'package:carcare_customer_mobile/features/discovery/data/fake_organization_repository.dart';
import 'package:carcare_customer_mobile/features/history/data/fake_service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/cancelled_appointment_summary.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Push service whose foreground (`onMessage`) stream the test drives —
/// `notification_deep_link_test.dart`'s `_ControllablePush` only exposes the
/// tap (`onMessageOpenedApp`) stream, which isn't enough to test the
/// reload-on-arrival path this file covers.
class _ControllableForegroundPush implements RemotePushService {
  final _incoming = StreamController<RemoteMessage>.broadcast();

  void arrive(Map<String, dynamic> data) =>
      _incoming.add(RemoteMessage(data: data));

  @override
  Stream<RemoteMessage> get onMessage => _incoming.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedApp => const Stream.empty();

  @override
  Future<RemoteMessage?> getInitialMessage() async => null;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
}

class _AuthedRepo implements AuthRepository {
  @override
  Stream<void> get onSessionInvalidated => const Stream.empty();

  @override
  Future<Account?> restoreSession() async =>
      const Account(id: '1', phone: '99112233');

  @override
  Future<void> requestOtp(String phone) async {}

  @override
  Future<Account> verifyOtp({
    required String phone,
    required String code,
    String? name,
  }) async => const Account(id: '1', phone: '99112233');

  @override
  Future<void> signOut() async {}
}

/// Wraps [FakeAppointmentRepository], counting `getAppointments()` calls —
/// the method `AppointmentsController.load()` actually calls — so a test can
/// assert a reload really happened instead of just that the app didn't crash.
class _CountingAppointmentRepository implements AppointmentRepository {
  _CountingAppointmentRepository(this._inner);

  final FakeAppointmentRepository _inner;
  int getAppointmentsCallCount = 0;

  @override
  Future<List<Appointment>> getAppointments() {
    getAppointmentsCallCount++;
    return _inner.getAppointments();
  }

  @override
  Future<DayAvailability> getAvailability({
    required String branchId,
    required DateTime date,
    List<String> categoryIds = const [],
  }) => _inner.getAvailability(
    branchId: branchId,
    date: date,
    categoryIds: categoryIds,
  );

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
    List<String> categoryIds = const [],
  }) => _inner.createAppointment(
    branchId: branchId,
    requestedAt: requestedAt,
    note: note,
    accountVehicleId: accountVehicleId,
    categoryIds: categoryIds,
  );

  @override
  Future<List<WalkInOrder>> getWalkInOrders() => _inner.getWalkInOrders();

  @override
  Future<void> cancelAppointment(String id) => _inner.cancelAppointment(id);

  @override
  Future<AppointmentPayment?> getPayment(String appointmentId) =>
      _inner.getPayment(appointmentId);

  @override
  Future<AppointmentPaymentCheckResult> checkPayment(String appointmentId) =>
      _inner.checkPayment(appointmentId);

  @override
  Future<AppointmentPayment?> retryPayment(String appointmentId) =>
      _inner.retryPayment(appointmentId);
}

/// Wraps [FakeServiceHistoryRepository], counting `getServiceHistory()`
/// calls — the method `HistoryController.load()` actually calls.
class _CountingHistoryRepository implements ServiceHistoryRepository {
  _CountingHistoryRepository(this._inner);

  final FakeServiceHistoryRepository _inner;
  int getServiceHistoryCallCount = 0;

  @override
  Future<ServiceHistoryPage> getServiceHistory({HistoryFilter filter = const HistoryFilter()}) {
    getServiceHistoryCallCount++;
    return _inner.getServiceHistory(filter: filter);
  }

  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) =>
      _inner.getServiceOrderDetail(id);

  @override
  Future<List<CancelledAppointmentSummary>> getCancelledAppointments() =>
      _inner.getCancelledAppointments();
}

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'a terminal push type (order_completed) reloads both Appointments and History',
    (tester) async {
      final push = _ControllableForegroundPush();
      final appointments = _CountingAppointmentRepository(
        FakeAppointmentRepository(),
      );
      final history = _CountingHistoryRepository(
        FakeServiceHistoryRepository(),
      );
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: _AuthedRepo(),
          appointmentRepository: appointments,
          historyRepository: history,
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      // Baseline: both already loaded once on login/startup.
      final appointmentsBefore = appointments.getAppointmentsCallCount;
      final historyBefore = history.getServiceHistoryCallCount;
      expect(appointmentsBefore, greaterThan(0));
      expect(historyBefore, greaterThan(0));

      push.arrive(const {
        'type': 'order_completed',
        'orderId': 'order-1',
        'appointmentId': 'seed-1',
      });
      await tester.pumpAndSettle();

      expect(
        appointments.getAppointmentsCallCount,
        greaterThan(appointmentsBefore),
      );
      expect(
        history.getServiceHistoryCallCount,
        greaterThan(historyBefore),
      );
    },
  );

  testWidgets(
    'an active-only push type (order_in_progress) reloads only Appointments',
    (tester) async {
      final push = _ControllableForegroundPush();
      final appointments = _CountingAppointmentRepository(
        FakeAppointmentRepository(),
      );
      final history = _CountingHistoryRepository(
        FakeServiceHistoryRepository(),
      );
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: _AuthedRepo(),
          appointmentRepository: appointments,
          historyRepository: history,
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      final appointmentsBefore = appointments.getAppointmentsCallCount;
      final historyBefore = history.getServiceHistoryCallCount;

      push.arrive(const {
        'type': 'order_in_progress',
        'orderId': 'order-1',
        'appointmentId': 'seed-1',
      });
      await tester.pumpAndSettle();

      expect(
        appointments.getAppointmentsCallCount,
        greaterThan(appointmentsBefore),
      );
      // History is untouched — order_in_progress doesn't move anything
      // between the active list and History.
      expect(history.getServiceHistoryCallCount, historyBefore);
    },
  );

  testWidgets(
    'a broadcast push reloads neither Appointments nor History',
    (tester) async {
      final push = _ControllableForegroundPush();
      final appointments = _CountingAppointmentRepository(
        FakeAppointmentRepository(),
      );
      final history = _CountingHistoryRepository(
        FakeServiceHistoryRepository(),
      );
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: _AuthedRepo(),
          appointmentRepository: appointments,
          historyRepository: history,
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      final appointmentsBefore = appointments.getAppointmentsCallCount;
      final historyBefore = history.getServiceHistoryCallCount;

      push.arrive(const {'type': 'feedback_replied_account'});
      await tester.pumpAndSettle();

      expect(appointments.getAppointmentsCallCount, appointmentsBefore);
      expect(history.getServiceHistoryCallCount, historyBefore);
    },
  );

  testWidgets(
    'resuming from background reconciles both lists even without a push',
    (tester) async {
      final push = _ControllableForegroundPush();
      final appointments = _CountingAppointmentRepository(
        FakeAppointmentRepository(),
      );
      final history = _CountingHistoryRepository(
        FakeServiceHistoryRepository(),
      );
      await tester.pumpWidget(
        CarCareCustomerApp(
          organizationRepository: FakeOrganizationRepository(),
          authRepository: _AuthedRepo(),
          appointmentRepository: appointments,
          historyRepository: history,
          remotePushService: push,
        ),
      );
      await tester.pumpAndSettle();

      final appointmentsBefore = appointments.getAppointmentsCallCount;
      final historyBefore = history.getServiceHistoryCallCount;

      // Simulate the app going to background and coming back — no push
      // involved at all, this is the missed-push safety net.
      // The lifecycle state machine only allows linear steps
      // (resumed <-> inactive <-> hidden <-> paused) — going to background
      // and back has to walk the whole chain both ways, or Flutter's
      // AppLifecycleListener trips an assertion on the "invalid" jump.
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(
        appointments.getAppointmentsCallCount,
        greaterThan(appointmentsBefore),
      );
      expect(
        history.getServiceHistoryCallCount,
        greaterThan(historyBefore),
      );
    },
  );
}
