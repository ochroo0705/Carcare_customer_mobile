enum AppointmentFeeStatus { pending, paid, underpaid, failed }

AppointmentFeeStatus appointmentFeeStatusFromApi(String value) =>
    switch (value) {
      'PENDING' => AppointmentFeeStatus.pending,
      'PAID' => AppointmentFeeStatus.paid,
      'UNDERPAID' => AppointmentFeeStatus.underpaid,
      'FAILED' => AppointmentFeeStatus.failed,
      _ => AppointmentFeeStatus.pending,
    };

/// Нэг банкны апп руу шилжих QPay deep link (`AppointmentPayment.urls`-ийн
/// нэг мөр). QPay invoice үүсгэхэд банк тус бүрийн deep link-ийг буцаадаг —
/// backend `feeQpayUrls`-д хадгалж mobile-д дамжуулна. Ганц ерөнхий
/// `qpay://` link биш, банк тус бүрийн link л суулгасан аппыг найдвартай
/// нээдэг тул хэрэглэгчид банкаа сонгуулна.
class QpayBankUrl {
  const QpayBankUrl({
    required this.name,
    required this.nameMn,
    required this.logo,
    required this.link,
    this.description,
  });

  /// Банкны англи нэр (QPay `name`) — logo байхгүй үед fallback.
  final String name;

  /// Монгол нэр (QPay `name_mn`) — UI-д харуулах гол шошго.
  final String nameMn;

  /// Банкны лого зураг (URL эсвэл data URI) — QPay `logo`.
  final String logo;

  /// Тухайн банкны аппыг нээх deep link (QPay `link`).
  final String link;

  /// QPay `description` — заавал биш.
  final String? description;

  /// UI-д харуулах шошго: mn нэр эхэнд, үгүй бол англи нэр.
  String get label => nameMn.trim().isNotEmpty ? nameMn : name;
}

/// A booking fee attached to an appointment, paid via QPay. `null` (not this
/// type — the field itself is nullable everywhere it's used) means no fee is
/// required — see `CUSTOMER_API_CONTRACT.md` §"4.1 Цаг захиалгын хураамж".
class AppointmentPayment {
  const AppointmentPayment({
    required this.status,
    required this.amount,
    required this.currency,
    this.qrImageBase64,
    this.qrText,
    this.urls = const [],
    this.underpaidAmount,
  });

  final AppointmentFeeStatus status;
  final num amount;
  final String currency;

  /// Base64-encoded QR PNG — present only while `status` is `pending` or
  /// `underpaid` (the API omits it once paid, and never sends one at all if
  /// checkout creation failed).
  final String? qrImageBase64;

  /// A `qpay://...` deeplink into a banking app — same availability as
  /// [qrImageBase64].
  final String? qrText;

  /// Банк тус бүрийн deep link (QPay `urls`). Хоосон байж болно — энэ фичер
  /// нэвтрэхээс өмнө үүссэн pending invoice-ууд `feeQpayUrls=null` тул
  /// backend `[]` буцаана; тэр үед QR-аар (эсвэл ерөнхий [qrText]-ээр)
  /// л төлнө. UI хоосон бол банк сонголтыг харуулахгүй.
  final List<QpayBankUrl> urls;

  /// Only set while `status` is `underpaid`: how much of [amount] has
  /// arrived so far.
  final num? underpaidAmount;
}

/// Result of polling `POST /appointments/[id]/payment/check`.
class AppointmentPaymentCheckResult {
  const AppointmentPaymentCheckResult({
    required this.paid,
    this.underpaidAmount,
    this.message,
  });

  final bool paid;
  final num? underpaidAmount;
  final String? message;
}
