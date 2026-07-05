import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/view_models/pet/pet_add_view_model.dart';

class MockPetRepository extends Mock implements PetRepository {}

Pet _pet(
  String id, {
  String name = 'Test',
  String species = 'bird',
  String? breedId,
  String? breed,
}) =>
    Pet(
      id: id,
      userId: 'user-1',
      name: name,
      species: species,
      breedId: breedId,
      breed: breed,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Mock Repository를 주입한 ProviderContainer를 반환 (테스트 종료 시 자동 dispose).
ProviderContainer _container(PetRepository repo) {
  final container = ProviderContainer(overrides: [
    petRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  late MockPetRepository repo;

  setUpAll(() {
    registerFallbackValue(_pet('fallback'));
  });

  setUp(() {
    repo = MockPetRepository();
  });

  group('PetAddViewModel.save (수정 경로 — species-default 매핑)', () {
    // breedId 미지정 + species 공백일 때 effectiveSpecies가 리터럴 'default'로
    // 결정되는 분기 (pet_add_view_model.dart L106~110) 회귀 테스트.
    test('breedId 없고 species가 빈 문자열이면 updatePet에 species="default"가 전달된다',
        () async {
      final existingPet = _pet('p1', species: 'parakeet');
      final updatedPet = _pet('p1', species: 'default');

      when(() => repo.updatePet(
            petId: any(named: 'petId'),
            name: any(named: 'name'),
            species: any(named: 'species'),
            breed: any(named: 'breed'),
            breedId: any(named: 'breedId'),
            updateBreedFields: any(named: 'updateBreedFields'),
            birthDate: any(named: 'birthDate'),
            gender: any(named: 'gender'),
            growthStage: any(named: 'growthStage'),
            weight: any(named: 'weight'),
            adoptionDate: any(named: 'adoptionDate'),
          )).thenAnswer((_) async => updatedPet);
      when(() => repo.upsertLocalCache(any(),
          setActive: any(named: 'setActive'))).thenAnswer((_) async {});

      final container = _container(repo);
      const input = PetFormInput(name: 'Kiwi', species: '', breedId: null);

      final result = await container
          .read(petAddViewModelProvider.notifier)
          .save(input: input, existingPet: existingPet);

      expect(result.species, 'default');

      final captured = verify(() => repo.updatePet(
            petId: existingPet.id,
            name: 'Kiwi',
            species: captureAny(named: 'species'),
            breed: any(named: 'breed'),
            breedId: null,
            updateBreedFields: true,
            birthDate: any(named: 'birthDate'),
            gender: any(named: 'gender'),
            growthStage: any(named: 'growthStage'),
            weight: any(named: 'weight'),
            adoptionDate: any(named: 'adoptionDate'),
          )).captured;
      expect(captured.single, 'default');
    });

    // breedId가 있으면 input.species(자유 텍스트)는 무시되고 breed 파생 값('bird' +
    // breedDisplayName)이 사용되는 분기 (pet_add_view_model.dart L106~113) 회귀 테스트.
    test('breedId가 있으면 input.species는 무시되고 breed 파생 값이 사용된다', () async {
      final existingPet = _pet('p1', species: 'parakeet');
      final updatedPet =
          _pet('p1', species: 'bird', breedId: 'breed-1', breed: '왕관앵무');

      when(() => repo.updatePet(
            petId: any(named: 'petId'),
            name: any(named: 'name'),
            species: any(named: 'species'),
            breed: any(named: 'breed'),
            breedId: any(named: 'breedId'),
            updateBreedFields: any(named: 'updateBreedFields'),
            birthDate: any(named: 'birthDate'),
            gender: any(named: 'gender'),
            growthStage: any(named: 'growthStage'),
            weight: any(named: 'weight'),
            adoptionDate: any(named: 'adoptionDate'),
          )).thenAnswer((_) async => updatedPet);
      when(() => repo.upsertLocalCache(any(),
          setActive: any(named: 'setActive'))).thenAnswer((_) async {});

      final container = _container(repo);
      const input = PetFormInput(
        name: 'Kiwi',
        species: 'ignored-free-text', // breedId가 있으므로 무시되어야 함
        breedId: 'breed-1',
        breedDisplayName: '왕관앵무',
      );

      await container
          .read(petAddViewModelProvider.notifier)
          .save(input: input, existingPet: existingPet);

      verify(() => repo.updatePet(
            petId: existingPet.id,
            name: 'Kiwi',
            species: 'bird',
            breed: '왕관앵무',
            breedId: 'breed-1',
            updateBreedFields: true,
            birthDate: any(named: 'birthDate'),
            gender: any(named: 'gender'),
            growthStage: any(named: 'growthStage'),
            weight: any(named: 'weight'),
            adoptionDate: any(named: 'adoptionDate'),
          )).called(1);
    });
  });
}
