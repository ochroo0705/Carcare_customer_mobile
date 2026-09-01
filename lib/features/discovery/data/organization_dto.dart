import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';

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
  });

  factory BranchSummaryDto.fromJson(Map<String, dynamic> json) =>
      BranchSummaryDto(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        city: _requiredString(json, 'city'),
        district: _requiredString(json, 'district'),
        latitude: _optionalDouble(json['latitude']),
        longitude: _optionalDouble(json['longitude']),
      );

  final String id;
  final String name;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;

  Branch toDomain() => Branch(
    id: id,
    name: name,
    city: city,
    district: district,
    latitude: latitude,
    longitude: longitude,
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
    this.latitude,
    this.longitude,
    this.openTime,
    this.closeTime,
  });

  factory BranchDetailDto.fromJson(Map<String, dynamic> json) =>
      BranchDetailDto(
        id: _requiredString(json, 'id'),
        name: _requiredString(json, 'name'),
        city: _requiredString(json, 'city'),
        district: _requiredString(json, 'district'),
        khoroo: _optionalString(json['khoroo']) ?? '',
        address: _optionalString(json['address']) ?? '',
        latitude: _optionalDouble(json['latitude']),
        longitude: _optionalDouble(json['longitude']),
        openTime: _optionalString(json['openTime']),
        closeTime: _optionalString(json['closeTime']),
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
