import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';
import 'package:flutter/foundation.dart';

enum OrganizationDetailStatus { initial, loading, data, error }

class OrganizationDetailController extends ChangeNotifier {
  OrganizationDetailController(this._repository);

  final OrganizationRepository _repository;
  final Map<String, OrganizationDetail> _cache = {};
  OrganizationDetailStatus status = OrganizationDetailStatus.initial;
  OrganizationDetail? organization;
  String? message;
  String? _requestedSlug;

  Future<void> load(String slug) async {
    if (_requestedSlug == slug && status == OrganizationDetailStatus.loading) {
      return;
    }
    _requestedSlug = slug;
    final cached = _cache[slug];
    if (cached != null) {
      organization = cached;
      status = OrganizationDetailStatus.data;
      message = null;
      notifyListeners();
      return;
    }
    organization = null;
    status = OrganizationDetailStatus.loading;
    message = null;
    notifyListeners();
    try {
      final result = await _repository.getOrganization(slug);
      if (_requestedSlug != slug) return;
      _cache[slug] = result;
      organization = result;
      status = OrganizationDetailStatus.data;
    } on AppFailure catch (failure) {
      if (_requestedSlug != slug) return;
      status = OrganizationDetailStatus.error;
      message = failure.message;
    } catch (_) {
      if (_requestedSlug != slug) return;
      status = OrganizationDetailStatus.error;
      message = 'Тодорхойгүй алдаа гарлаа.';
    }
    notifyListeners();
  }
}
