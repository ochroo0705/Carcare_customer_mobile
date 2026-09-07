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
    this.startedAt,
    this.completedAt,
  });

  final String id;
  final String number;
  final ServiceProgressStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<AppointmentServiceItemProgress> items;

  int get completedItemCount =>
      items.where((item) => item.status.isCompleted).length;

  double get completionRatio => items.isEmpty
      ? (status.isCompleted ? 1 : 0)
      : completedItemCount / items.length;
}
