import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/notifications/local_push_service.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:carcare_customer_mobile/features/notifications/presentation/controllers/notifications_state.dart';
import 'package:flutter/foundation.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this._repository, [LocalPushService? pushService])
    : _pushService = pushService ?? LocalPushService.instance;

  final NotificationsRepository _repository;
  final LocalPushService _pushService;
  NotificationsState _state = const NotificationsState();

  /// `markRead`/`markAllRead`/`handleIncomingPush` each trigger their own
  /// `load()` on top of a possible manual refresh, so calls can overlap (e.g.
  /// a pull-to-refresh in flight when the customer taps "mark read", or a
  /// push arriving mid-refresh) — without this, a slower call finishing after
  /// a faster one can silently revert state it already moved past (a just
  /// -read notification flipping back to unread). Incremented at the start of
  /// every `load()`; only the call that is still the latest may apply.
  int _loadRequestId = 0;

  // True while a successful load's data is on screen; a failed reload then
  // keeps it (with a message) rather than replacing it with an error state.
  bool _hasLiveData = false;

  NotificationsState get state => _state;

  /// The server's unread total, not a count over the loaded page — the list
  /// is capped at one page while unread notifications are never pruned.
  int get unreadCount => _state.unreadCount;

  Future<void> load() async {
    final requestId = ++_loadRequestId;
    _state = NotificationsState(
      status: NotificationsStatus.loading,
      notifications: _state.notifications,
      unreadCount: _state.unreadCount,
    );
    notifyListeners();
    NotificationsState result;
    try {
      final page = await _repository.getNotifications();
      final notifications = page.items.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      result = NotificationsState(
        status: notifications.isEmpty
            ? NotificationsStatus.empty
            : NotificationsStatus.data,
        notifications: notifications,
        unreadCount: page.unreadCount,
      );
    } on FeatureUnavailableFailure {
      // Real API build: no notifications-list endpoint yet (D-014). The in-app
      // list shows "coming soon"; real pushes still surface via the OS/local
      // banner in handleIncomingPush, which doesn't depend on the list.
      result = const NotificationsState(
        status: NotificationsStatus.unavailable,
      );
    } on AppFailure catch (failure) {
      result = _resultAfterFailure(failure.message);
    } catch (_) {
      result = _resultAfterFailure('Тодорхойгүй алдаа гарлаа.');
    }
    if (requestId != _loadRequestId) return;
    _hasLiveData = result.status == NotificationsStatus.data;
    _state = result;
    notifyListeners();
  }

  NotificationsState _resultAfterFailure(String message) {
    if (_hasLiveData) {
      return NotificationsState(
        status: NotificationsStatus.data,
        notifications: _state.notifications,
        unreadCount: _state.unreadCount,
        message: message,
      );
    }
    return NotificationsState(
      status: NotificationsStatus.error,
      message: message,
    );
  }

  /// Resets to the initial state, e.g. after the customer signs out.
  void reset() {
    _loadRequestId++;
    _hasLiveData = false;
    _state = const NotificationsState();
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    try {
      await _repository.markRead(id);
      await load();
    } catch (_) {
      // Best-effort; a failed mark-read isn't worth surfacing an error for.
    }
  }

  Future<void> markAllRead() async {
    try {
      await _repository.markAllRead();
      await load();
    } catch (_) {
      // Best-effort; a failed mark-all-read isn't worth surfacing an error for.
    }
  }

  /// Called when a real FCM message arrives while the app is in the
  /// foreground (foreground messages don't auto-display, unlike
  /// background/terminated ones, which the OS shows on its own). Takes plain
  /// fields rather than a `RemoteMessage` so this controller doesn't depend
  /// on the `firebase_messaging` package directly — the caller (router
  /// wiring) does that mapping.
  Future<void> handleIncomingPush({
    required String? title,
    required String? body,
    required Map<String, dynamic> data,
  }) async {
    final notification = AppNotification(
      id: 'push-${DateTime.now().microsecondsSinceEpoch}',
      type: notificationTypeFromPushData(
        data['type'] is String ? data['type'] as String : null,
      ),
      title: title ?? 'Мэдэгдэл',
      message: body ?? '',
      createdAt: DateTime.now(),
      isRead: false,
      // Keep the routable ids so a tap on this row deep-links exactly like a
      // tap on the banner itself (fake mode; in a real build the row is
      // replaced by the server's own copy on the `load()` below).
      data: {
        for (final entry in data.entries)
          if (entry.value is String && (entry.value as String).isNotEmpty)
            entry.key: entry.value as String,
      },
    );
    try {
      await _repository.addExternal(notification);
      await load();
    } catch (_) {
      // The in-app list may be unavailable in a real build — never let that
      // stop the local banner below, which is the actual notification.
    }
    await _pushService.show(notification);
  }
}
