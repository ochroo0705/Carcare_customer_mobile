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
    this.note,
    this.categoryNames = const [],
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
  final String? note;

  /// Захиалсан бүх үйлчилгээний ангилал (booking v2). Backend-ийн
  /// `categories` массиваас ирнэ; хуучин ганц `category`-г зөвхөн fallback-д
  /// ашиглана (харах: CUSTOMER_API_CONTRACT.md — "new clients should read
  /// `categories`"). Ангилалгүй захиалгад хоосон.
  final List<String> categoryNames;
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

  /// Цуцлах товчийг харуулах эсэх — UI-ийн цорын ганц эх сурвалж.
  ///
  /// `status.canCancel` нь ЗӨВХӨН төлөв шалгадаг тул шууд бүү ашигла:
  /// ажилтан баталгаажуулж ServiceOrder үүсгэсний дараа ч `CONFIRMED` хэвээр
  /// байх тул тэр нь `true` буцаана. Тэр үед цуцлах нь утгагүй — засвар аль
  /// хэдийн эхэлсэн байж болох ба appointment-ийг цуцлахад холбогдох
  /// ServiceOrder ХӨНДӨГДӨХГҮЙ: үйлчлүүлэгч цуцалсан гэж бодох ч ажил үргэлжилж,
  /// ажилтанд төөрөгдүүлсэн мэдэгдэл очно.
  ///
  /// `serviceProgress` нь захиалга үүссэн үед л ирдэг (харах: түүний тайлбар),
  /// тиймээс түүнийг байхгүй байхыг шаардана. Offline cache-д `serviceProgress`
  /// байхгүй байж болох тул энэ нь зөвхөн UX-ийн урьдчилсан шалгалт —
  /// эцсийн шийдвэр server дээр (харах: `remote_appointment_repository.dart`).
  bool get canCancel => status.canCancel && serviceProgress == null;

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
    note: note,
    categoryNames: categoryNames,
    vehiclePlate: vehiclePlate,
    payment: payment ?? this.payment,
    serviceProgress: serviceProgress ?? this.serviceProgress,
  );
}
