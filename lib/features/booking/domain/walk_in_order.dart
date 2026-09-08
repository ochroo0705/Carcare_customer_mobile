import 'package:carcare_customer_mobile/features/booking/domain/service_progress.dart';

/// Ажилтан утсаар/шууд ирсэн машинд цаг захиалгагүйгээр шууд үүсгэсэн
/// засварын хуудас — [progress.id]-той тэнцүү `Appointment` мөр байхгүй тул
/// `GET /appointments`-ийн `walkInOrders` массиваар тусад нь ирнэ (харах:
/// carcare.mn `app/api/v1/app/appointments/route.ts`). `progress`-ийн бүх
/// талбар (дэлгэрэнгүй, үнэ, ажлын жагсаалт) list payload дотор аль хэдийн
/// иржээ — дэлгэрэнгүй дэлгэц тусад нь дахин татахгүй.
class WalkInOrder {
  const WalkInOrder({
    required this.tenantName,
    required this.tenantSlug,
    required this.branchName,
    required this.progress,
  });

  final String tenantName;
  final String tenantSlug;
  final String branchName;
  final AppointmentServiceProgress progress;
}
