import 'package:carcare_customer_mobile/features/booking/domain/bookable_service.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_category.dart';

class ServiceCatalog {
  const ServiceCatalog({required this.categories, required this.services});

  final List<ServiceCategory> categories;
  final List<BookableService> services;
}
