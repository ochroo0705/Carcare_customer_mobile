enum NotificationType {
  appointmentConfirmed,
  appointmentRejected,
  appointmentReminder,
  appointmentExpired,
  feedbackReplied,
  broadcast,
}

/// Maps the backend's `data.type` values (`carcare.mn/lib/notifications.ts`,
/// `NOTIFICATION_REGISTRY`) to the domain enum. Only the **account-realm**
/// types ever reach the customer app; the staff/system types
/// (`appointment_created`, `broadcast_staff`, …) and anything unrecognized
/// (including a missing `type`) fall back to [NotificationType.broadcast]
/// rather than throwing — the payload shape is server-controlled and may grow.
NotificationType notificationTypeFromPushData(String? value) => switch (value) {
  'appointment_confirmed' => NotificationType.appointmentConfirmed,
  'appointment_rejected' => NotificationType.appointmentRejected,
  'appointment_reminder' => NotificationType.appointmentReminder,
  'appointment_expired' => NotificationType.appointmentExpired,
  'feedback_replied_account' => NotificationType.feedbackReplied,
  _ => NotificationType.broadcast, // incl. 'broadcast_account' + unknown/null
};

extension NotificationTypeUi on NotificationType {
  String get localizedLabel => switch (this) {
    NotificationType.appointmentConfirmed => 'Цаг баталгаажлаа',
    NotificationType.appointmentRejected => 'Цаг батлагдсангүй',
    NotificationType.appointmentReminder => 'Сануулга',
    NotificationType.appointmentExpired => 'Цаг цуцлагдлаа',
    NotificationType.feedbackReplied => 'Санал хүсэлтэд хариу ирсэн',
    NotificationType.broadcast => 'Мэдэгдэл',
  };
}
