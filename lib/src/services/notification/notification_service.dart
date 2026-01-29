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

  /// 알림 폴링 스트림 (30초 간격)
  Stream<List<AppNotification>> subscribeToNotifications() {
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      try {
        return await fetchNotifications(unreadOnly: true);
      } catch (_) {
        return <AppNotification>[];
      }
    }).asyncMap((future) => future);
  }
}
