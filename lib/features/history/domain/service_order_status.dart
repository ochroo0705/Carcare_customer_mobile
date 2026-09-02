enum ServiceOrderStatus { paid, partiallyPaid, unpaid }

extension ServiceOrderStatusUi on ServiceOrderStatus {
  String get localizedLabel => switch (this) {
    ServiceOrderStatus.paid => 'Төлөгдсөн',
    ServiceOrderStatus.partiallyPaid => 'Хэсэгчлэн төлөгдсөн',
    ServiceOrderStatus.unpaid => 'Төлөгдөөгүй',
  };
}
