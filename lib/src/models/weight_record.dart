class WeightRecord {
  final String? id;
  final String petId;
  final DateTime date;
  final double weight; // in grams
  final String? memo;
  final int? recordedHour;   // 0-23, null이면 시간 미기록 (기존 데이터 호환)
  final int? recordedMinute; // 0-59
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WeightRecord({
    this.id,
    required this.petId,
    required this.date,
    required this.weight,
    this.memo,
    this.recordedHour,
    this.recordedMinute,
    this.createdAt,
    this.updatedAt,
  });

  // JSON 역직렬화
  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['id'] as String?,
      petId: json['pet_id'] as String,
      date: DateTime.parse(json['recorded_date'] as String),
      weight: (json['weight'] as num).toDouble(),
      memo: json['memo'] as String?,
      recordedHour: json['recorded_hour'] as int?,
      recordedMinute: json['recorded_minute'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'pet_id': petId,
      'recorded_date': date.toIso8601String().split('T').first,
      'weight': weight,
      if (memo != null) 'memo': memo,
    };
  }

  /// Insert용 JSON (id 제외)
  Map<String, dynamic> toInsertJson() {
    return {
      'pet_id': petId,
      'recorded_date': date.toIso8601String().split('T').first,
      'weight': weight,
      if (memo != null) 'memo': memo,
    };
  }

  // copyWith 메서드
  WeightRecord copyWith({
    String? id,
    String? petId,
    DateTime? date,
    double? weight,
    String? memo,
    int? recordedHour,
    int? recordedMinute,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      memo: memo ?? this.memo,
      recordedHour: recordedHour ?? this.recordedHour,
      recordedMinute: recordedMinute ?? this.recordedMinute,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// 시간이 기록되었는지 여부
  bool get hasTime => recordedHour != null && recordedMinute != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          date == other.date &&
          weight == other.weight;

  @override
  int get hashCode => id.hashCode ^ date.hashCode ^ weight.hashCode;
}
