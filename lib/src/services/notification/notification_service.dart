import 'dart:async';
import '../../models/notification.dart';
import '../api/api_client.dart';

/// 알림 관리 서비스
/// FastAPI notifications 엔드포인트와 연동
class NotificationService {
  NotificationService();

  final _api = ApiClient.instance;

  /// 알림 생성
  Future<AppNotification> createNotification({
    required NotificationType type,
    required String title,
    String message = '',
    String? petId,
  }) async {
    final response = await _api.post('/notifications/', body: {
      if (petId != null) 'pet_id': petId,
      'type': type.name,
      'title': title,
      'message': message,
    });

    return AppNotification.fromJson(response);
  }

  /// 현재 사용자의 모든 알림 조회
  Future<List<AppNotification>> fetchNotifications({
    int? limit,
    bool unreadOnly = false,
  }) async {
    final params = <String, String>{};
    if (limit != null) params['limit'] = limit.toString();
    if (unreadOnly) params['unread_only'] = 'true';

    final response = await _api.get(
      '/notifications/',
      queryParams: params.isNotEmpty ? params : null,
    );

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// 읽지 않은 알림 개수 조회
  Future<int> getUnreadCount() async {
    final response = await _api.get('/notifications/unread-count');
    return response['count'] as int;
  }

  /// 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    await _api.put('/notifications/$notificationId/read');
  }

  /// 모든 알림 읽음 처리
  Future<void> markAllAsRead() async {
    await _api.put('/notifications/read-all');
  }

  /// 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    await _api.delete('/notifications/$notificationId');
  }

  /// 모든 알림 삭제
  Future<void> deleteAllNotifications() async {
    await _api.delete('/notifications/');
  }

  /// 특정 펫의 알림 삭제
  Future<void> deleteNotificationsByPetId(String petId) async {
    await _api.delete('/notifications/by-pet/$petId');
  }

  /// 알림 폴링 스트림 (점진적 백오프)
  Stream<List<AppNotification>> subscribeToNotifications() async* {
    int interval = 30;
    const maxInterval = 120;
    while (true) {
      await Future.delayed(Duration(seconds: interval));
      try {
        final notifications = await fetchNotifications();
        yield notifications;
        // 새 알림이 있으면 빠르게, 없으면 점진적으로 늘림
        if (notifications.any((n) => !n.isRead)) {
          interval = 30;
        } else {
          interval = (interval * 1.5).clamp(30, maxInterval).toInt();
        }
      } catch (_) {
        yield <AppNotification>[];
        interval = (interval * 2).clamp(30, maxInterval).toInt();
      }
    }
  }
}
