/// 반려동물 모델
class Pet {
  final String id;
  final String userId;
  final String name;
  final String species; // 'dog', 'cat', 'bird', 'hamster' 등
  final String? breed;
  final DateTime? birthDate;
  final String? gender; // 'male', 'female', 'unknown'
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.gender,
    this.profileImageUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      gender: json['gender'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'species': species,
      'breed': breed,
      'birth_date': birthDate?.toIso8601String().split('T').first,
      'gender': gender,
      'profile_image_url': profileImageUrl,
      'is_active': isActive,
    };
  }

  /// Insert용 JSON (id, timestamps 제외)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'species': species,
      if (breed != null) 'breed': breed,
      if (birthDate != null)
        'birth_date': birthDate!.toIso8601String().split('T').first,
      if (gender != null) 'gender': gender,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
      'is_active': isActive,
    };
  }

  Pet copyWith({
    String? id,
    String? userId,
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    String? profileImageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      species: species ?? this.species,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pet && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
