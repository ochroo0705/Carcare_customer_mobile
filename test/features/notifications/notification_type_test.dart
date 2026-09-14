import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps every account-realm push type', () {
    expect(
      notificationTypeFromPushData('appointment_confirmed'),
      NotificationType.appointmentConfirmed,
    );
    expect(
      notificationTypeFromPushData('appointment_rejected'),
      NotificationType.appointmentRejected,
    );
    expect(
      notificationTypeFromPushData('appointment_reminder'),
      NotificationType.appointmentReminder,
    );
    expect(
      notificationTypeFromPushData('appointment_expired'),
      NotificationType.appointmentExpired,
    );
    expect(
      notificationTypeFromPushData('appointment_rescheduled'),
      NotificationType.appointmentRescheduled,
    );
    expect(
      notificationTypeFromPushData('appointment_no_show'),
      NotificationType.appointmentNoShow,
    );
    expect(
      notificationTypeFromPushData('order_completed'),
      NotificationType.orderCompleted,
    );
    expect(
      notificationTypeFromPushData('order_cancelled'),
      NotificationType.orderCancelled,
    );
    expect(
      notificationTypeFromPushData('order_in_progress'),
      NotificationType.orderInProgress,
    );
    expect(
      notificationTypeFromPushData('order_payment_received'),
      NotificationType.orderPaymentReceived,
    );
    expect(
      notificationTypeFromPushData('order_rescheduled'),
      NotificationType.orderRescheduled,
    );
    expect(
      notificationTypeFromPushData('expected_finish_revised'),
      NotificationType.expectedFinishRevised,
    );
    expect(
      notificationTypeFromPushData('feedback_replied_account'),
      NotificationType.feedbackReplied,
    );
    expect(
      notificationTypeFromPushData('broadcast_account'),
      NotificationType.broadcast,
    );
  });

  test('falls back to broadcast for staff/system, unknown, and null', () {
    // Staff-realm types the customer app should never receive.
    expect(
      notificationTypeFromPushData('appointment_created'),
      NotificationType.broadcast,
    );
    // Staff-facing "customer cancelled" notice — distinct from the
    // account-realm order_cancelled/appointment lifecycle types above.
    expect(
      notificationTypeFromPushData('appointment_cancelled'),
      NotificationType.broadcast,
    );
    expect(
      notificationTypeFromPushData('broadcast_staff'),
      NotificationType.broadcast,
    );
    // Unknown / future / missing.
    expect(
      notificationTypeFromPushData('something_new'),
      NotificationType.broadcast,
    );
    expect(notificationTypeFromPushData(null), NotificationType.broadcast);
    expect(notificationTypeFromPushData(''), NotificationType.broadcast);
  });
}
