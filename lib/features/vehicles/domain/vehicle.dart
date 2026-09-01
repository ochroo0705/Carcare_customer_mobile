class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.make,
    required this.model,
    this.year,
    this.vin,
  });

  /// The account-vehicle/link id, used for delete and appointment creation.
  final String id;
  final String plate;
  final String make;
  final String model;
  final int? year;
  final String? vin;
}
