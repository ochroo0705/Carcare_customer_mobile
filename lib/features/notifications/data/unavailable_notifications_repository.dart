import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notifications_repository.dart';

/// Notifications repository for **real API builds**, where no notifications
/// list/read-state endpoint exists yet (D-014). `getNotifications` throws
/// [FeatureUnavailableFailure] so the in-app list shows an honest "coming soon"
/// state rather than the fake seeds served in fake mode / tests. The mutating
/// methods are no-ops — real push delivery still happens at the OS/local-banner
/// level (`NotificationsController.handleIncomingPush`), which doesn't depend on
/// this list; we simply don't fake a synced, read-state-tracked in-app list.
class UnavailableNotificationsRepository implements NotificationsRepository {
  const UnavailableNotificationsRepository();

  @override
  Future<List<AppNotification>> getNotifications() async =>
      throw const FeatureUnavailableFailure();

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> addExternal(AppNotification notification) async {}
}
