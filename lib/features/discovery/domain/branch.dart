enum BranchOpenStatus { open, closed, unknown }

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    this.latitude,
    this.longitude,
  });
  final String id;
  final String name;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;
}

class BranchDetail {
  const BranchDetail({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.khoroo,
    required this.address,
    this.latitude,
    this.longitude,
    this.openTime,
    this.closeTime,
  });

  final String id;
  final String name;
  final String city;
  final String district;
  final String khoroo;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? openTime;
  final String? closeTime;

  String get fullAddress =>
      [khoroo, address].where((part) => part.trim().isNotEmpty).join(', ');

  String get hoursLabel {
    final opening = _parseClock(openTime);
    final closing = _parseClock(closeTime);
    if (opening == null || closing == null || opening == closing) {
      return 'Цагийн мэдээлэл тодорхойгүй';
    }
    return '$openTime–$closeTime';
  }

  BranchOpenStatus openStatusAt(DateTime now) {
    final opening = _parseClock(openTime);
    final closing = _parseClock(closeTime);
    if (opening == null || closing == null || opening == closing) {
      return BranchOpenStatus.unknown;
    }
    final currentMinute = now.hour * 60 + now.minute;
    if (opening < closing) {
      return currentMinute >= opening && currentMinute < closing
          ? BranchOpenStatus.open
          : BranchOpenStatus.closed;
    }
    return currentMinute >= opening || currentMinute < closing
        ? BranchOpenStatus.open
        : BranchOpenStatus.closed;
  }
}

int? _parseClock(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}
