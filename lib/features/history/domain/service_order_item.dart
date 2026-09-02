enum ServiceOrderItemKind { labor, part, diagnostic }

extension ServiceOrderItemKindUi on ServiceOrderItemKind {
  String get localizedLabel => switch (this) {
    ServiceOrderItemKind.labor => 'Ажил',
    ServiceOrderItemKind.part => 'Сэлбэг',
    ServiceOrderItemKind.diagnostic => 'Оношилгоо',
  };
}

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
