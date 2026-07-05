import '../models/pet.dart';
import '../services/pet/pet_service.dart';
import '../services/pet/pet_local_cache_service.dart';

/// Pet 도메인 Repository — ViewModel이 의존하는 단일 데이터 접근 지점.
///
/// ViewModel은 이 인터페이스만 바라보고 `PetService` / `PetLocalCacheService` 구현을
/// 직접 알지 못한다. 테스트에서는 Mock Repository를 주입하여 ViewModel만
/// 단위 테스트할 수 있다.
abstract class PetRepository {
  Future<List<Pet>> getMyPets({bool forceRefresh = false});
  Future<Pet?> getActivePet({bool forceRefresh = false});
  Future<Pet?> getPetById(String petId);

  Future<Pet> createPet({
    required String name,
    required String species,
    String? breed,
    String? breedId,
    DateTime? birthDate,
    String? gender,
    String? growthStage,
    double? weight,
    DateTime? adoptionDate,
    String? profileImageUrl,
  });

  Future<Pet> updatePet({
    required String petId,
    String? name,
    String? species,
    String? breed,
    String? breedId,
    bool updateBreedFields = false,
    DateTime? birthDate,
    String? gender,
    String? growthStage,
    double? weight,
    DateTime? adoptionDate,
    String? profileImageUrl,
  });

  Future<void> deletePet(String petId);
  Future<void> setActivePet(String petId);

  /// 로컬 캐시(영속)에 upsert — 활성 펫 지정 포함.
  Future<void> upsertLocalCache(Pet pet, {bool setActive = true});

  /// 로컬 캐시에서 펫 제거.
  Future<void> removeLocalCache(String petId);

  /// 로컬 캐시 펫 목록(삭제 후 남은 펫 판단 등에 사용).
  Future<List<Pet>> getLocalPets();

  /// 로컬 캐시의 활성 펫 — 네트워크를 타지 않는 오프라인 폴백 전용.
  Future<Pet?> getActivePetFromLocalCache();
}

/// 기본 구현 — 기존 `PetService` + `PetLocalCacheService`를 래핑한다.
class PetRepositoryImpl implements PetRepository {
  PetRepositoryImpl({
    PetService? service,
    PetLocalCacheService? cache,
  })  : _service = service ?? PetService.instance,
        _cache = cache ?? PetLocalCacheService.instance;

  final PetService _service;
  final PetLocalCacheService _cache;

  @override
  Future<List<Pet>> getMyPets({bool forceRefresh = false}) =>
      _service.getMyPets(forceRefresh: forceRefresh);

  @override
  Future<Pet?> getActivePet({bool forceRefresh = false}) =>
      _service.getActivePet(forceRefresh: forceRefresh);

  @override
  Future<Pet?> getPetById(String petId) => _service.getPetById(petId);

  @override
  Future<Pet> createPet({
    required String name,
    required String species,
    String? breed,
    String? breedId,
    DateTime? birthDate,
    String? gender,
    String? growthStage,
    double? weight,
    DateTime? adoptionDate,
    String? profileImageUrl,
  }) {
    return _service.createPet(
      name: name,
      species: species,
      breed: breed,
      breedId: breedId,
      birthDate: birthDate,
      gender: gender,
      growthStage: growthStage,
      weight: weight,
      adoptionDate: adoptionDate,
      profileImageUrl: profileImageUrl,
    );
  }

  @override
  Future<Pet> updatePet({
    required String petId,
    String? name,
    String? species,
    String? breed,
    String? breedId,
    bool updateBreedFields = false,
    DateTime? birthDate,
    String? gender,
    String? growthStage,
    double? weight,
    DateTime? adoptionDate,
    String? profileImageUrl,
  }) {
    return _service.updatePet(
      petId: petId,
      name: name,
      species: species,
      breed: breed,
      breedId: breedId,
      updateBreedFields: updateBreedFields,
      birthDate: birthDate,
      gender: gender,
      growthStage: growthStage,
      weight: weight,
      adoptionDate: adoptionDate,
      profileImageUrl: profileImageUrl,
    );
  }

  @override
  Future<void> deletePet(String petId) => _service.deletePet(petId);

  @override
  Future<void> setActivePet(String petId) => _service.setActivePet(petId);

  @override
  Future<void> upsertLocalCache(Pet pet, {bool setActive = true}) {
    return _cache.upsertPet(
      PetProfileCache(
        id: pet.id,
        name: pet.name,
        species: pet.breed ?? pet.species,
        gender: pet.gender,
        birthDate: pet.birthDate,
      ),
      setActive: setActive,
    );
  }

  @override
  Future<void> removeLocalCache(String petId) => _cache.removePet(petId);

  @override
  Future<List<Pet>> getLocalPets() async {
    final cached = await _cache.getPets();
    return cached.map(_petFromCache).toList();
  }

  @override
  Future<Pet?> getActivePetFromLocalCache() async {
    final cached = await _cache.getActivePet();
    if (cached == null) return null;
    return _petFromCache(cached);
  }

  /// `PetProfileCache` → `Pet` 최소 매핑.
  ///
  /// 로컬 캐시에는 id/name/species/gender/birthDate만 저장되므로 나머지 필드는
  /// 더미 값(userId='', createdAt/updatedAt=now)으로 채운다. 남은 펫 판단이나
  /// 오프라인 폴백 표시용으로만 쓰이고 서버에 재전송되지 않는다.
  Pet _petFromCache(PetProfileCache c) {
    final now = DateTime.now();
    return Pet(
      id: c.id,
      userId: '',
      name: c.name,
      species: c.species ?? '',
      gender: c.gender,
      birthDate: c.birthDate,
      createdAt: now,
      updatedAt: now,
    );
  }
}
