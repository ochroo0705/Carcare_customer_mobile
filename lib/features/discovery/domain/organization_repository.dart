import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';

abstract interface class OrganizationRepository {
  /// [filter] идэвхтэй бол сервер талын "ойролцоо"/"одоо нээлттэй" шүүлтийг
  /// хэрэглэнэ (branch-д `distanceKm` нэмэгдэж болно). null бол бүх жагсаалт.
  Future<OrganizationPage> getOrganizations({OrganizationFilter? filter});
  Future<OrganizationDetail> getOrganization(String slug);
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
