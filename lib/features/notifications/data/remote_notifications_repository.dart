import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/core/network/api_client.dart';
import 'package:carcare_customer_mobile/features/notifications/data/notification_dto.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_page.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';

/// `/api/v1/app/notifications` adapter.
///
/// The server returns the first page newest-first (50 rows) and the account's
/// own unread total; there is no infinite scroll, because read notifications
/// are pruned after 90 days and the list stays short.
class RemoteNotificationsRepository implements NotificationsRepository {
  RemoteNotificationsRepository(this._client);

  final ApiClient _client;

  @override
  Future<NotificationsPage> getNotifications() async {
    final json = await _client.getJson('/notifications');
    final items = parseNotificationListJson(json['notifications'])
        .map((dto) => dto.toDomain())
        .toList(growable: false);
    final unread = json['unreadCount'];
    return NotificationsPage(
      items: items,
      // Fall back to the page's own unread rows if the server ever omits the
      // count — a wrong badge is better than a failed load.
      unreadCount: unread is num
          ? unread.toInt()
          : items.where((item) => !item.isRead).length,
    );
  }

  @override
  Future<void> markRead(String id) async {
    final json = await _client.patchJson('/notifications/$id/read', const {});
    if (json['ok'] != true) {
      throw const UnexpectedFailure('Мэдэгдлийг уншсан болгож чадсангүй.');
    }
  }

  @override
  Future<void> markAllRead() async {
    final json = await _client.postJson('/notifications/read-all', const {});
    if (json['ok'] != true) {
      throw const UnexpectedFailure('Мэдэгдлийг уншсан болгож чадсангүй.');
    }
  }

  @override
  /// No-op by design. `createNotification` writes the row **before** sending
  /// the push, so the `load()` the controller runs right after this call
  /// already returns the server's own copy — inserting a locally-built one
  /// would duplicate it under a fabricated `push-<timestamp>` id.
  Future<void> addExternal(AppNotification notification) async {}
}
