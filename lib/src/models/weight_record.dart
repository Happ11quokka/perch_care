class WeightRecord {
  final String? id;
  final String petId;
  final DateTime date;
  final double weight; // in grams
  final String? memo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WeightRecord({
    this.id,
    required this.petId,
    required this.date,
    required this.weight,
    this.memo,
    this.createdAt,
    this.updatedAt,
  });

  // Supabase JSON 역직렬화
  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['id'] as String?,
      petId: json['pet_id'] as String,
      date: DateTime.parse(json['recorded_date'] as String),
      weight: (json['weight'] as num).toDouble(),
      memo: json['memo'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  // Supabase JSON 직렬화
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      date: date ?? this.date,
      weight: weight ?? this.weight,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

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
