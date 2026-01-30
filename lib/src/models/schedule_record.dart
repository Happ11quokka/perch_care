import 'package:flutter/material.dart';

class ScheduleRecord {
  final String id;
  final String petId;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String? description;
  final Color color;
  final int? reminderMinutes; // 알림 (분 전)

  ScheduleRecord({
    String? id,
    required this.petId,
    required this.startTime,
    required this.endTime,
    required this.title,
    this.description,
    required this.color,
    this.reminderMinutes,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // 색상 팔레트 (Figma 디자인 기반)
  static const List<Color> colorPalette = [
    Color(0xFFFF9A42), // Orange (브랜드)
    Color(0xFFFF6B6B), // Red
    Color(0xFFFFD93D), // Yellow
    Color(0xFF6BCB77), // Green
    Color(0xFF4D96FF), // Blue
    Color(0xFF9B59B6), // Purple
    Color(0xFFFF85A2), // Pink
    Color(0xFF00D9FF), // Cyan
    Color(0xFFA8E6CF), // Light Green
    Color(0xFFFFBE76), // Light Orange
    Color(0xFF95A5A6), // Gray
    Color(0xFF2C3E50), // Dark
  ];

  ScheduleRecord copyWith({
    String? id,
    String? petId,
    DateTime? startTime,
    DateTime? endTime,
    String? title,
    String? description,
    Color? color,
    int? reminderMinutes,
  }) {
    return ScheduleRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      title: title ?? this.title,
      description: description ?? this.description,
      color: color ?? this.color,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
    );
  }

  // 시간 포맷 헬퍼
  String get formattedStartTime {
    final hour = startTime.hour;
    final minute = startTime.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$period ${displayHour.toString().padLeft(2, '0')}:$minute';
  }

  String get formattedEndTime {
    final hour = endTime.hour;
    final minute = endTime.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$period ${displayHour.toString().padLeft(2, '0')}:$minute';
  }

  String get formattedTimeRange => '$formattedStartTime - $formattedEndTime';

  String formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}월 ${date.day}일 ($weekday)';
  }

  String get formattedStartDate => formatDate(startTime);
  String get formattedEndDate => formatDate(endTime);

  /// Color를 hex string으로 변환
  String get colorHex {
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2, 8).toUpperCase()}';
  }

  /// hex string을 Color로 변환
  static Color colorFromHex(String hex) {
    final hexCode = hex.replaceAll('#', '');
    return Color(int.parse('FF$hexCode', radix: 16));
  }

  /// JSON 역직렬화
  factory ScheduleRecord.fromJson(Map<String, dynamic> json) {
    return ScheduleRecord(
      id: json['id'] as String,
      petId: json['pet_id'] as String,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      color: colorFromHex(json['color'] as String? ?? '#FF9A42'),
      reminderMinutes: json['reminder_minutes'] as int?,
    );
  }

  /// JSON 직렬화 (조회용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pet_id': petId,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'title': title,
      'description': description,
      'color': colorHex,
      'reminder_minutes': reminderMinutes,
    };
  }

  /// INSERT용 JSON (id, pet_id 제외 — pet_id는 URL path로 전달)
  Map<String, dynamic> toInsertJson() {
    return {
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'title': title,
      'description': description,
      'color': colorHex,
      'reminder_minutes': reminderMinutes,
    };
  }
}
