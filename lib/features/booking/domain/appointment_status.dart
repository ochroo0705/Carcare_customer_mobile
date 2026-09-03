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
