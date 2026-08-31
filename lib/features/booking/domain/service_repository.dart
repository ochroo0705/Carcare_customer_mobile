import 'package:carcare_customer_mobile/features/booking/domain/service_catalog.dart';

abstract interface class ServiceRepository {
  Future<ServiceCatalog> getServicesForBranch(String branchId);
}
