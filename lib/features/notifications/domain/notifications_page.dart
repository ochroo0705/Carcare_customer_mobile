import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';

/// One page of notifications plus the **server's** unread total.
///
/// The unread count is not derived from [items] because the list is only the
/// first page: read notifications are pruned after 90 days but unread ones
/// never are, so a customer who ignores the app can hold more unread
/// notifications than one page returns. Deriving it there would quietly cap
/// the bell badge at the page size.
class NotificationsPage {
  const NotificationsPage({required this.items, required this.unreadCount});

  final List<AppNotification> items;
  final int unreadCount;
}
