import '../../models/pet.dart';
import '../api/api_client.dart';

/// 반려동물 CRUD 서비스
class PetService {
  PetService();

  final _api = ApiClient.instance;

  /// 내 반려동물 목록 조회
  Future<List<Pet>> getMyPets() async {
    final response = await _api.get('/pets/');
    return (response as List).map((json) => Pet.fromJson(json)).toList();
  }

  /// 활성화된 반려동물 조회
  Future<Pet?> getActivePet() async {
    final response = await _api.get('/pets/active');
    return response != null ? Pet.fromJson(response) : null;
  }

  /// 특정 반려동물 조회
  Future<Pet?> getPetById(String petId) async {
    try {
      final response = await _api.get('/pets/$petId');
      return Pet.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  /// 반려동물 생성
  Future<Pet> createPet({
    required String name,
    required String species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    double? weight,
    DateTime? adoptionDate,
    String? profileImageUrl,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'species': species,
      if (breed != null) 'breed': breed,
      if (birthDate != null)
        'birth_date': birthDate.toIso8601String().split('T').first,
      if (gender != null) 'gender': gender,
      if (weight != null) 'weight': weight,
      if (adoptionDate != null)
        'adoption_date': adoptionDate.toIso8601String().split('T').first,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
    };

    final response = await _api.post('/pets/', body: body);
    return Pet.fromJson(response);
  }

  /// 반려동물 수정
  Future<Pet> updatePet({
    required String petId,
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    double? weight,
    DateTime? adoptionDate,
    String? profileImageUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (species != null) updates['species'] = species;
    if (breed != null) updates['breed'] = breed;
    if (birthDate != null) {
      updates['birth_date'] = birthDate.toIso8601String().split('T').first;
    }
    if (gender != null) updates['gender'] = gender;
    if (weight != null) updates['weight'] = weight;
    if (adoptionDate != null) {
      updates['adoption_date'] = adoptionDate.toIso8601String().split('T').first;
    }
    if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;

    final response = await _api.put('/pets/$petId', body: updates);
    return Pet.fromJson(response);
  }

  /// 반려동물 삭제
  Future<void> deletePet(String petId) async {
    await _api.delete('/pets/$petId');
  }

  /// 활성 펫 변경
  Future<void> setActivePet(String petId) async {
    await _api.put('/pets/$petId/activate');
  }
}
