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
  final String userId;
  final String? petId;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.userId,
    this.petId,
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

  /// JSON 역직렬화
  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      petId: json['pet_id'] as String?,
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: json['title'] as String,
      message: json['message'] as String? ?? '',
      timestamp: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pet_id': petId,
      'type': type.name,
      'title': title,
      'message': message,
      'is_read': isRead,
    };
  }

  /// INSERT용 JSON (id 제외)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'pet_id': petId,
      'type': type.name,
      'title': title,
      'message': message,
      'is_read': isRead,
    };
  }

  /// 읽음 상태 토글
  AppNotification copyWith({
    String? id,
    String? userId,
    String? petId,
    NotificationType? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      petId: petId ?? this.petId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}
