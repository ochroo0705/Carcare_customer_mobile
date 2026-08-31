class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.district,
    required this.isOpen,
    required this.hours,
    this.latitude,
    this.longitude,
  });
  final String id;
  final String name;
  final String address;
  final String city;
  final String district;
  final bool isOpen;
  final String hours;
  final double? latitude;
  final double? longitude;
}
