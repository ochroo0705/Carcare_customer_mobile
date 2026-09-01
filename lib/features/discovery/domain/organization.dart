import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';

class Organization {
  const Organization({
    required this.slug,
    required this.name,
    required this.branches,
    this.logoUrl,
  });
  final String slug;
  final String name;
  final String? logoUrl;
  final List<Branch> branches;
}

class OrganizationDetail {
  const OrganizationDetail({
    required this.slug,
    required this.name,
    required this.branches,
    this.logoUrl,
    this.phone,
  });

  final String slug;
  final String name;
  final String? logoUrl;
  final String? phone;
  final List<BranchDetail> branches;
}
