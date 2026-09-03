import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';

/// Service-history repository for **real API builds**, where no history
/// endpoint exists yet (D-014). Every read throws [FeatureUnavailableFailure]
/// so the UI shows an honest "coming soon" state instead of the fake seed data
/// [FakeServiceHistoryRepository] serves in fake mode / tests.
class UnavailableServiceHistoryRepository implements ServiceHistoryRepository {
  const UnavailableServiceHistoryRepository();

  @override
  Future<List<ServiceOrder>> getServiceHistory() async =>
      throw const FeatureUnavailableFailure();

  @override
  Future<ServiceOrderDetail> getServiceOrderDetail(String id) async =>
      throw const FeatureUnavailableFailure();
}
