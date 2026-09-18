/// Backend-ийн appointment status-ийг client талын UI төлөвт хөрвүүлнэ.
/// Энд service completed төлөв байхгүй — `CONFIRMED` нь зөвхөн цаг
/// баталгаажсаныг илэрхийлнэ, үйлчилгээ дууссаныг биш.
enum AppointmentStatus {
  pending,
  confirmed,
  rejected,
  cancelled,
  noShow,
  unknown,
}

AppointmentStatus appointmentStatusFromApi(String value) => switch (value) {
  'PENDING' => AppointmentStatus.pending,
  'CONFIRMED' => AppointmentStatus.confirmed,
  'REJECTED' => AppointmentStatus.rejected,
  'CANCELLED' => AppointmentStatus.cancelled,
  'NO_SHOW' => AppointmentStatus.noShow,
  _ => AppointmentStatus.unknown,
};

extension AppointmentStatusUi on AppointmentStatus {
  /// Зөвхөн PENDING/CONFIRMED appointment нь одоо үргэлжилж буй хүсэлт гэж
  /// үзэгдэнэ. Цуцлах эрхийн эцсийн шалгалтыг server хийдэг.
  bool get isActive =>
      this == AppointmentStatus.pending || this == AppointmentStatus.confirmed;

  /// ЗӨВХӨН төлвийн шалгалт. UI-д ШУУД БҮҮ АШИГЛА — `Appointment.canCancel`-ыг
  /// хэрэглэ. Ажилтан баталгаажуулж ServiceOrder үүсгэсний дараа ч төлөв
  /// `CONFIRMED` хэвээр тул энэ нь `true` буцаасаар байх ба цуцлах товч
  /// буруугаар харагдана (харах: `Appointment.canCancel`-ийн тайлбар).
  bool get canCancel => isActive;

  String get localizedLabel => switch (this) {
    AppointmentStatus.pending => 'Хүлээгдэж буй',
    AppointmentStatus.confirmed => 'Баталгаажсан',
    AppointmentStatus.rejected => 'Татгалзсан',
    AppointmentStatus.cancelled => 'Цуцалсан',
    AppointmentStatus.noShow => 'Ирээгүй',
    AppointmentStatus.unknown => 'Тодорхойгүй',
  };
}
