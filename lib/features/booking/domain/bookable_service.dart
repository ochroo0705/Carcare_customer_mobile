class BookableService {
  const BookableService({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.price,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final int durationMinutes;
  final int price;
}
