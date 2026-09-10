import 'package:carcare_customer_mobile/features/history/domain/service_order_item.dart'
    show ServiceOrderItemKind;

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
  postponed,
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
    // Backend renamed WAITING_PARTS -> POSTPONED (carcare.mn migration
    // 20260910160000): postponed now covers any pause reason, not just
    // parts. Old label kept as fallback only if a stale value ever appears.
    case 'POSTPONED':
    case 'WAITING_PARTS':
      return ServiceProgressStatus.postponed;
    case 'COMPLETED':
      return ServiceProgressStatus.completed;
    case 'CANCELLED':
      return ServiceProgressStatus.cancelled;
    default:
      return ServiceProgressStatus.unknown;
  }
}

/// D-078's postpone reason tags — same fixed enum the staff web uses, safe to
/// show to the customer (unlike the free-text `reason`, which the backend
/// never sends to `/api/v1/app/*`; see CUSTOMER_API_CONTRACT.md, D-079).
enum OrderPostponeReasonTag {
  waitingParts,
  waitingCustomer,
  needsDiagnosis,
  other,
}

OrderPostponeReasonTag? orderPostponeReasonTagFromApi(String? value) =>
    switch (value) {
      'WAITING_PARTS' => OrderPostponeReasonTag.waitingParts,
      'WAITING_CUSTOMER' => OrderPostponeReasonTag.waitingCustomer,
      'NEEDS_DIAGNOSIS' => OrderPostponeReasonTag.needsDiagnosis,
      'OTHER' => OrderPostponeReasonTag.other,
      _ => null,
    };

extension OrderPostponeReasonTagUi on OrderPostponeReasonTag {
  String get localizedLabel => switch (this) {
    OrderPostponeReasonTag.waitingParts => 'Сэлбэг хүлээж байна',
    OrderPostponeReasonTag.waitingCustomer =>
      'Үйлчлүүлэгчийн шийдвэр хүлээж байна',
    OrderPostponeReasonTag.needsDiagnosis => 'Нэмэлт оношилгоо шаардлагатай',
    OrderPostponeReasonTag.other => 'Бусад',
  };
}

/// One entry of a `ServiceOrder`'s customer-safe status timeline
/// (`statusHistory` in the API — D-079). `fromStatus` is null for the
/// order's first transition.
class OrderStatusHistoryEntry {
  const OrderStatusHistoryEntry({
    required this.id,
    required this.toStatus,
    required this.createdAt,
    this.fromStatus,
    this.reasonTag,
  });

  final String id;
  final ServiceProgressStatus? fromStatus;
  final ServiceProgressStatus toStatus;
  final OrderPostponeReasonTag? reasonTag;
  final DateTime createdAt;
}

extension ServiceProgressStatusUi on ServiceProgressStatus {
  String get localizedLabel => switch (this) {
    ServiceProgressStatus.pending => 'Хүлээгдэж буй',
    ServiceProgressStatus.scheduled => 'Товлогдсон',
    ServiceProgressStatus.inProgress => 'Хийгдэж байна',
    ServiceProgressStatus.postponed => 'Хойшлогдсон',
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
    this.kind = ServiceOrderItemKind.labor,
    this.quantity,
    this.unitPrice,
    this.total,
  });

  final String id;
  final String name;
  final ServiceProgressStatus status;
  final ServiceOrderItemKind kind;
  final num? quantity;
  final num? unitPrice;
  final num? total;
}

class AppointmentServiceProgress {
  const AppointmentServiceProgress({
    required this.id,
    required this.number,
    required this.status,
    required this.items,
    this.paymentStatus = OrderPaymentStatus.unknown,
    this.scheduledAt,
    this.startedAt,
    this.completedAt,
    this.estimatedDurationMinutes,
    this.expectedFinishAt,
    this.totalAmount,
    this.paidAmount,
    this.vehiclePlate,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleYear,
    this.statusHistory = const [],
    this.scheduledReturnAt,
  });

  final String id;
  final String number;
  final ServiceProgressStatus status;
  final OrderPaymentStatus paymentStatus;
  // Ажил хараахан эхлээгүй (SCHEDULED) үед л утгатай — эхэлмэгц startedAt
  // тэргүүлнэ, ажилтан шилжүүлбэл энэ утга шинэчлэгдэнэ (order_rescheduled
  // мэдэгдэл, харах: carcare.mn lib/notifications.ts).
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  // Захиалга үүсэх үеийн анхны тооцоолол (минут) — immutable, категори
  // дараа өөрчлөгдсөн ч энэ хуучин утга хэвээр үлдэнэ.
  final int? estimatedDurationMinutes;
  // Ажилтны шинэчилж болох дуусах хугацааны таамаг — completedAt-той андуурч
  // болохгүй, ажил дуусаагүй байхад ч байж болно (эсвэл хэтэрсэн байж болно).
  final DateTime? expectedFinishAt;
  final num? totalAmount;
  final num? paidAmount;
  // Захиалга үүсэх үед snapshot хийгдсэн машин — захиалгагүй үед
  // Appointment.accountVehicle-ээс тусад нь харагдана (AppointmentDto-д).
  final String? vehiclePlate;
  final String? vehicleMake;
  final String? vehicleModel;
  final int? vehicleYear;
  final List<AppointmentServiceItemProgress> items;
  // Newest first, per the API contract (D-079).
  final List<OrderStatusHistoryEntry> statusHistory;
  // The car's return time while `status` is `postponed` (D-080) — a separate
  // `OrderTimeBooking` row, not `scheduledAt` (the order's original booking
  // time). Null for every other status.
  final DateTime? scheduledReturnAt;

  int get completedItemCount =>
      items.where((item) => item.status.isCompleted).length;

  double get completionRatio => items.isEmpty
      ? (status.isCompleted ? 1 : 0)
      : completedItemCount / items.length;

  /// Ажил бүрэн дуусаад бүрэн төлөгдсөн эсэх. Ийм аппойнтмент цаашид
  /// "Миний захиалгууд" дээр харагдахгүй — түүхэнд шилждэг (server талд
  /// /api/v1/app/appointments аль хэдийн шүүсэн байх ёстой ч client талд ч
  /// давхар шалгаж, кэшлэгдсэн хуучин датаг найдваргүй харуулахаас сэргийлнэ).
  bool get isSettled =>
      status.isCompleted && paymentStatus == OrderPaymentStatus.paid;

  /// Тооцоолсон дуусах хугацаанаас хэтэрсэн ч ажил хараахан дуусаагүй эсэх.
  /// Хойшлогдсон (postponed) захиалгад хуучин таамаг хамааралгүй болсон тул
  /// хэзээ ч "хожимдсон" гэж тооцохгүй — шинэ буцах цаг үүнийг орлоно (D-081).
  bool get isDelayed =>
      !status.isCompleted &&
      status != ServiceProgressStatus.cancelled &&
      status != ServiceProgressStatus.postponed &&
      expectedFinishAt != null &&
      expectedFinishAt!.isBefore(DateTime.now());
}
