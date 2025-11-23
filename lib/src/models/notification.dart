import 'package:flutter/material.dart';

/// 알림 타입
enum NotificationType {
  /// 기록 리마인더
  reminder,

  /// 건강 경고
  healthWarning,

  /// 시스템 알림
  system,
}

/// 알림 모델
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  /// 알림 타입에 따른 아이콘 반환
  IconData get icon {
    switch (type) {
      case NotificationType.reminder:
        return Icons.edit_calendar_outlined;
      case NotificationType.healthWarning:
        return Icons.warning_amber_rounded;
      case NotificationType.system:
        return Icons.info_outline;
    }
  }

  /// 알림 타입에 따른 아이콘 색상 반환
  Color get iconColor {
    switch (type) {
      case NotificationType.reminder:
        return const Color(0xFF4CAF50); // 녹색
      case NotificationType.healthWarning:
        return const Color(0xFFFF9A42); // 주황색 (브랜드 컬러)
      case NotificationType.system:
        return const Color(0xFF2196F3); // 파란색
    }
  }

  /// 읽음 상태 토글
  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// 더미 알림 데이터
class NotificationData {
  /// 더미 알림 리스트 생성
  static List<AppNotification> getDummyNotifications({String petName = '초코'}) {
    final now = DateTime.now();

    return [
      AppNotification(
        id: '1',
        type: NotificationType.reminder,
        title: '기록 리마인더',
        message: '$petName 오늘 기록을 해주세요!',
        timestamp: now.subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      AppNotification(
        id: '2',
        type: NotificationType.healthWarning,
        title: '체중 이상 감지',
        message: '현재 기록 데이터를 통해 24일 체중부터 이상한 것 같아요',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: false,
      ),
      AppNotification(
        id: '3',
        type: NotificationType.system,
        title: '앱 업데이트',
        message: '앱이 업데이트되었습니다. 새로운 기능을 확인해보세요!',
        timestamp: now.subtract(const Duration(days: 3)),
        isRead: true,
      ),
    ];
  }

  /// 읽지 않은 알림 개수 반환
  static int getUnreadCount(List<AppNotification> notifications) {
    return notifications.where((n) => !n.isRead).length;
  }
}
