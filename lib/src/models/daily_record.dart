/// 일일 건강 기록 모델 (캘린더용)
class DailyRecord {
  final String? id;
  final String petId;
  final DateTime recordedDate;
  final String? notes;
  final String? mood; // 'great', 'good', 'normal', 'bad', 'sick'
  final int? activityLevel; // 1~5
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DailyRecord({
    this.id,
    required this.petId,
    required this.recordedDate,
    this.notes,
    this.mood,
    this.activityLevel,
    this.createdAt,
    this.updatedAt,
  });

  factory DailyRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecord(
      id: json['id'] as String?,
      petId: json['pet_id'] as String,
      recordedDate: DateTime.parse(json['recorded_date'] as String),
      notes: json['notes'] as String?,
      mood: json['mood'] as String?,
      activityLevel: json['activity_level'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'pet_id': petId,
      'recorded_date': recordedDate.toIso8601String().split('T').first,
      if (notes != null) 'notes': notes,
      if (mood != null) 'mood': mood,
      if (activityLevel != null) 'activity_level': activityLevel,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'pet_id': petId,
      'recorded_date': recordedDate.toIso8601String().split('T').first,
      if (notes != null) 'notes': notes,
      if (mood != null) 'mood': mood,
      if (activityLevel != null) 'activity_level': activityLevel,
    };
  }

  DailyRecord copyWith({
    String? id,
    String? petId,
    DateTime? recordedDate,
    String? notes,
    String? mood,
    int? activityLevel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      recordedDate: recordedDate ?? this.recordedDate,
      notes: notes ?? this.notes,
      mood: mood ?? this.mood,
      activityLevel: activityLevel ?? this.activityLevel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyRecord && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 기분 enum
enum Mood {
  great('great', '최고'),
  good('good', '좋음'),
  normal('normal', '보통'),
  bad('bad', '나쁨'),
  sick('sick', '아픔');

  final String value;
  final String label;

  const Mood(this.value, this.label);

  static Mood? fromValue(String? value) {
    if (value == null) return null;
    return Mood.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Mood.normal,
    );
  }
}
