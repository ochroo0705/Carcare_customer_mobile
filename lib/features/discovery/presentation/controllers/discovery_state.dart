import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';

enum DiscoveryStatus { initial, loading, data, empty, error }

class DiscoveryState {
  const DiscoveryState({
    this.status = DiscoveryStatus.initial,
    this.organizations = const [],
    this.message,
    this.isFromCache = false,
  });
  final DiscoveryStatus status;
  final List<Organization> organizations;
  final String? message;

  /// True when [organizations] is the last successfully loaded list, shown
  /// because a fresh load just failed (e.g. no network) rather than because
  /// it is currently up to date.
  final bool isFromCache;

  bool get isLoading =>
      status == DiscoveryStatus.initial || status == DiscoveryStatus.loading;
}
