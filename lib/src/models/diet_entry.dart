/// 식이 기록 유형: 배식(serving) 또는 취식(eating)
enum DietType { serving, eating }

/// 개별 식이 기록 항목
class DietEntry {
  final String foodName;
  final DietType type;
  final double grams;
  final int? recordedHour;   // 0-23
  final int? recordedMinute; // 0-59
  final String? memo;

  const DietEntry({
    required this.foodName,
    required this.type,
    required this.grams,
    this.recordedHour,
    this.recordedMinute,
    this.memo,
  });

  /// 시간이 기록되었는지 여부
  bool get hasTime => recordedHour != null && recordedMinute != null;

  /// 시간 표시 문자열 (예: "오전 8:30")
  String get timeDisplayString {
    if (!hasTime) return '';
    final hour = recordedHour!;
    final minute = recordedMinute!;
    final isAM = hour < 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = isAM ? '오전' : '오후';
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }

  factory DietEntry.fromJson(Map<String, dynamic> json) {
    return DietEntry(
      foodName: json['foodName'] as String? ?? '',
      type: json['type'] == 'serving' ? DietType.serving : DietType.eating,
      grams: (json['grams'] as num?)?.toDouble() ?? 0,
      recordedHour: json['recordedHour'] as int?,
      recordedMinute: json['recordedMinute'] as int?,
      memo: json['memo'] as String?,
    );
  }

  /// 기존 _FoodEntry JSON 형식으로부터 마이그레이션
  factory DietEntry.fromLegacyJson(Map<String, dynamic> json) {
    return DietEntry(
      foodName: json['name'] as String? ?? '',
      type: DietType.eating, // 기존 데이터는 모두 취식으로 간주
      grams: (json['totalGrams'] as num?)?.toDouble() ?? 0,
      recordedHour: null,
      recordedMinute: null,
      memo: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodName': foodName,
      'type': type == DietType.serving ? 'serving' : 'eating',
      'grams': grams,
      if (recordedHour != null) 'recordedHour': recordedHour,
      if (recordedMinute != null) 'recordedMinute': recordedMinute,
      if (memo != null) 'memo': memo,
    };
  }

  DietEntry copyWith({
    String? foodName,
    DietType? type,
    double? grams,
    int? recordedHour,
    int? recordedMinute,
    String? memo,
  }) {
    return DietEntry(
      foodName: foodName ?? this.foodName,
      type: type ?? this.type,
      grams: grams ?? this.grams,
      recordedHour: recordedHour ?? this.recordedHour,
      recordedMinute: recordedMinute ?? this.recordedMinute,
      memo: memo ?? this.memo,
    );
  }
}
