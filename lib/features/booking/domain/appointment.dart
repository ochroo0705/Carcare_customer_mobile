import 'package:carcare_customer_mobile/features/booking/domain/appointment_payment.dart';
import 'package:carcare_customer_mobile/features/booking/domain/appointment_status.dart';

class Appointment {
  const Appointment({
    required this.id,
    required this.status,
    required this.requestedAt,
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    this.note,
    this.categoryName,
    this.vehiclePlate,
    this.payment,
  });

  final String id;
  final AppointmentStatus status;
  final DateTime requestedAt;
  final String tenantName;
  final String tenantSlug;
  final String branchName;
  final String? note;
  final String? categoryName;
  final String? vehiclePlate;

  /// The QPay booking fee for this appointment, or `null` if none is
  /// required (fee feature disabled, or already fully paid — a paid fee
  /// still round-trips as `AppointmentPayment(status: paid, ...)`, not
  /// `null`, so a paid badge can still be shown).
  final AppointmentPayment? payment;

  /// Хураамжийг төлөх боломжтой эсэх — цорын ганц эх сурвалж (detail + list
  /// хоёулаа үүнийг ашиглана). Зөвхөн (1) цаг захиалга идэвхтэй (pending/
  /// confirmed) — цуцалсан/татгалзсан/ирээгүй бол төлбөр утгагүй, (2) хураамж
  /// шаардлагатай, (3) бүрэн төлөгдөөгүй үед л зөвшөөрнө. Server эцсийн
  /// шалгалтыг өөрөө хийдэг; энэ нь UI-г буруу төлөвт харуулахаас сэргийлнэ.
  bool get canPayFee =>
      status.isActive &&
      payment != null &&
      payment!.status != AppointmentFeeStatus.paid;

  Appointment copyWith({
    AppointmentStatus? status,
    AppointmentPayment? payment,
  }) => Appointment(
    id: id,
    status: status ?? this.status,
    requestedAt: requestedAt,
    tenantName: tenantName,
    tenantSlug: tenantSlug,
    branchName: branchName,
    note: note,
    categoryName: categoryName,
    vehiclePlate: vehiclePlate,
    payment: payment ?? this.payment,
  );
}
