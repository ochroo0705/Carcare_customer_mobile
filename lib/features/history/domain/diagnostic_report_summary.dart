/// Захиалгад хавсаргасан оношилгооны тайлангийн товч мэдээлэл. Backend
/// `GET /api/v1/app/orders/[id]` тайлан бүрийн БҮРЭН өгөгдлийг (template schema,
/// data) буцаадаг ч энэ хувилбарт зөвхөн товч жагсаалт (нэр/төрөл/огноо/гүйлт)
/// харуулна — schema-аар жолоодсон бүрэн тайлан харагч дараагийн ажил.
class DiagnosticReportSummary {
  const DiagnosticReportSummary({
    required this.id,
    required this.templateName,
    required this.type,
    required this.createdAt,
    this.mileageAtReport,
  });

  final String id;

  /// Тайлан загварын нэр (QPay `templateName`) — UI-д харуулах гол шошго.
  final String templateName;

  /// Загварын төрөл (`type`) — жишээ нь `INSPECTION`. Тодорхойгүй байж болно.
  final String type;

  final DateTime createdAt;

  /// Тайлан бичих үеийн гүйлт (км). Заавал биш.
  final int? mileageAtReport;
}
