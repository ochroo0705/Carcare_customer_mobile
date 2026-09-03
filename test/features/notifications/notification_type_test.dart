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
