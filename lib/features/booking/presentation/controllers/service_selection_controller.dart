import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/booking/domain/bookable_service.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_catalog.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_category.dart';
import 'package:carcare_customer_mobile/features/booking/domain/service_repository.dart';
import 'package:flutter/foundation.dart';

class ServiceSelectionController extends ChangeNotifier {
  ServiceSelectionController(this._repository, this.branchId);

  final ServiceRepository _repository;
  final String branchId;

  bool isLoading = false;
  String? errorMessage;
  List<ServiceCategory> categories = const [];
  List<BookableService> services = const [];
  String? selectedCategoryId;
  final Set<String> _selectedServiceIds = {};

  List<BookableService> get selectedServices => services
      .where((service) => _selectedServiceIds.contains(service.id))
      .toList(growable: false);

  int get totalPrice =>
      selectedServices.fold(0, (sum, item) => sum + item.price);
  int get totalDurationMinutes =>
      selectedServices.fold(0, (sum, item) => sum + item.durationMinutes);

  List<BookableService> get visibleServices => selectedCategoryId == null
      ? services
      : services
            .where((service) => service.categoryId == selectedCategoryId)
            .toList(growable: false);

  bool isSelected(String serviceId) => _selectedServiceIds.contains(serviceId);

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final ServiceCatalog catalog = await _repository.getServicesForBranch(
        branchId,
      );
      categories = catalog.categories;
      services = catalog.services;
      _selectedServiceIds.removeWhere(
        (id) => !services.any((service) => service.id == id),
      );
    } on AppFailure catch (failure) {
      errorMessage = failure.message;
    } catch (_) {
      errorMessage = 'Тодорхойгүй алдаа гарлаа.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCategory(String? categoryId) {
    selectedCategoryId = categoryId;
    notifyListeners();
  }

  void toggleService(String serviceId) {
    if (!_selectedServiceIds.add(serviceId)) {
      _selectedServiceIds.remove(serviceId);
    }
    notifyListeners();
  }
}
