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
