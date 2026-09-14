import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';

OrganizationPage organizationPageFromJson(Map<String, dynamic> json) {
  final items = json['orgs'];
  if (items is! List) throw const UnexpectedFailure('API жагсаалт буруу байна.');
  final organizations = items
      .map((item) {
        if (item is! Map) throw const UnexpectedFailure('API өгөгдөл буруу байна.');
        return OrganizationSummaryDto.fromJson(Map<String, dynamic>.from(item)).toDomain();
      })
      .toList(growable: false);
  final rawPagination = json['pagination'];
  final pagination = rawPagination is Map
      ? _paginationFromJson(Map<String, dynamic>.from(rawPagination), organizations.length)
      : OrganizationPagination(
          page: 1,
          pageSize: organizations.length,
          total: organizations.length,
          totalPages: 1,
          hasPrev: false,
          hasNext: false,
        );
  final rawFacets = json['facets'];
  final facets = rawFacets is Map
      ? OrganizationFacets(
          cities: _stringList(rawFacets['cities']),
          districts: _stringList(rawFacets['districts']),
        )
      : const OrganizationFacets();
  return OrganizationPage(
    organizations: organizations,
    pagination: pagination,
    facets: facets,
  );
}

OrganizationPagination _paginationFromJson(
  Map<String, dynamic> json,
  int fallbackLength,
) => OrganizationPagination(
  page: _positiveInt(json['page'], 1),
  pageSize: _positiveInt(json['pageSize'], fallbackLength),
  total: _nonNegativeInt(json['total'], fallbackLength),
  totalPages: _positiveInt(json['totalPages'], 1),
  hasPrev: json['hasPrev'] == true,
  hasNext: json['hasNext'] == true,
);

int _positiveInt(Object? value, int fallback) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : (fallback > 0 ? fallback : 1);
}

int _nonNegativeInt(Object? value, int fallback) {
  final parsed = value is num ? value.toInt() : int.tryParse('$value');
  return parsed != null && parsed >= 0 ? parsed : fallback;
}

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().map((item) => item.trim()).where((item) => item.isNotEmpty).toList(growable: false)
    : const [];

class OrganizationSummaryDto {
  OrganizationSummaryDto({
    required this.slug,
    required this.name,
    required this.branches,
    this.logoUrl,
  });

  factory OrganizationSummaryDto.fromJson(Map<String, dynamic> json) =>
      OrganizationSummaryDto(
        slug: _requiredString(json, 'slug'),
        name: _requiredString(json, 'name'),
        logoUrl: _optionalString(json['logoUrl']),
        branches: _mapList(json['branches'], BranchSummaryDto.fromJson),
      );

  final String slug;
  final String name;
  final String? logoUrl;
  final List<BranchSummaryDto> branches;

  Organization toDomain() => Organization(
    slug: slug,
    name: name,
    logoUrl: logoUrl,
    branches: branches.map((branch) => branch.toDomain()).toList(),
  );
}

class BranchSummaryDto {
  BranchSummaryDto({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    this.latitude,
    this.longitude,
    this.distanceKm,
  });

  factory BranchSummaryDto.fromJson(Map<String, dynamic> json) =>
      BranchSummaryDto(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        city: _optionalString(json['city']) ?? '',
        district: _optionalString(json['district']) ?? '',
        latitude: _optionalDouble(json['latitude']),
        longitude: _optionalDouble(json['longitude']),
        distanceKm: _optionalDouble(json['distanceKm']),
      );

  final String id;
  final String name;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  Branch toDomain() => Branch(
    id: id,
    name: name,
    city: city,
    district: district,
    latitude: latitude,
    longitude: longitude,
    distanceKm: distanceKm,
  );
}

class OrganizationDetailDto {
  OrganizationDetailDto({
    required this.slug,
    required this.name,
    required this.branches,
    this.logoUrl,
    this.phone,
  });

  factory OrganizationDetailDto.fromJson(Map<String, dynamic> json) =>
      OrganizationDetailDto(
        slug: _requiredString(json, 'slug'),
        name: _requiredString(json, 'name'),
        logoUrl: _optionalString(json['logoUrl']),
        phone: _optionalString(json['phone1']),
        branches: _mapList(json['branches'], BranchDetailDto.fromJson),
      );

  final String slug;
  final String name;
  final String? logoUrl;
  final String? phone;
  final List<BranchDetailDto> branches;

