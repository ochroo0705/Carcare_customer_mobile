enum NotificationType {
  appointmentConfirmed,
  appointmentRejected,
  appointmentReminder,
  appointmentExpired,
  appointmentRescheduled,
  appointmentNoShow,
  orderCompleted,
  orderCancelled,
  orderInProgress,
  orderPaymentReceived,
  orderRescheduled,
  expectedFinishRevised,
  serviceReminder,
  feedbackReplied,
  tenantPromo,
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
  'appointment_rescheduled' => NotificationType.appointmentRescheduled,
  'appointment_no_show' => NotificationType.appointmentNoShow,
  'order_completed' => NotificationType.orderCompleted,
  'order_cancelled' => NotificationType.orderCancelled,
  'order_in_progress' => NotificationType.orderInProgress,
  'order_payment_received' => NotificationType.orderPaymentReceived,
  'order_rescheduled' => NotificationType.orderRescheduled,
  'expected_finish_revised' => NotificationType.expectedFinishRevised,
  'service_reminder' => NotificationType.serviceReminder,
  'feedback_replied_account' => NotificationType.feedbackReplied,
  'tenant_promo' => NotificationType.tenantPromo,
  _ => NotificationType.broadcast, // incl. 'broadcast_account' + unknown/null
};

extension NotificationTypeUi on NotificationType {
  String get localizedLabel => switch (this) {
    NotificationType.appointmentConfirmed => 'Цаг баталгаажлаа',
    NotificationType.appointmentRejected => 'Цаг батлагдсангүй',
    NotificationType.appointmentReminder => 'Сануулга',
    NotificationType.appointmentExpired => 'Цаг цуцлагдлаа',
    NotificationType.appointmentRescheduled => 'Цаг шилжсэн',
    NotificationType.appointmentNoShow => 'Цагт ирээгүй',
    NotificationType.orderCompleted => 'Захиалга дууссан',
    NotificationType.orderCancelled => 'Захиалга цуцлагдсан',
    NotificationType.orderInProgress => 'Ажил эхэлсэн',
    NotificationType.orderPaymentReceived => 'Төлбөр хүлээн авсан',
    NotificationType.orderRescheduled => 'Товлосон огноо шилжсэн',
    NotificationType.expectedFinishRevised => 'Дуусах хугацаа шинэчлэгдсэн',
    NotificationType.serviceReminder => 'Үйлчилгээний сануулга',
    NotificationType.feedbackReplied => 'Санал хүсэлтэд хариу ирсэн',
    NotificationType.tenantPromo => 'Байгууллагын зар',
    NotificationType.broadcast => 'Мэдэгдэл',
  };
}
