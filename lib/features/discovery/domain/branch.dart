enum BranchOpenStatus { open, closed, unknown }

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });
  final String id;
  final String name;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;

  /// Distance from the user, in km — only present when the list was fetched with
  /// the "near me" filter (`GET /orgs?lat&lng`). `null` otherwise.
  final double? distanceKm;

  /// City · district, omitting either part when the API left it blank
  /// (`Branch.city`/`district` are optional server-side). Empty when both
  /// are absent.
  String get locationLabel =>
      [city, district].where((part) => part.trim().isNotEmpty).join(' · ');

  /// Human label for [distanceKm] (e.g. "1.3 км"), or `null` when absent.
  String? get distanceLabel =>
      distanceKm == null ? null : '${distanceKm!.toStringAsFixed(1)} км';
}

/// Discovery-ийн сервер талын шүүлт (booking v2). `nearMe` идэвхтэй бол `lat`/`lng`
/// заавал. Идэвхгүй утга null — query-д орохгүй.
class OrganizationFilter {
  const OrganizationFilter({
    this.lat,
    this.lng,
    this.radiusKm,
    this.openNow = false,
    this.weekend = false,
  });

  final double? lat;
  final double? lng;
  final double? radiusKm;
  final bool openNow;
  // Амралтын өдөр (Бямба/Ням) аль нэгэнд ажилладаг салбартай байгууллага.
  final bool weekend;

  bool get hasNearMe => lat != null && lng != null;
  bool get isActive => hasNearMe || openNow || weekend;
}

/// Салбарт санал болгож буй үйлчилгээний ангилал (booking v2) — шийдэгдсэн
/// хугацаатай (сервер талд branch override ?? default ?? 30 бодогдоно).
class BranchServiceCategory {
  const BranchServiceCategory({
    required this.id,
    required this.name,
    required this.durationMinutes,
  });

  final String id;
  final String name;
  final int durationMinutes;
}

class BranchScheduleRule {
  const BranchScheduleRule({
    required this.weekday,
    required this.isOpen,
    this.openTime,
    this.closeTime,
  });

  final String weekday;
  final bool isOpen;
  final String? openTime;
  final String? closeTime;
}

class BranchScheduleException {
  const BranchScheduleException({
    required this.date,
    required this.isOpen,
    this.openTime,
    this.closeTime,
    this.label,
  });

  final String date;
  final bool isOpen;
  final String? openTime;
  final String? closeTime;
  final String? label;
}

class BranchScheduleSeason {
  const BranchScheduleSeason({
    required this.name,
    required this.startsOn,
    required this.endsOn,
    required this.days,
  });

  final String name;
  final String startsOn;
  final String endsOn;
  final List<BranchScheduleRule> days;
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
    this.categories = const [],
    this.schedules = const [],
    this.scheduleExceptions = const [],
    this.scheduleSeasons = const [],
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

  final List<BranchScheduleRule> schedules;
  final List<BranchScheduleException> scheduleExceptions;
  final List<BranchScheduleSeason> scheduleSeasons;

  /// Онлайн захиалгад санал болгох үйлчилгээний ангилалууд (booking v2).
  final List<BranchServiceCategory> categories;

  String get fullAddress =>
      [khoroo, address].where((part) => part.trim().isNotEmpty).join(', ');

  /// City · district, omitting either part when the API left it blank
  /// (`Branch.city`/`district` are optional server-side). Empty when both
  /// are absent.
  String get locationLabel =>
      [city, district].where((part) => part.trim().isNotEmpty).join(' · ');

  String get hoursLabel {
    final effective = effectiveScheduleAt(DateTime.now());
    final opening = _parseClock(effective.openTime);
    final closing = _parseClock(effective.closeTime);
    if (opening == null || closing == null || opening == closing) {
      return 'Цагийн мэдээлэл тодорхойгүй';
    }
    return '${effective.openTime}–${effective.closeTime}';
  }

  // NB: booking v2 (2026-09-07) — client-side slot generation removed. Slots now
  // come from the branch availability endpoint (sized to the selected categories'
  // summed duration, with real booked/available state). See BookingRequestScreen.

  BranchOpenStatus openStatusAt(DateTime now) {
    final effective = effectiveScheduleAt(now);
    if (!effective.isOpen) return BranchOpenStatus.closed;
    final opening = _parseClock(effective.openTime);
    final closing = _parseClock(effective.closeTime);
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

  BranchScheduleRule effectiveScheduleAt(DateTime value) {
    final business = value.toUtc().add(const Duration(hours: 8));
    final date = '${business.year.toString().padLeft(4, '0')}-${business.month.toString().padLeft(2, '0')}-${business.day.toString().padLeft(2, '0')}';
    final weekday = <String>['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'][business.weekday % 7];
    final exception = _firstOrNull(scheduleExceptions.where((item) => item.date == date));
    if (exception != null) {
      return BranchScheduleRule(weekday: weekday, isOpen: exception.isOpen, openTime: exception.openTime, closeTime: exception.closeTime);
    }
    final base = _firstOrNull(schedules.where((item) => item.weekday == weekday));
    final season = _firstOrNull(
      scheduleSeasons.where(
        (item) =>
            item.startsOn.compareTo(date) <= 0 &&
            date.compareTo(item.endsOn) < 0,
      ),
    );
    final seasonal = season == null ? null : _firstOrNull(season.days.where((item) => item.weekday == weekday));
    if (seasonal != null) {
      return BranchScheduleRule(weekday: weekday, isOpen: seasonal.isOpen, openTime: seasonal.openTime ?? base?.openTime ?? openTime, closeTime: seasonal.closeTime ?? base?.closeTime ?? closeTime);
    }
    if (base != null) {
      return BranchScheduleRule(weekday: weekday, isOpen: base.isOpen, openTime: base.openTime ?? openTime, closeTime: base.closeTime ?? closeTime);
    }
    return BranchScheduleRule(weekday: weekday, isOpen: openTime != null && closeTime != null, openTime: openTime, closeTime: closeTime);
  }
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) return value;
  return null;
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
