import 'package:flutter/foundation.dart';
import '../../models/pet.dart';
import '../api/api_client.dart';
import 'pet_local_cache_service.dart';

/// 반려동물 CRUD 서비스 (인메모리 캐시 + 로컬 캐시 폴백)
class PetService {
  PetService._();
  static final instance = PetService._();

  final _api = ApiClient.instance;
  final _petCache = PetLocalCacheService.instance;

  // 인메모리 캐시
  Pet? _cachedActivePet;
  List<Pet>? _cachedPets;
  DateTime? _lastActivePetFetch;
  DateTime? _lastPetsFetch;
  static const _cacheDuration = Duration(minutes: 5);

  bool _isActivePetCacheValid() =>
      _lastActivePetFetch != null &&
      DateTime.now().difference(_lastActivePetFetch!) < _cacheDuration;

  bool _isPetsCacheValid() =>
      _lastPetsFetch != null &&
      DateTime.now().difference(_lastPetsFetch!) < _cacheDuration;

  /// 캐시 무효화 (데이터 변경 후 호출)
  void invalidateCache() {
    _cachedActivePet = null;
    _cachedPets = null;
    _lastActivePetFetch = null;
    _lastPetsFetch = null;
  }

  /// 내 반려동물 목록 조회 (캐시-우선)
  Future<List<Pet>> getMyPets({bool forceRefresh = false}) async {
    // 1순위: 인메모리 캐시
    if (!forceRefresh && _isPetsCacheValid() && _cachedPets != null) {
      debugPrint('[PetService] getMyPets() → cache hit');
      return _cachedPets!;
    }

    try {
      // 2순위: 서버 API
      final response = await _api.get('/pets/');
      final pets = (response as List).map((json) => Pet.fromJson(json)).toList();
      _cachedPets = pets;
      _lastPetsFetch = DateTime.now();
      debugPrint('[PetService] getMyPets() → server (${pets.length} pets)');
      return pets;
    } catch (e) {
      // 3순위: 만료된 인메모리 캐시
      if (_cachedPets != null) {
        debugPrint('[PetService] getMyPets() → stale cache fallback');
        return _cachedPets!;
      }
      // 4순위: 로컬 영속 캐시
      final cached = await _petCache.getPets();
      if (cached.isNotEmpty) {
        debugPrint('[PetService] getMyPets() → local cache fallback');
        return cached.map((c) => Pet(
          id: c.id,
          userId: '',
          name: c.name,
          species: c.species ?? '',
          gender: c.gender,
          birthDate: c.birthDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )).toList();
      }
      rethrow;
    }
  }

  /// 활성화된 반려동물 조회 (캐시-우선)
  Future<Pet?> getActivePet({bool forceRefresh = false}) async {
    // 1순위: 인메모리 캐시
    if (!forceRefresh && _isActivePetCacheValid() && _cachedActivePet != null) {
      debugPrint('[PetService] getActivePet() → cache hit');
      return _cachedActivePet;
    }

    try {
      // 2순위: 서버 API
      final response = await _api.get('/pets/active');
      final pet = response != null ? Pet.fromJson(response) : null;
      _cachedActivePet = pet;
      _lastActivePetFetch = DateTime.now();
      debugPrint('[PetService] getActivePet() → server (${pet?.name})');

      // 로컬 캐시 동기화
      if (pet != null) {
        await _petCache.upsertPet(
          PetProfileCache(
            id: pet.id,
            name: pet.name,
            species: pet.breed,
            gender: pet.gender,
            birthDate: pet.birthDate,
          ),
          setActive: true,
        );
      }
      return pet;
    } catch (e) {
      // 3순위: 만료된 인메모리 캐시
      if (_cachedActivePet != null) {
        debugPrint('[PetService] getActivePet() → stale cache fallback');
        return _cachedActivePet;
      }
      // 4순위: 로컬 영속 캐시
      final cached = await _petCache.getActivePet();
      if (cached != null) {
        debugPrint('[PetService] getActivePet() → local cache fallback');
        return Pet(
          id: cached.id,
          userId: '',
          name: cached.name,
          species: cached.species ?? '',
          gender: cached.gender,
          birthDate: cached.birthDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      rethrow;
    }
  }

  /// 특정 반려동물 조회
  Future<Pet?> getPetById(String petId) async {
    // 인메모리 캐시에서 먼저 확인
    if (_cachedActivePet?.id == petId && _isActivePetCacheValid()) {
      debugPrint('[PetService] getPetById() → cache hit');
      return _cachedActivePet;
    }
    if (_cachedPets != null && _isPetsCacheValid()) {
      final found = _cachedPets!.where((p) => p.id == petId).firstOrNull;
      if (found != null) {
        debugPrint('[PetService] getPetById() → pets list cache hit');
        return found;
      }
    }

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
    String? growthStage,
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
      if (growthStage != null) 'growth_stage': growthStage,
      if (weight != null) 'weight': weight,
      if (adoptionDate != null)
        'adoption_date': adoptionDate.toIso8601String().split('T').first,
      if (profileImageUrl != null) 'profile_image_url': profileImageUrl,
    };

    final response = await _api.post('/pets/', body: body);
    final pet = Pet.fromJson(response);
    invalidateCache();
    return pet;
  }

  /// 반려동물 수정
  Future<Pet> updatePet({
    required String petId,
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? gender,
    String? growthStage,
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
    if (growthStage != null) updates['growth_stage'] = growthStage;
    if (weight != null) updates['weight'] = weight;
    if (adoptionDate != null) {
      updates['adoption_date'] = adoptionDate.toIso8601String().split('T').first;
    }
    if (profileImageUrl != null) updates['profile_image_url'] = profileImageUrl;

    final response = await _api.put('/pets/$petId', body: updates);
    final pet = Pet.fromJson(response);
    invalidateCache();
    return pet;
  }

  /// 반려동물 삭제
  Future<void> deletePet(String petId) async {
    await _api.delete('/pets/$petId');
    invalidateCache();
  }

  /// 활성 펫 변경
  Future<void> setActivePet(String petId) async {
    await _api.put('/pets/$petId/activate');
    invalidateCache();
  }
}
