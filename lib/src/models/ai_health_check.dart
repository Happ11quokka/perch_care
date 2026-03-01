/// AI 건강 체크 기록 모델
class AiHealthCheck {
  final String? id;
  final String petId;
  final String checkType; // 'eye', 'skin', 'posture' 등
  final String? imageUrl;
  final Map<String, dynamic> result; // AI 분석 결과
  final double? confidenceScore; // 신뢰도 (0~100)
  final String status; // 'normal', 'warning', 'danger'
  final DateTime checkedAt;
  final DateTime? createdAt;

  const AiHealthCheck({
    this.id,
    required this.petId,
    required this.checkType,
    this.imageUrl,
    required this.result,
    this.confidenceScore,
    this.status = 'normal',
    required this.checkedAt,
    this.createdAt,
  });

  factory AiHealthCheck.fromJson(Map<String, dynamic> json) {
    return AiHealthCheck(
      id: json['id'] as String?,
      petId: json['pet_id'] as String,
      checkType: json['check_type'] as String,
      imageUrl: json['image_url'] as String?,
      result: json['result'] as Map<String, dynamic>,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'normal',
      checkedAt: DateTime.parse(json['checked_at'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'pet_id': petId,
      'check_type': checkType,
      if (imageUrl != null) 'image_url': imageUrl,
      'result': result,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      'status': status,
      'checked_at': checkedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'pet_id': petId,
      'check_type': checkType,
      if (imageUrl != null) 'image_url': imageUrl,
      'result': result,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      'status': status,
      'checked_at': checkedAt.toIso8601String(),
    };
  }

  AiHealthCheck copyWith({
    String? id,
    String? petId,
    String? checkType,
    String? imageUrl,
    Map<String, dynamic>? result,
    double? confidenceScore,
    String? status,
    DateTime? checkedAt,
    DateTime? createdAt,
  }) {
    return AiHealthCheck(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      checkType: checkType ?? this.checkType,
      imageUrl: imageUrl ?? this.imageUrl,
      result: result ?? this.result,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      status: status ?? this.status,
      checkedAt: checkedAt ?? this.checkedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiHealthCheck &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// 건강 체크 타입 enum
enum HealthCheckType {
  eye('eye', '눈 건강'),
  skin('skin', '피부 건강'),
  posture('posture', '자세/체형'),
  oral('oral', '구강 건강'),
  ear('ear', '귀 건강'),
  general('general', '전체 건강');

  final String value;
  final String label;

  const HealthCheckType(this.value, this.label);

  static HealthCheckType fromValue(String value) {
    return HealthCheckType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HealthCheckType.general,
    );
  }
}

/// 건강 상태 enum
enum HealthStatus {
  normal('normal', '정상'),
  warning('warning', '주의'),
  danger('danger', '위험');

  final String value;
  final String label;

  const HealthStatus(this.value, this.label);

  static HealthStatus fromValue(String value) {
    return HealthStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HealthStatus.normal,
    );
  }
}

/// Vision 분석 모드
enum VisionMode {
  fullBody('full_body', '전체 외형'),
  partSpecific('part_specific', '부위별 검사'),
  droppings('droppings', '배변 분석'),
  food('food', '먹이 안전성');

  final String value;
  final String label;

  const VisionMode(this.value, this.label);

  static VisionMode fromValue(String value) {
    return VisionMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VisionMode.fullBody,
    );
  }
}

/// 부위별 검사 대상 (part_specific 모드용)
enum BodyPart {
  eye('eye', '눈'),
  beak('beak', '부리'),
  feather('feather', '깃털'),
  foot('foot', '발');

  final String value;
  final String label;

  const BodyPart(this.value, this.label);

  static BodyPart fromValue(String value) {
    return BodyPart.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BodyPart.eye,
    );
  }
}
