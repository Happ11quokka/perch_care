import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/notification.dart';

/// 알림 관리 서비스
/// Supabase notifications 테이블과 연동
class NotificationService {
  final _supabase = Supabase.instance.client;
  static const _tableName = 'notifications';

  /// 현재 로그인한 사용자 ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// 알림 생성
  Future<AppNotification> createNotification({
    required NotificationType type,
    required String title,
    String message = '',
    String? petId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final data = {
      'user_id': _currentUserId,
      'pet_id': petId,
      'type': type.name,
      'title': title,
      'message': message,
      'is_read': false,
    };

    final response = await _supabase
        .from(_tableName)
        .insert(data)
        .select()
        .single();

    return AppNotification.fromJson(response);
  }

  /// 현재 사용자의 모든 알림 조회
  Future<List<AppNotification>> fetchNotifications({
    int? limit,
    bool unreadOnly = false,
  }) async {
    if (_currentUserId == null) {
      return [];
    }

    var query = _supabase
        .from(_tableName)
        .select()
        .eq('user_id', _currentUserId!);

    if (unreadOnly) {
      query = query.eq('is_read', false);
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit ?? 100);

    return (response as List)
        .map((json) => AppNotification.fromJson(json))
        .toList();
  }

  /// 읽지 않은 알림 개수 조회
  Future<int> getUnreadCount() async {
    if (_currentUserId == null) {
      return 0;
    }

    final response = await _supabase
        .from(_tableName)
        .select('id')
        .eq('user_id', _currentUserId!)
        .eq('is_read', false);

    return (response as List).length;
  }

  /// 알림 읽음 처리
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from(_tableName)
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// 모든 알림 읽음 처리
  Future<void> markAllAsRead() async {
    if (_currentUserId == null) return;

    await _supabase
        .from(_tableName)
        .update({'is_read': true})
        .eq('user_id', _currentUserId!)
        .eq('is_read', false);
  }

  /// 알림 삭제
  Future<void> deleteNotification(String notificationId) async {
    await _supabase
        .from(_tableName)
        .delete()
        .eq('id', notificationId);
  }

  /// 모든 알림 삭제
  Future<void> deleteAllNotifications() async {
    if (_currentUserId == null) return;

    await _supabase
        .from(_tableName)
        .delete()
        .eq('user_id', _currentUserId!);
  }

  /// 특정 펫의 알림 삭제
  Future<void> deleteNotificationsByPetId(String petId) async {
    await _supabase
        .from(_tableName)
        .delete()
        .eq('pet_id', petId);
  }

  /// 알림 실시간 구독 (Stream)
  Stream<List<AppNotification>> subscribeToNotifications() {
    if (_currentUserId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from(_tableName)
        .stream(primaryKey: ['id'])
        .eq('user_id', _currentUserId!)
        .order('created_at', ascending: false)
        .map((data) => data
            .map((json) => AppNotification.fromJson(json))
            .toList());
  }
}
