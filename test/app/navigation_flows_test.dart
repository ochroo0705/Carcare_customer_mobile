import 'package:carcare_customer_mobile/app/bootstrap_flags.dart';
import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/auth/data/fake_auth_repository.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/auth_controller.dart';
import 'package:carcare_customer_mobile/features/auth/presentation/login_screen.dart';
import 'package:carcare_customer_mobile/features/booking/data/fake_appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_repository.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_detail_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/appointment_payment_screen.dart';
import 'package:carcare_customer_mobile/features/booking/presentation/screens/booking_request_screen.dart';
import 'package:carcare_customer_mobile/features/discovery/presentation/screens/organization_detail_screen.dart';
import 'package:carcare_customer_mobile/features/history/presentation/screens/service_order_detail_screen.dart';
import 'package:carcare_customer_mobile/features/history/presentation/widgets/diagnostic_report_row.dart';
import 'package:carcare_customer_mobile/features/diagnostics/presentation/screens/diagnostic_detail_screen.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:carcare_customer_mobile/features/profile/presentation/screens/account_closure_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/add_vehicle_screen.dart';
import 'package:carcare_customer_mobile/features/vehicles/presentation/screens/vehicle_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_harness.dart';

/// Fails the FIRST `createAppointment` call with [UnauthenticatedFailure]
/// (simulating a 401 from an expired session the client hasn't noticed yet),
/// then behaves like the base fake for every call after. Used to exercise
/// `BookingRequestScreen.onUnauthenticated` → the router's login-then-resume
/// path, which `FakeAppointmentRepository` alone never triggers.
class _UnauthenticatedOnceAppointmentRepository
    extends FakeAppointmentRepository {
  bool _thrown = false;

  @override
  Future<CreatedAppointment> createAppointment({
    required String branchId,
    required DateTime requestedAt,
    String? note,
    String? accountVehicleId,
    List<String> categoryIds = const [],
  }) async {
    if (!_thrown) {
      _thrown = true;
      throw const UnauthenticatedFailure();
    }
    return super.createAppointment(
      branchId: branchId,
      requestedAt: requestedAt,
      note: note,
      accountVehicleId: accountVehicleId,
      categoryIds: categoryIds,
    );
  }
}

