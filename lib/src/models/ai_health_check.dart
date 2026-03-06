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
  int get hashCode => (id ?? '').hashCode;
}

/// 건강 체크 타입 enum
enum HealthCheckType {
  eye('eye'),
  skin('skin'),
  posture('posture'),
  oral('oral'),
  ear('ear'),
  general('general');

  final String value;

  const HealthCheckType(this.value);

  static HealthCheckType fromValue(String value) {
    return HealthCheckType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HealthCheckType.general,
    );
  }
}

/// 건강 상태 enum
enum HealthStatus {
  normal('normal'),
  warning('warning'),
  danger('danger');

  final String value;

  const HealthStatus(this.value);

  static HealthStatus fromValue(String value) {
    return HealthStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HealthStatus.normal,
    );
  }
}

/// Vision 분석 모드
enum VisionMode {
  fullBody('full_body'),
  partSpecific('part_specific'),
  droppings('droppings'),
  food('food');

  final String value;

  const VisionMode(this.value);

  static VisionMode fromValue(String value) {
    return VisionMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VisionMode.fullBody,
    );
  }
}

/// 부위별 검사 대상 (part_specific 모드용)
enum BodyPart {
  eye('eye'),
  beak('beak'),
  feather('feather'),
  foot('foot');

  final String value;

  const BodyPart(this.value);

  static BodyPart fromValue(String value) {
    return BodyPart.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BodyPart.eye,
    );
  }
}
