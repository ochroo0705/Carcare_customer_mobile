enum VehicleLookupSource { global, hur }

/// Result of a HUR-backed plate lookup. Not yet a saved [Vehicle] — it has no
/// account-vehicle id until the customer confirms adding it.
class VehicleLookupResult {
  const VehicleLookupResult({
    required this.plate,
    required this.make,
    required this.model,
    required this.source,
    this.year,
    this.vin,
    this.fuelType,
    this.wheelPosition,
    this.colorName,
    this.capacity,
    this.purpose,
  });

  final String plate;
  final String make;
  final String model;
  final VehicleLookupSource source;
  final int? year;
  final String? vin;
  final String? fuelType;
  final String? wheelPosition;
  final String? colorName;
  final int? capacity;
  final String? purpose;
}
