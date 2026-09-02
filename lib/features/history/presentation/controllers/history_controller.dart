import 'dart:convert';

import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_history_repository.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order.dart';
import 'package:carcare_customer_mobile/features/history/domain/service_order_status.dart';
import 'package:carcare_customer_mobile/features/history/presentation/controllers/history_state.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryController extends ChangeNotifier {
  HistoryController(this._repository);

  static const _cacheKey = 'history_cache_v1';

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
      await _saveCache(orders);
    } on AppFailure catch (failure) {
      _state = await _fallbackToCache(failure.message);
    } catch (_) {
      _state = await _fallbackToCache('Тодорхойгүй алдаа гарлаа.');
    }
    notifyListeners();
  }

  /// Resets to the initial state and clears the on-disk cache, e.g. after
  /// the customer signs out — the next account must never see this one's
  /// cached service history.
  Future<void> reset() async {
    _state = const HistoryState();
    notifyListeners();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_cacheKey);
    } catch (_) {
      // Best-effort — a stale cache is overwritten by the next load() anyway.
    }
  }

  Future<HistoryState> _fallbackToCache(String failureMessage) async {
    final cached = await _readCache();
    if (cached == null || cached.isEmpty) {
      return HistoryState(status: HistoryStatus.error, message: failureMessage);
    }
    return HistoryState(
      status: HistoryStatus.data,
      orders: cached,
      isFromCache: true,
      message: failureMessage,
    );
  }

  Future<void> _saveCache(List<ServiceOrder> orders) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final json = jsonEncode(orders.map(_orderToJson).toList());
      await preferences.setString(_cacheKey, json);
    } catch (_) {
      // Persisting the cache is a best-effort convenience; a write failure
      // here must never surface as a load failure.
    }
  }

  Future<List<ServiceOrder>?> _readCache() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_cacheKey);
      if (raw == null) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      final orders = decoded
          .map(_orderFromJson)
          .whereType<ServiceOrder>()
          .toList();
      return orders.isEmpty ? null : orders;
    } catch (_) {
      return null;
    }
  }
}

Map<String, dynamic> _orderToJson(ServiceOrder order) => {
  'id': order.id,
  'tenantName': order.tenantName,
  'tenantSlug': order.tenantSlug,
  'branchName': order.branchName,
  'completedAt': order.completedAt.toIso8601String(),
  'status': order.status.name,
  'totalAmount': order.totalAmount,
  'paidAmount': order.paidAmount,
  'vehiclePlate': order.vehiclePlate,
};

ServiceOrder? _orderFromJson(Object? value) {
  if (value is! Map) return null;
  final id = value['id'];
  final tenantName = value['tenantName'];
  final tenantSlug = value['tenantSlug'];
  final branchName = value['branchName'];
  final completedAtRaw = value['completedAt'];
  final statusName = value['status'];
  final totalAmount = value['totalAmount'];
  final paidAmount = value['paidAmount'];
  if (id is! String ||
      tenantName is! String ||
      tenantSlug is! String ||
      branchName is! String ||
      completedAtRaw is! String ||
      statusName is! String ||
      totalAmount is! num ||
      paidAmount is! num) {
    return null;
  }
  final completedAt = DateTime.tryParse(completedAtRaw);
  if (completedAt == null) return null;
  return ServiceOrder(
    id: id,
    tenantName: tenantName,
    tenantSlug: tenantSlug,
    branchName: branchName,
    completedAt: completedAt,
    status: ServiceOrderStatus.values.firstWhere(
      (status) => status.name == statusName,
      orElse: () => ServiceOrderStatus.unpaid,
    ),
    totalAmount: totalAmount.toInt(),
    paidAmount: paidAmount.toInt(),
    vehiclePlate: value['vehiclePlate'] is String
        ? value['vehiclePlate'] as String
        : null,
  );
}
