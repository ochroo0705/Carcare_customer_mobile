import 'package:carcare_customer_mobile/core/errors/app_failure.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/app_notification.dart';
import 'package:carcare_customer_mobile/features/notifications/domain/notification_type.dart';

/// `GET /api/v1/app/notifications` item.
///
/// The server sends the notification's raw `data` map rather than the web's
/// `href`, so the same key set arrives here as in an FCM push payload.
class NotificationDto {
  const NotificationDto({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  factory NotificationDto.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const UnexpectedFailure('Мэдэгдлийн мэдээлэл буруу байна.');
    }
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (createdAt == null) {
      throw const UnexpectedFailure('Мэдэгдлийн огноо буруу байна.');
    }
    return NotificationDto(
      id: id,
      // An unknown type is not an error — the registry grows server-side and
      // an older build must still render the row (see notificationTypeFrom
      // PushData, which falls back to a generic notification).
      type: json['type'] as String?,
      title: _optionalString(json['title']) ?? 'Мэдэгдэл',
      body: _optionalString(json['body']) ?? '',
      data: _stringMap(json['data']),
      read: json['read'] == true,
      createdAt: createdAt.toLocal(),
    );
  }

  final String id;
  final String? type;
  final String title;
  final String body;
  final Map<String, String> data;
  final bool read;
  final DateTime createdAt;

  AppNotification toDomain() => AppNotification(
    id: id,
    type: notificationTypeFromPushData(type),
    title: title,
    message: body,
    createdAt: createdAt,
    isRead: read,
    data: data,
  );
}

List<NotificationDto> parseNotificationListJson(Object? value) {
  if (value is! List) {
    throw const UnexpectedFailure('Мэдэгдлийн жагсаалт буруу байна.');
  }
  return value
      .whereType<Map>()
      .map((item) => NotificationDto.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

/// Deep-link payloads are string-keyed and string-valued by contract; anything
/// else is dropped rather than stringified, so a bad value can't masquerade as
/// an id the router would try to route on.
Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  final result = <String, String>{};
  value.forEach((key, item) {
    if (key is String && item is String && item.isNotEmpty) result[key] = item;
  });
  return result;
}

String? _optionalString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}
