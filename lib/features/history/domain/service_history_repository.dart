import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_detail.dart';

abstract interface class ServiceHistoryRepository {
  Future<List<ServiceOrder>> getServiceHistory();

  Future<ServiceOrderDetail> getServiceOrderDetail(String id);
}
