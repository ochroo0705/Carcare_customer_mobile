import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    this.branchId,
    this.note,
    this.categoryName,
    this.vehiclePlate,
    this.payment,
    this.serviceProgress,
  });

  final String id;
  final AppointmentStatus status;
  final DateTime requestedAt;
  final String tenantName;
  final String tenantSlug;
  final String branchName;
  // Шилжүүлэх (reschedule) урсгалд шаардлагатай — тухайн салбарын боломжит
  // цаг татахад ашиглана. Хуучин кэшлэгдсэн бичлэгт байхгүй байж болзошгүй.
  final String? branchId;
  final String? note;
  final String? categoryName;
  final String? vehiclePlate;

  /// The QPay booking fee for this appointment, or `null` if none is
  /// required (fee feature disabled, or already fully paid — a paid fee
  /// still round-trips as `AppointmentPayment(status: paid, ...)`, not
  /// `null`, so a paid badge can still be shown).
  final AppointmentPayment? payment;

  /// Progress for the ServiceOrder created after staff confirms this booking.
  /// It is absent while the appointment has not yet become an order, and may
  /// also be absent on an offline cached appointment.
  final AppointmentServiceProgress? serviceProgress;

  /// Хураамжийг төлөх боломжтой эсэх — цорын ганц эх сурвалж (detail + list
  /// хоёулаа үүнийг ашиглана). Зөвхөн (1) цаг захиалга идэвхтэй (pending/
  /// confirmed) — цуцалсан/татгалзсан/ирээгүй бол төлбөр утгагүй, (2) хураамж
  /// шаардлагатай, (3) бүрэн төлөгдөөгүй үед л зөвшөөрнө. Server эцсийн
  /// шалгалтыг өөрөө хийдэг; энэ нь UI-г буруу төлөвт харуулахаас сэргийлнэ.
  bool get canPayFee =>
      status.isActive &&
      payment != null &&
      payment!.status != AppointmentFeeStatus.paid;

  /// Захиалгаа өөр хугацаанд шилжүүлэх боломжтой эсэх — идэвхтэй (pending/
  /// confirmed) ба ХАРИН ажилтан аль хэдийн засварын хуудас (ServiceOrder)
  /// нээсэн бол үгүй (тэр цагт байгууллагатай шууд холбогдох ёстой — веб
  /// талын `rescheduleAppointmentByAccount`-тай ижил дүрэм).
  bool get canReschedule => status.isActive && serviceProgress == null;

  Appointment copyWith({
    AppointmentStatus? status,
    DateTime? requestedAt,
    AppointmentPayment? payment,
    AppointmentServiceProgress? serviceProgress,
  }) => Appointment(
    id: id,
    status: status ?? this.status,
    requestedAt: requestedAt ?? this.requestedAt,
    tenantName: tenantName,
    tenantSlug: tenantSlug,
    branchName: branchName,
    branchId: branchId,
    note: note,
    categoryName: categoryName,
    vehiclePlate: vehiclePlate,
    payment: payment ?? this.payment,
    serviceProgress: serviceProgress ?? this.serviceProgress,
  );
}
