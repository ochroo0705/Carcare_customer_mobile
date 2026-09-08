/// Захиалгын PAYMENT статус (workflow-той тусдаа). Аппойнтмент бүрэн
/// дуусаад бүрэн төлөгдсөн эсэхийг шийдэхэд ашиглагдана — доор харах:
/// [AppointmentServiceProgress.isSettled].
enum OrderPaymentStatus { unpaid, partiallyPaid, paid, unknown }

OrderPaymentStatus orderPaymentStatusFromApi(String? value) => switch (value) {
  'UNPAID' => OrderPaymentStatus.unpaid,
  'PARTIAL' => OrderPaymentStatus.partiallyPaid,
  'PAID' => OrderPaymentStatus.paid,
  _ => OrderPaymentStatus.unknown,
};

/// Customer-safe workflow statuses for a linked service order and its items.
/// Payment status is deliberately separate from this model.
enum ServiceProgressStatus {
  pending,
  scheduled,
  inProgress,
  waitingParts,
  completed,
  cancelled,
  unknown,
}

ServiceProgressStatus serviceProgressStatusFromApi(String value) {
  switch (value) {
    case 'PENDING':
      return ServiceProgressStatus.pending;
    case 'SCHEDULED':
      return ServiceProgressStatus.scheduled;
    case 'IN_PROGRESS':
      return ServiceProgressStatus.inProgress;
    case 'WAITING_PARTS':
      return ServiceProgressStatus.waitingParts;
    case 'COMPLETED':
      return ServiceProgressStatus.completed;
    case 'CANCELLED':
      return ServiceProgressStatus.cancelled;
    default:
      return ServiceProgressStatus.unknown;
  }
}

extension ServiceProgressStatusUi on ServiceProgressStatus {
  String get localizedLabel => switch (this) {
    ServiceProgressStatus.pending => 'Хүлээгдэж буй',
    ServiceProgressStatus.scheduled => 'Товлогдсон',
    ServiceProgressStatus.inProgress => 'Хийгдэж байна',
    ServiceProgressStatus.waitingParts => 'Сэлбэг хүлээж буй',
    ServiceProgressStatus.completed => 'Дууссан',
    ServiceProgressStatus.cancelled => 'Цуцлагдсан',
    ServiceProgressStatus.unknown => 'Тодорхойгүй',
  };

  bool get isCompleted => this == ServiceProgressStatus.completed;
}

class AppointmentServiceItemProgress {
  const AppointmentServiceItemProgress({
    required this.id,
    required this.name,
    required this.status,
  });

  final String id;
  final String name;
  final ServiceProgressStatus status;
}

class AppointmentServiceProgress {
  const AppointmentServiceProgress({
    required this.id,
    required this.number,
    required this.status,
    required this.items,
    this.paymentStatus = OrderPaymentStatus.unknown,
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String number;
  final ServiceProgressStatus status;
  final OrderPaymentStatus paymentStatus;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<AppointmentServiceItemProgress> items;

  int get completedItemCount =>
      items.where((item) => item.status.isCompleted).length;

  double get completionRatio => items.isEmpty
      ? (status.isCompleted ? 1 : 0)
      : completedItemCount / items.length;

  /// Ажил бүрэн дуусаад бүрэн төлөгдсөн эсэх. Ийм аппойнтмент цаашид
  /// "Миний цагууд" дээр харагдахгүй — түүхэнд шилждэг (server талд
  /// /api/v1/app/appointments аль хэдийн шүүсэн байх ёстой ч client талд ч
  /// давхар шалгаж, кэшлэгдсэн хуучин датаг найдваргүй харуулахаас сэргийлнэ).
  bool get isSettled =>
      status.isCompleted && paymentStatus == OrderPaymentStatus.paid;
}
