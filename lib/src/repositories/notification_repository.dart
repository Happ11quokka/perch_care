import '../models/notification.dart';
import '../services/notification/notification_service.dart';

/// 알림 Repository — ViewModel/Screen이 `NotificationService`를 직접 알지 못하도록 래핑한다.
///
/// 화면(NotificationScreen)이 실사용하는 5메서드만 노출(fetch/markAsRead/markAllAsRead/
/// delete/subscribe). `getUnreadCount`는 현재 호출부가 없어 YAGNI로 제외.
abstract class NotificationRepository {
  Future<List<AppNotification>> fetch({int? limit, bool unreadOnly = false});
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> delete(String id);
  Stream<List<AppNotification>> subscribe();
}

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({NotificationService? service})
      : _service = service ?? NotificationService.instance;

  final NotificationService _service;

  @override
  Future<List<AppNotification>> fetch({
    int? limit,
    bool unreadOnly = false,
  }) async =>
      _service.fetchNotifications(limit: limit, unreadOnly: unreadOnly);

  @override
  Future<void> markAsRead(String id) => _service.markAsRead(id);

  @override
  Future<void> markAllAsRead() => _service.markAllAsRead();

  @override
  Future<void> delete(String id) => _service.deleteNotification(id);

  @override
  Stream<List<AppNotification>> subscribe() =>
      _service.subscribeToNotifications();
}
