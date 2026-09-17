import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';

abstract interface class OrganizationRepository {
  /// [filter] идэвхтэй бол сервер талын "ойролцоо"/"одоо нээлттэй" шүүлтийг
  /// хэрэглэнэ (branch-д `distanceKm` нэмэгдэж болно). null бол бүх жагсаалт.
  Future<OrganizationPage> getOrganizations({OrganizationFilter? filter});
  Future<OrganizationMapPage> getMapMarkers({
    required MapViewport viewport,
    OrganizationFilter? filter,
  });
  Future<OrganizationDetail> getOrganization(String slug);

  /// Active `SystemServiceKey`s — the platform-wide "what do you need done?"
  /// options for the cross-org Booking tab picker (`OrganizationFilter.serviceKey`).
  Future<List<ServiceKey>> getServiceKeys();

  /// Active `BranchTag`s — the platform-wide business-type labels (e.g.
  /// "Угаалгын газар") for the discovery tag filter (`OrganizationFilter.tag`).
  Future<List<BranchTagOption>> getBranchTags();
}

class ServiceKey {
  const ServiceKey({required this.id, required this.name});

  final String id;
  final String name;
}

class MapViewport {
  const MapViewport({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;
}

class OrganizationMapMarker {
  const OrganizationMapMarker({
    required this.id,
    required this.orgSlug,
    required this.orgName,
    required this.branchName,
    required this.latitude,
    required this.longitude,
    this.logoUrl,
    this.city,
    this.district,
    this.distanceKm,
    this.serviceKeyIds = const [],
    this.tagIds = const [],
  });

  final String id;
  final String orgSlug;
  final String orgName;
  final String branchName;
  final String? logoUrl;
  final String? city;
  final String? district;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final List<String> serviceKeyIds;
  final List<String> tagIds;

  Organization toOrganization() => Organization(
    slug: orgSlug,
    name: orgName,
    logoUrl: logoUrl,
    branches: [
      Branch(
        id: id,
        name: branchName,
        city: city ?? '',
        district: district ?? '',
        latitude: latitude,
        longitude: longitude,
        distanceKm: distanceKm,
        serviceKeyIds: serviceKeyIds,
      ),
    ],
  );
}

class OrganizationMapPage {
  const OrganizationMapPage({
    required this.markers,
    required this.count,
    required this.truncated,
    required this.max,
  });

  final List<OrganizationMapMarker> markers;
  final int count;
  final bool truncated;
  final int max;
}

class OrganizationPagination {
  const OrganizationPagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasPrev,
    required this.hasNext,
  });

  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;
}

class OrganizationFacets {
  const OrganizationFacets({this.cities = const [], this.districts = const []});

  final List<String> cities;
  final List<String> districts;
}

class OrganizationPage {
  const OrganizationPage({
    required this.organizations,
    required this.pagination,
    this.facets = const OrganizationFacets(),
  });

  final List<Organization> organizations;
  final OrganizationPagination pagination;
  final OrganizationFacets facets;
}
