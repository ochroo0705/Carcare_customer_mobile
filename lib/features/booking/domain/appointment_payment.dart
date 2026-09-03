enum AppointmentFeeStatus { pending, paid, underpaid, failed }

AppointmentFeeStatus appointmentFeeStatusFromApi(String value) =>
    switch (value) {
      'PENDING' => AppointmentFeeStatus.pending,
      'PAID' => AppointmentFeeStatus.paid,
      'UNDERPAID' => AppointmentFeeStatus.underpaid,
      'FAILED' => AppointmentFeeStatus.failed,
      _ => AppointmentFeeStatus.pending,
    };

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
