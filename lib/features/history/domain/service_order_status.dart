enum ServiceOrderStatus { paid, partiallyPaid, unpaid }

/// API `PaymentStatus` (UNPAID/PARTIAL/PAID) → domain. This is the order's
/// PAYMENT status, not its workflow status (SCHEDULED/IN_PROGRESS/…, which the
/// list UI does not model). Unknown → `unpaid` (safe default).
ServiceOrderStatus serviceOrderStatusFromApi(String value) => switch (value) {
  'PAID' => ServiceOrderStatus.paid,
  'PARTIAL' => ServiceOrderStatus.partiallyPaid,
  'UNPAID' => ServiceOrderStatus.unpaid,
  _ => ServiceOrderStatus.unpaid,
};

extension ServiceOrderStatusUi on ServiceOrderStatus {
  String get localizedLabel => switch (this) {
    ServiceOrderStatus.paid => 'Төлөгдсөн',
    ServiceOrderStatus.partiallyPaid => 'Хэсэгчлэн төлөгдсөн',
    ServiceOrderStatus.unpaid => 'Төлөгдөөгүй',
  };
}
