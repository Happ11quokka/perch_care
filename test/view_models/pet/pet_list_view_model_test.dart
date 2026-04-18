import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/view_models/pet/pet_list_view_model.dart';

class MockPetRepository extends Mock implements PetRepository {}

Pet _pet(String id, {String name = 'Test'}) => Pet(
      id: id,
      userId: 'user-1',
      name: name,
      species: 'bird',
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

  setUp(() {
    repo = MockPetRepository();
  });

  group('PetListViewModel', () {
    test('build()는 Repository.getMyPets()를 호출하고 결과를 노출한다', () async {
      when(() => repo.getMyPets(forceRefresh: false))
          .thenAnswer((_) async => [_pet('p1'), _pet('p2')]);

      final container = _container(repo);
      final pets = await container.read(petListViewModelProvider.future);

      expect(pets, hasLength(2));
      expect(pets.map((p) => p.id), ['p1', 'p2']);
      verify(() => repo.getMyPets(forceRefresh: false)).called(1);
    });

    test('refresh()는 forceRefresh=true로 Repository를 재호출한다', () async {
      when(() => repo.getMyPets(forceRefresh: false))
          .thenAnswer((_) async => [_pet('p1')]);
      when(() => repo.getMyPets(forceRefresh: true))
          .thenAnswer((_) async => [_pet('p2'), _pet('p3')]);

      final container = _container(repo);

      // 초기 로드
      await container.read(petListViewModelProvider.future);
      // refresh
      await container.read(petListViewModelProvider.notifier).refresh();
      // refresh 이후의 값
      final pets = await container.read(petListViewModelProvider.future);

      expect(pets.map((p) => p.id), ['p2', 'p3']);
      verify(() => repo.getMyPets(forceRefresh: true)).called(1);
    });

    test('Repository에서 예외가 나면 AsyncError 상태로 전파된다', () async {
      when(() => repo.getMyPets(forceRefresh: false))
          .thenThrow(Exception('network error'));

      final container = _container(repo);

      await expectLater(
        container.read(petListViewModelProvider.future),
        throwsA(isA<Exception>()),
      );
      final state = container.read(petListViewModelProvider);
      expect(state.hasError, isTrue);
    });

  });
}
