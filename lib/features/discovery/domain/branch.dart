import 'dart:math' as math;

enum BranchOpenStatus { open, closed, unknown }

/// A platform-wide business-type label (e.g. "Угаалгын газар") a branch can
/// carry — see `BranchTag` server-side. Shown directly on branch cards and
/// used to drive the discovery tag filter chip row.
class BranchTagOption {
  const BranchTagOption({required this.id, required this.name});

  final String id;
  final String name;
}

class Branch {
  const Branch({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.serviceKeyIds = const [],
    this.tags = const [],
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

  /// `SystemServiceKey.id`s this branch's categories are linked to — powers
  /// the cross-org "what do you need done?" picker (`?serviceKey=` filter).
  final List<String> serviceKeyIds;

  /// Business-type labels this branch carries (e.g. "Угаалгын газар") —
  /// shown directly on the branch card, and match the discovery tag filter
  /// chip row (`?tag=` filter, see `/api/v1/app/branch-tags`).
  final List<BranchTagOption> tags;

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
    this.query = '',
    this.city = '',
    this.district = '',
    this.page = 1,
    this.pageSize = 20,
    this.lat,
    this.lng,
    this.radiusKm,
    this.openNow = false,
    this.weekend = false,
    this.serviceKey = '',
    this.tag = '',
  });

  final String query;
  final String city;
  final String district;
  final int page;
  final int pageSize;
  final double? lat;
  final double? lng;
  final double? radiusKm;
  final bool openNow;
  // Амралтын өдөр (Бямба/Ням) аль нэгэнд ажилладаг салбартай байгууллага.
  final bool weekend;
  // "Ямар ажил хийлгэх гэж байна?" — SystemServiceKey.id-аар шүүнэ, аль ч
  // байгууллагад хамаарахгүй (Booking tab-ийн cross-org picker).
  final String serviceKey;
  // Бизнесийн төрлийн шошго (BranchTag.id) — discovery-г бизнесийн төрлөөр
  // шүүх хөнгөн шүүлтүүр (жиш: "Угаалгын газар").
  final String tag;

  bool get hasNearMe => lat != null && lng != null;
  bool get hasTextFilters => query.isNotEmpty || city.isNotEmpty || district.isNotEmpty;
  bool get isActive =>
      hasTextFilters || hasNearMe || openNow || weekend || serviceKey.isNotEmpty || tag.isNotEmpty;
}

/// Салбарт санал болгож буй үйлчилгээний ангилал (booking v2) — шийдэгдсэн
/// хугацаатай (сервер талд branch override ?? default ?? 30 бодогдоно).
class BranchServiceCategory {
  const BranchServiceCategory({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.systemServiceKeyId,
  });

  final String id;
  final String name;
  final int durationMinutes;
  // Cross-org "what job do you need done?" key this category maps to — lets
  // a locked, category-first booking flow (from the Booking tab's multi-key
  // picker) resolve which of a branch's categories to preselect.
  final String systemServiceKeyId;
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

enum BranchScheduleSource { exception, season, weekday, fallback }

/// A resolved day's hours plus *why* — mirrors the server's
/// `resolveEffectiveSchedule` precedence (exception > active season > base
/// weekday > branch-level fallback) so the mobile UI can show the same
/// answer, and explain it, for any date.
class BranchEffectiveSchedule {
  const BranchEffectiveSchedule({
    required this.rule,
    required this.source,
    this.label,
  });

  final BranchScheduleRule rule;
  final BranchScheduleSource source;

  /// Exception label (e.g. "Наадам") or season name (e.g. "Өвлийн цагийн
  /// хуваарь") — null for the ordinary weekday/fallback sources.
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

  /// Approximate straight-line distance from a user location, in kilometres.
  /// Returns null when this branch has no usable coordinates.
  double? distanceKmFrom({required double userLatitude, required double userLongitude}) {
    final branchLatitude = latitude;
    final branchLongitude = longitude;
    if (branchLatitude == null || branchLongitude == null) return null;
    const earthRadiusKm = 6371.0;
    final latDelta = (branchLatitude - userLatitude) * math.pi / 180;
    final longitudeDelta = (branchLongitude - userLongitude) * math.pi / 180;
    final userLatitudeRadians = userLatitude * math.pi / 180;
    final branchLatitudeRadians = branchLatitude * math.pi / 180;
    final haversine = math.pow(math.sin(latDelta / 2), 2) +
        math.cos(userLatitudeRadians) *
            math.cos(branchLatitudeRadians) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return 2 * earthRadiusKm * math.asin(math.min(1, math.sqrt(haversine)));
  }

  String? distanceLabelFrom({required double userLatitude, required double userLongitude}) {
    final distance = distanceKmFrom(
      userLatitude: userLatitude,
      userLongitude: userLongitude,
    );
    return distance == null ? null : 'Ойролцоогоор ${distance.toStringAsFixed(1)} км';
  }

  // NB: booking v2 (2026-09-07) — client-side slot generation removed. Slots now
  // come from the branch availability endpoint (sized to the selected categories'
  // summed duration, with real booked/available state). See BookingRequestScreen.

  BranchOpenStatus openStatusAt(DateTime now) {
    final detail = effectiveScheduleDetailAt(now);
    final effective = detail.rule;
    // The "fallback" source means no exception/season/weekday rule matched
    // at all — `isOpen: false` there just reflects missing data (no branch
    // -level hours either), not an explicit "closed" answer. Don't conflate
    // the two: report unknown instead of a false "closed".
    if (!effective.isOpen) {
      return detail.source == BranchScheduleSource.fallback
          ? BranchOpenStatus.unknown
          : BranchOpenStatus.closed;
    }
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

  BranchScheduleRule effectiveScheduleAt(DateTime value) =>
      effectiveScheduleDetailAt(value).rule;

  BranchEffectiveSchedule effectiveScheduleDetailAt(DateTime value) {
    final business = value.toUtc().add(const Duration(hours: 8));
    final date = '${business.year.toString().padLeft(4, '0')}-${business.month.toString().padLeft(2, '0')}-${business.day.toString().padLeft(2, '0')}';
    final weekday = <String>['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'][business.weekday % 7];
    final exception = _firstOrNull(scheduleExceptions.where((item) => item.date == date));
    if (exception != null) {
      return BranchEffectiveSchedule(
        rule: BranchScheduleRule(weekday: weekday, isOpen: exception.isOpen, openTime: exception.openTime, closeTime: exception.closeTime),
        source: BranchScheduleSource.exception,
        label: exception.label,
      );
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
    if (season != null && seasonal != null) {
      return BranchEffectiveSchedule(
        rule: BranchScheduleRule(weekday: weekday, isOpen: seasonal.isOpen, openTime: seasonal.openTime ?? base?.openTime ?? openTime, closeTime: seasonal.closeTime ?? base?.closeTime ?? closeTime),
        source: BranchScheduleSource.season,
        label: season.name,
      );
    }
    if (base != null) {
      return BranchEffectiveSchedule(
        rule: BranchScheduleRule(weekday: weekday, isOpen: base.isOpen, openTime: base.openTime ?? openTime, closeTime: base.closeTime ?? closeTime),
        source: BranchScheduleSource.weekday,
      );
    }
    return BranchEffectiveSchedule(
      rule: BranchScheduleRule(weekday: weekday, isOpen: openTime != null && closeTime != null, openTime: openTime, closeTime: closeTime),
      source: BranchScheduleSource.fallback,
    );
  }
}

T? _firstOrNull<T>(Iterable<T> values) {
  for (final value in values) {
    return value;
  }
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
