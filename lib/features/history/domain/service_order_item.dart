enum ServiceOrderItemKind { labor, part, diagnostic, fee }

extension ServiceOrderItemKindUi on ServiceOrderItemKind {
  String get localizedLabel => switch (this) {
    ServiceOrderItemKind.labor => 'Ажил',
    ServiceOrderItemKind.part => 'Сэлбэг',
    ServiceOrderItemKind.diagnostic => 'Оношилгоо',
    ServiceOrderItemKind.fee => 'Хураамж',
  };
}

/// API `ItemKind` (LABOR/DIAGNOSTIC/PART/FEE) → domain. Unknown falls back to
/// `labor` (a neutral service line) rather than throwing on an unfamiliar kind.
ServiceOrderItemKind serviceOrderItemKindFromApi(String value) =>
    switch (value) {
      'LABOR' => ServiceOrderItemKind.labor,
      'PART' => ServiceOrderItemKind.part,
      'DIAGNOSTIC' => ServiceOrderItemKind.diagnostic,
      'FEE' => ServiceOrderItemKind.fee,
      _ => ServiceOrderItemKind.labor,
    };

class ServiceOrderItem {
  const ServiceOrderItem({
    required this.kind,
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final ServiceOrderItemKind kind;
  final String name;
  final int quantity;
  final int unitPrice;

  int get totalPrice => quantity * unitPrice;
}