void main() {
  setUpAll(() => debugDisableAppBootstrap = true);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Explore list → first branch card → organization detail.
  Future<void> openOrganization(WidgetTester tester) async {
    await openListView(tester);
    await tester.tap(find.text('Auto Doctor Service').first);
    await tester.pumpAndSettle();
    expect(find.byType(OrganizationDetailScreen), findsOneWidget);
  }

  /// Fills the booking form (branch is already locked/preselected by the
  /// Explore → detail → book flow) with the minimum needed for `_submit` to
  /// pass its validation: one category, a future date (next month, day 10,
  /// to dodge any current-month-end edge case), and the first available slot.
  Future<void> fillMinimalBookingForm(WidgetTester tester) async {
    await tester.tap(find.text('Тос солих'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('booking-calendar-next')));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final targetDate = DateTime(now.year, now.month + 1, 10);
    final dateFinder = find.byKey(
      ValueKey(
        'booking-date-${targetDate.year}-${targetDate.month}-${targetDate.day}',
      ),
    );
    await tester.ensureVisible(dateFinder);
    await tester.pumpAndSettle();
    await tester.tap(dateFinder);
    await tester.pumpAndSettle();

    final slot = find.byKey(const ValueKey('booking-slot-9-0'));
    await tester.ensureVisible(slot);
    await tester.pumpAndSettle();
    await tester.tap(slot);
    await tester.pumpAndSettle();
  }

  group('Explore booking', () {
    testWidgets('detail → book → back returns to detail, back again to shell',
        (tester) async {
      await pumpApp(tester);
      await openOrganization(tester);
      await tester.tap(find.byKey(const ValueKey('detail-book-button')));
      await tester.pumpAndSettle();
      expect(find.byType(BookingRequestScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(BookingRequestScreen), findsNothing);
      expect(find.byType(OrganizationDetailScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(OrganizationDetailScreen), findsNothing);
    });

    // Deliberate behaviour change #3 (a bug fix, not a preserved quirk): the
    // old delegate had no auth guard on the booking page at all — tapping
    // "book" while signed out was a no-op from the UI's perspective, since
    // none of the delegate's page conditions matched and the Navigator just
    // kept showing `OrganizationDetailScreen` underneath. That button was
    // effectively dead for a signed-out customer. `customerRedirect` now
    // guards `/organizations/:slug/book` on `isAuthenticated`, same as every
    // other route in the table, so the tap now does what it always should
    // have: send the customer to `LoginScreen` (with `from` set to the
    // booking URL) instead of doing nothing.
    testWidgets(
        'signed out: tapping book now shows LoginScreen (bug fix — the old '
        'button was dead)', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await openOrganization(tester);
      await tester.tap(find.byKey(const ValueKey('detail-book-button')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BookingRequestScreen), findsNothing);
    });

    // Full flow for the fixed behaviour: signed out → tap book → login →
    // complete OTP → lands on BookingRequestScreen, with exactly one page
    // pushed for the whole sequence (the redirect intercepts the booking
    // push and swaps in LoginScreen; a successful sign-in then
    // `pushReplacement`s that same page with the booking page). One
    // `pageBack` must therefore return straight to `OrganizationDetailScreen`
    // — not to a second booking page, and not back to LoginScreen.
    testWidgets(
        'signed out → book → login → OTP: lands on BookingRequestScreen with '
        'exactly one page pushed', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await openOrganization(tester);
      await tester.tap(find.byKey(const ValueKey('detail-book-button')));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('login-phone')), '99112233');
      await tester.tap(find.text('Код авах →'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
      await tester.tap(find.text('Нэвтрэх →'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      // `find.byType` skips offstage pages by default, so a plain
      // `findsOneWidget` here would not catch a second, offstage
      // `BookingRequestScreen` left underneath (e.g. from `pushReplacement`
      // stacking a new page on top of one that was never popped).
      // `skipOffstage: false` checks the whole page stack, not just what's
      // currently visible.
      expect(
        find.byType(BookingRequestScreen, skipOffstage: false),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(BookingRequestScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(OrganizationDetailScreen), findsOneWidget);
    });

    testWidgets(
        'submit failing with UnauthenticatedFailure shows login; logging in '
        'resumes into booking', (tester) async {
      await pumpApp(
        tester,
        appointments: _UnauthenticatedOnceAppointmentRepository(),
      );
      await openOrganization(tester);
      await tester.tap(find.byKey(const ValueKey('detail-book-button')));
      await tester.pumpAndSettle();

      await fillMinimalBookingForm(tester);
      final submit = find.byKey(const ValueKey('submit-booking'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(BookingRequestScreen), findsNothing);

      // LoginScreen has no onSubmitted wiring on its TextFields — the phone
      // and OTP steps are each advanced by tapping the FilledButton below the
      // field, not by a keyboard "done" action. The brief's
      // `receiveAction(TextInputAction.done)` steps were a no-op against the
      // real screen; fixed to tap the button instead.
      await tester.enterText(
          find.byKey(const ValueKey('login-phone')), '99112233');
      await tester.tap(find.text('Код авах →'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('login-otp')), '123456');
      await tester.tap(find.text('Нэвтрэх →'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsNothing);
      // Same duplicate-page concern as the signed-out flow above: this
      // resumes via a `pop()` back to the booking page that was already
      // mounted underneath `LoginScreen` (not a `pushReplacement`), so
      // check the whole stack, not just what's on top.
      expect(
        find.byType(BookingRequestScreen, skipOffstage: false),
        findsOneWidget,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(BookingRequestScreen), findsNothing);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byType(OrganizationDetailScreen), findsOneWidget);
    });
  });

  group('Service-key booking', () {
    testWidgets('back from booking skips detail and lands on the shell',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Захиалах'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-car-wash')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('service-key-apply')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('service-key-result-auto-doctor-bzd')));
      await tester.pumpAndSettle();
      expect(find.byType(BookingRequestScreen), findsOneWidget);
      expect(find.byType(OrganizationDetailScreen), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(BookingRequestScreen), findsNothing);
      expect(find.byType(OrganizationDetailScreen), findsNothing);
    });
  });

  group('Booking completion', () {
    testWidgets(
        'submit lands on Appointments tab → new appointment detail → payment',
        (tester) async {
      await pumpApp(tester);
      await openOrganization(tester);
      await tester.tap(find.byKey(const ValueKey('detail-book-button')));
      await tester.pumpAndSettle();

      await fillMinimalBookingForm(tester);

      final submit = find.byKey(const ValueKey('submit-booking'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.byType(BookingRequestScreen), findsNothing);
      expect(find.byType(OrganizationDetailScreen), findsNothing);
      expect(find.text('Цагийн хүсэлт амжилттай илгээгдлээ.'), findsOneWidget);
      // Fake repo attaches a pending booking fee → payment on top of detail.
      expect(find.byType(AppointmentPaymentScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('appointments-tab-bar')), findsOneWidget);
    });
  });

  group('Detail pages', () {
    testWidgets('history order → diagnostic → back twice to history',
        (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Түүх'));
      await tester.pumpAndSettle();
      // seed-history-1 is the fake order that actually has a diagnostic
      // report attached (see FakeServiceHistoryRepository._reports) — target
      // it directly rather than "the first order card", which (sorted by
      // completedAt) is a different, report-less seed.
      await tester.tap(
          find.byKey(const ValueKey('history-order-seed-history-1')));
      await tester.pumpAndSettle();
      expect(find.byType(ServiceOrderDetailScreen), findsOneWidget);

      // The section header text ('Оношилгооны тайлан') is not itself
      // tappable — the actual `InkWell` lives on the `DiagnosticReportRow`
      // below it (see `diagnostic_report_row.dart`), so target that widget.
      expect(find.text('Оношилгооны тайлан'), findsOneWidget);
      expect(find.byType(DiagnosticReportRow), findsOneWidget);
      await tester.tap(find.byType(DiagnosticReportRow));
      await tester.pumpAndSettle();
      expect(find.byType(DiagnosticDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ServiceOrderDetailScreen), findsNothing);
      expect(find.byKey(const ValueKey('history-tab-bar')), findsOneWidget);
    });

    testWidgets('profile → add vehicle → back; vehicle detail → back',
        (tester) async {
      await pumpApp(tester);
      await openListView(tester);
      await tester.tap(find.byKey(const ValueKey('shell-avatar')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('profile-add-vehicle-fab')));
      await tester.pumpAndSettle();
      expect(find.byType(AddVehicleScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(AddVehicleScreen), findsNothing);

      // The card shows "plate · year" (fake vehicle has year 2019), not the
      // bare plate the brief's finder assumed — match on the substring.
      await tester.tap(find.textContaining('9911УБЕ').first);
      await tester.pumpAndSettle();
      expect(find.byType(VehicleDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(VehicleDetailScreen), findsNothing);
    });

    testWidgets('bell opens notifications; back closes it', (tester) async {
      await pumpApp(tester);
      await openListView(tester);
      await tester.tap(find.byKey(const ValueKey('shell-notifications')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsNothing);
    });
  });

  group('Push deep link over an open stack', () {
    testWidgets('clears whatever is open, then shows the appointment',
        (tester) async {
      final push = ControllablePush();
      await pumpApp(tester, push: push);
      await openOrganization(tester);

      push.tap(const {'type': 'appointment_confirmed', 'appointmentId': 'seed-1'});
      await tester.pumpAndSettle();

      expect(find.byType(OrganizationDetailScreen), findsNothing);
      expect(find.byType(AppointmentDetailScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('appointments-tab-bar')), findsOneWidget);
    });
  });

  group('Gaps the old delegate handled implicitly (Task 5)', () {
    // Step 2: the old delegate dropped the closure page whenever
    // `_showAccountClosure && isAuthenticated` no longer both held. The
    // router's redirect now covers this the same way it covers the
    // signed-out-tap-book case: `customerRedirect` sends
    // `/account/close` back to the shell whenever `isAuthenticated` is
    // false, and go_router re-evaluates that redirect against the current
    // (topmost) location on every `routerRefresh` notification — including
    // the one `AuthController.signOut()` fires.
    //
    // This only works because closure is the topmost page when sign-out
    // happens; closure has no outgoing links, so nothing can ever be pushed
    // on top of it in the real app, and there is deliberately no test for
    // that unreachable case.
    testWidgets('signing out while the closure page is open removes it',
        (tester) async {
      await pumpApp(tester);
      await openListView(tester);
      await tester.tap(find.byKey(const ValueKey('shell-avatar')));
      await tester.pumpAndSettle();

      final tile = find.byKey(const ValueKey('profile-account-closure-tile'));
      await tester.scrollUntilVisible(
        tile,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(AccountClosureScreen), findsOneWidget);

      final authController =
          tester.element(find.byType(AccountClosureScreen)).read<AuthController>();
      await authController.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(AccountClosureScreen, skipOffstage: false), findsNothing);
    });

    // Step 4: go_router wires Android's system back button to the same pop
    // the app bar's back arrow uses (`Navigator.maybePop` under the hood),
    // so a pushed page closes on system back exactly like it does on a
    // widget-level `pageBack()`.
    testWidgets('Android system back from a pushed page returns',
        (tester) async {
      await pumpApp(tester);
      await openListView(tester);
      await tester.tap(find.byKey(const ValueKey('shell-notifications')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(NotificationsScreen, skipOffstage: false), findsNothing);
    });
  });
}
