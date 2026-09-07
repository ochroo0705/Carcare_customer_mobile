import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';

abstract interface class OrganizationRepository {
  /// [filter] идэвхтэй бол сервер талын "ойролцоо"/"одоо нээлттэй" шүүлтийг
  /// хэрэглэнэ (branch-д `distanceKm` нэмэгдэж болно). null бол бүх жагсаалт.
  Future<List<Organization>> getOrganizations({OrganizationFilter? filter});
  Future<OrganizationDetail> getOrganization(String slug);
}