  OrganizationDetail toDomain() => OrganizationDetail(
    slug: slug,
    name: name,
    logoUrl: logoUrl,
    phone: phone,
    branches: branches.map((branch) => branch.toDomain()).toList(),
  );
}

class BranchDetailDto {
  BranchDetailDto({
    required this.id,
    required this.name,
    required this.city,
    required this.district,
    required this.khoroo,
    required this.address,
    required this.categories,
    this.latitude,
    this.longitude,
    this.openTime,
    this.closeTime,
    this.schedules = const [],
    this.scheduleExceptions = const [],
    this.scheduleSeasons = const [],
  });

  factory BranchDetailDto.fromJson(Map<String, dynamic> json) =>
      BranchDetailDto(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        city: _optionalString(json['city']) ?? '',
        district: _optionalString(json['district']) ?? '',
        khoroo: _optionalString(json['khoroo']) ?? '',
        address: _optionalString(json['address']) ?? '',
        latitude: _optionalDouble(json['latitude']),
        longitude: _optionalDouble(json['longitude']),
        openTime: _optionalString(json['openTime']),
        closeTime: _optionalString(json['closeTime']),
        schedules: json['schedules'] is List
            ? _mapList(json['schedules'], _scheduleFromJson)
            : const <BranchScheduleRule>[],
        scheduleExceptions: json['scheduleExceptions'] is List
            ? _mapList(json['scheduleExceptions'], _exceptionFromJson)
            : const <BranchScheduleException>[],
        scheduleSeasons: json['scheduleSeasons'] is List
            ? _mapList(json['scheduleSeasons'], _seasonFromJson)
            : const <BranchScheduleSeason>[],
        // Booking v2: салбарын санал болгож буй ангилалууд (ЗААВАЛ БИШ; хуучин
        // API-д байхгүй бол хоосон — _mapList null дээр шидэх тул List үед л дуудна).
        categories: json['categories'] is List
            ? _mapList(json['categories'], _categoryFromJson)
            : const <BranchServiceCategory>[],
      );

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
  final List<BranchServiceCategory> categories;

  BranchDetail toDomain() => BranchDetail(
    id: id,
    name: name,
    city: city,
    district: district,
    khoroo: khoroo,
    address: address,
    latitude: latitude,
    longitude: longitude,
    openTime: openTime,
    closeTime: closeTime,
    schedules: schedules,
    scheduleExceptions: scheduleExceptions,
    scheduleSeasons: scheduleSeasons,
    categories: categories,
  );
}

BranchScheduleRule _scheduleFromJson(Map<String, dynamic> json) => BranchScheduleRule(
  weekday: _requiredString(json, 'weekday'),
  isOpen: json['isOpen'] == true,
  openTime: _optionalString(json['openTime']),
  closeTime: _optionalString(json['closeTime']),
);

BranchScheduleException _exceptionFromJson(Map<String, dynamic> json) => BranchScheduleException(
  date: _requiredString(json, 'date').substring(0, 10),
  isOpen: json['isOpen'] == true,
  openTime: _optionalString(json['openTime']),
  closeTime: _optionalString(json['closeTime']),
  label: _optionalString(json['label']),
);

BranchScheduleSeason _seasonFromJson(Map<String, dynamic> json) => BranchScheduleSeason(
  name: _requiredString(json, 'name'),
  startsOn: _requiredString(json, 'startsOn').substring(0, 10),
  endsOn: _requiredString(json, 'endsOn').substring(0, 10),
  days: json['days'] is List ? _mapList(json['days'], _scheduleFromJson) : const <BranchScheduleRule>[],
);

BranchServiceCategory _categoryFromJson(Map<String, dynamic> json) {
  final duration = json['durationMinutes'];
  return BranchServiceCategory(
    id: _requiredString(json, 'id'),
    name: _requiredString(json, 'name'),
    durationMinutes: duration is num ? duration.toInt() : 30,
  );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null) throw UnexpectedFailure('API талбар буруу байна: $key');
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

double? _optionalDouble(Object? value) =>
    value is num ? value.toDouble() : null;

List<T> _mapList<T>(Object? value, T Function(Map<String, dynamic>) mapper) {
  if (value is! List) {
    throw const UnexpectedFailure('API жагсаалт буруу байна.');
  }
  return value
      .map((item) {
        if (item is! Map) {
          throw const UnexpectedFailure('API өгөгдөл буруу байна.');
        }
        return mapper(Map<String, dynamic>.from(item));
      })
      .toList(growable: false);
}
