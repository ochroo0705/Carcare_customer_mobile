import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';
import 'package:carcare_customer_mobile/features/discovery/domain/organization_repository.dart';

enum DiscoveryStatus { initial, loading, data, empty, error }

class DiscoveryState {
  const DiscoveryState({
    this.status = DiscoveryStatus.initial,
    this.organizations = const [],
    this.pagination = const OrganizationPagination(
      page: 1,
      pageSize: 20,
      total: 0,
      totalPages: 1,
      hasPrev: false,
      hasNext: false,
    ),
    this.facets = const OrganizationFacets(),
    this.message,
    this.isFromCache = false,
    this.isLoadingMore = false,
    this.loadMoreMessage,
  });
  final DiscoveryStatus status;
  final List<Organization> organizations;
  final OrganizationPagination pagination;
  final OrganizationFacets facets;
  final String? message;

  /// True when [organizations] is the last successfully loaded list, shown
  /// because a fresh load just failed (e.g. no network) rather than because
  /// it is currently up to date.
  final bool isFromCache;
  final bool isLoadingMore;
  final String? loadMoreMessage;

  bool get isLoading =>
      status == DiscoveryStatus.initial || status == DiscoveryStatus.loading;
}
