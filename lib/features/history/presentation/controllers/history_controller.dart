import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:flutter/foundation.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this._repository);

  final ServiceHistoryRepository _repository;
  HistoryState _state = const HistoryState();

  HistoryState get state => _state;

  Future<void> load() async {
    _state = HistoryState(status: HistoryStatus.loading, orders: _state.orders);
    notifyListeners();
    try {
      final orders = (await _repository.getServiceHistory()).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
      _state = HistoryState(
        status: orders.isEmpty ? HistoryStatus.empty : HistoryStatus.data,
        orders: orders,
      );
    } on AppFailure catch (failure) {
      _state = HistoryState(
        status: HistoryStatus.error,
        message: failure.message,
      );
    } catch (_) {
      _state = const HistoryState(
        status: HistoryStatus.error,
        message: 'Тодорхойгүй алдаа гарлаа.',
      );
    }
    notifyListeners();
  }

  /// Resets to the initial state, e.g. after the customer signs out.
  void reset() {
    _state = const HistoryState();
    notifyListeners();
  }
}
