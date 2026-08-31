import 'package:carcare_customer_mobile/features/discovery/domain/organization.dart';

enum DiscoveryStatus { initial, loading, data, empty, error }

class DiscoveryState {
  const DiscoveryState({
    this.status = DiscoveryStatus.initial,
    this.organizations = const [],
    this.message,
  });
  final DiscoveryStatus status;
  final List<Organization> organizations;
  final String? message;
  bool get isLoading =>
      status == DiscoveryStatus.initial || status == DiscoveryStatus.loading;
}
