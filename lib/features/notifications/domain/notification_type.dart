enum NotificationType {
  appointmentConfirmed,
  appointmentRejected,
  appointmentReminder,
  broadcast,
}

/// Maps the `data.type` values documented in
/// `carcare.mn/docs/mobile-device-push.md` §4 ("Push мессежийн бүтэц") to the
/// domain enum. Anything else (including no `type` at all) falls back to
/// [NotificationType.broadcast] rather than throwing — the push payload
/// shape is server-controlled and may grow new types over time.
NotificationType notificationTypeFromPushData(String? value) => switch (value) {
  'appointment_confirmed' => NotificationType.appointmentConfirmed,
  'appointment_reminder' => NotificationType.appointmentReminder,
  _ => NotificationType.broadcast,
};

extension NotificationTypeUi on NotificationType {
  String get localizedLabel => switch (this) {
    NotificationType.appointmentConfirmed => 'Цаг баталгаажлаа',
    NotificationType.appointmentRejected => 'Цаг татгалзсан',
    NotificationType.appointmentReminder => 'Сануулга',
    NotificationType.broadcast => 'Мэдэгдэл',
  };
}
