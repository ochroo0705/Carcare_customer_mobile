/// A terminal, never-fulfilled appointment (D-085) — cancelled, no-showed, or
/// rejected before a `ServiceOrder` ever existed, so it can never appear as a
/// [ServiceOrder] entry in history. Lightweight by design: there is no
/// service work, items, or pricing to show, only that it happened.
enum CancelledAppointmentStatus { cancelled, noShow, rejected }

CancelledAppointmentStatus? cancelledAppointmentStatusFromApi(String? value) =>
    switch (value) {
      'CANCELLED' => CancelledAppointmentStatus.cancelled,
      'NO_SHOW' => CancelledAppointmentStatus.noShow,
      'REJECTED' => CancelledAppointmentStatus.rejected,
      _ => null,
    };

extension CancelledAppointmentStatusUi on CancelledAppointmentStatus {
  String get localizedLabel => switch (this) {
    CancelledAppointmentStatus.cancelled => 'Цуцлагдсан',
    CancelledAppointmentStatus.noShow => 'Ирээгүй',
    CancelledAppointmentStatus.rejected => 'Татгалзсан',
  };
}

class CancelledAppointmentSummary {
  const CancelledAppointmentSummary({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.tenantName,
    required this.branchName,
    this.categoryName,
  });

  final String id;
  final CancelledAppointmentStatus status;
  final DateTime requestedAt;
  final String tenantName;
  final String branchName;
  final String? categoryName;
}
