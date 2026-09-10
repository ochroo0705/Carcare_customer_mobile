class Vehicle {
  const Vehicle({
    required this.id,
    required this.plate,
    required this.make,
    required this.model,
    this.year,
    this.vin,
    this.fuelType,
    this.wheelPosition,
    this.colorName,
    this.capacity,
    this.purpose,
    this.serviceCount = 0,
    this.diagnosisCount = 0,
  });

  /// The account-vehicle/link id, used for delete and appointment creation.
  final String id;
  final String plate;
  final String make;
  final String model;
  final int? year;
  final String? vin;
  final String? fuelType;
  final String? wheelPosition;
  final String? colorName;
  final int? capacity;
  final String? purpose;
  final int serviceCount;
  final int diagnosisCount;
}
