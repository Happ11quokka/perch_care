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
}
