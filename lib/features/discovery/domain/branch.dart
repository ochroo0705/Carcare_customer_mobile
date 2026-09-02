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

  /// Generates fixed-length time-of-day slots spanning [openTime]–[closeTime]
  /// (e.g. 09:00, 09:30, 10:00, ... for the default 30-minute step) —
  /// mirrors the web booking picker's slot generation
  /// (`lib/appointment-slots.ts`'s `buildDaySlots`), minus real
  /// booked/available state: the customer API publishes no availability
  /// endpoint (`CUSTOMER_API_CONTRACT.md`), so every generated slot here is
  /// only ever "the branch is open then," never "and this exact slot is
  /// free" — that's still confirmed server-side on submit (a `409` means
  /// the slot filled up). Empty when hours aren't published or are
  /// malformed.
  List<({int hour, int minute})> slotsForDay({int slotMinutes = 30}) {
    final opening = _parseClock(openTime);
    final closing = _parseClock(closeTime);
    if (opening == null || closing == null || opening >= closing) {
      return const [];
    }
    final slots = <({int hour, int minute})>[];
    for (
      var minute = opening;
      minute + slotMinutes <= closing;
      minute += slotMinutes
    ) {
      slots.add((hour: minute ~/ 60, minute: minute % 60));
    }
    return slots;
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
