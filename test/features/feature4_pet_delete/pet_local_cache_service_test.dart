import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:perch_care/src/services/pet/pet_local_cache_service.dart';

void main() {
  group('Feature 4: PetLocalCacheService.removePet() 테스트', () {
    // 테스트용 펫 데이터
    final petA = PetProfileCache(
      id: 'pet-aaa',
      name: '앵무A',
      species: 'budgerigar',
    );
    final petB = PetProfileCache(
      id: 'pet-bbb',
      name: '앵무B',
      species: 'cockatiel',
    );
    final petC = PetProfileCache(
      id: 'pet-ccc',
      name: '앵무C',
      species: 'lovebird',
    );

    /// SharedPreferences를 테스트 데이터로 초기화
    void setUpPrefs({
      required List<PetProfileCache> pets,
      String? activePetId,
    }) {
      final map = <String, Object>{
        'local_pet_profiles': jsonEncode(
          pets.map((p) => p.toJson()).toList(),
        ),
      };
      if (activePetId != null) {
        map['local_active_pet_id'] = activePetId;
      }
      SharedPreferences.setMockInitialValues(map);
    }

    test('4.1 펫 삭제 시 리스트에서 제거', () async {
      setUpPrefs(pets: [petA, petB, petC], activePetId: petA.id);

      final service = PetLocalCacheService.instance;
      await service.removePet(petB.id);

      final remaining = await service.getPets();
      expect(remaining.length, 2);
      expect(remaining.map((p) => p.id), containsAll([petA.id, petC.id]));
      expect(remaining.map((p) => p.id), isNot(contains(petB.id)));
    });

    test('4.2 활성 펫 삭제 시 첫 번째 펫으로 재할당', () async {
      setUpPrefs(pets: [petA, petB, petC], activePetId: petB.id);

      final service = PetLocalCacheService.instance;
      await service.removePet(petB.id);

      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getString('local_active_pet_id');
      expect(activeId, petA.id); // 첫 번째 펫으로 재할당
    });

    test('4.3 마지막 펫 삭제 시 activePetId 키 제거', () async {
      setUpPrefs(pets: [petA], activePetId: petA.id);

      final service = PetLocalCacheService.instance;
      await service.removePet(petA.id);

      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getString('local_active_pet_id');
      expect(activeId, isNull);

      final remaining = await service.getPets();
      expect(remaining, isEmpty);
    });

    test('4.4 비활성 펫 삭제 시 활성 펫 변경 없음', () async {
      setUpPrefs(pets: [petA, petB, petC], activePetId: petA.id);

      final service = PetLocalCacheService.instance;
      await service.removePet(petC.id);

      final prefs = await SharedPreferences.getInstance();
      final activeId = prefs.getString('local_active_pet_id');
      expect(activeId, petA.id); // 변경 없음

      final remaining = await service.getPets();
      expect(remaining.length, 2);
    });

    test('4.5 존재하지 않는 petId 삭제 시 변경 없음', () async {
      setUpPrefs(pets: [petA, petB], activePetId: petA.id);

      final service = PetLocalCacheService.instance;
      await service.removePet('non-existent-id');

      final remaining = await service.getPets();
      expect(remaining.length, 2);
    });

    test('4.6 모든 펫 삭제 후 빈 리스트 반환', () async {
      setUpPrefs(pets: [petA, petB], activePetId: petA.id);

      final service = PetLocalCacheService.instance;
      await service.removePet(petA.id);
      await service.removePet(petB.id);

      final remaining = await service.getPets();
      expect(remaining, isEmpty);
    });
  });

  group('PetProfileCache 모델 테스트', () {
    test('toJson → fromJson 왕복 변환', () {
      final pet = PetProfileCache(
        id: 'test-id',
        name: '앵무새',
        species: 'budgerigar',
        gender: 'male',
        birthDate: DateTime(2024, 6, 15),
      );

      final json = pet.toJson();
      final restored = PetProfileCache.fromJson(json);

      expect(restored.id, pet.id);
      expect(restored.name, pet.name);
      expect(restored.species, pet.species);
      expect(restored.gender, pet.gender);
      expect(restored.birthDate, DateTime(2024, 6, 15));
    });

    test('선택 필드 null일 때 정상 처리', () {
      final pet = PetProfileCache(
        id: 'test-id',
        name: '이름만',
      );

      final json = pet.toJson();
      expect(json.containsKey('species'), isFalse);
      expect(json.containsKey('gender'), isFalse);
      expect(json.containsKey('birthDate'), isFalse);

      final restored = PetProfileCache.fromJson(json);
      expect(restored.species, isNull);
      expect(restored.gender, isNull);
      expect(restored.birthDate, isNull);
    });
  });
}
