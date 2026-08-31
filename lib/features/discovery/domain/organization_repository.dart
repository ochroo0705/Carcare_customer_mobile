import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';

abstract interface class OrganizationRepository {
  Future<List<Organization>> getOrganizations();
}
