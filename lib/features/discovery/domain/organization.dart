import 'package:carcare_customer_mobile/features/discovery/domain/branch.dart';

class Organization {
  const Organization({
    required this.slug,
    required this.name,
    required this.phone,
    required this.branches,
    this.logoUrl,
  });
  final String slug;
  final String name;
  final String phone;
  final String? logoUrl;
  final List<Branch> branches;
  bool get hasOpenBranch => branches.any((branch) => branch.isOpen);
}
