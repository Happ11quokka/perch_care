import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

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

  group('ActivePetViewModel', () {
    test('build()는 Repository.getActivePet()을 호출하고 결과를 노출한다', () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));

      final container = _container(repo);
      final pet = await container.read(activePetViewModelProvider.future);

      expect(pet?.id, 'p1');
      verify(() => repo.getActivePet(forceRefresh: false)).called(1);
    });

    // 기록 탭 펫 전환 버그(2026-07) 회귀 테스트:
    // 선택기 탭 경로는 반드시 이 switchPet을 경유해야 하며,
    // 영속화(setActivePet) → forceRefresh 재조회 → provider 상태 갱신 순서를 보장한다.
    test('switchPet()은 setActivePet 영속화 후 forceRefresh 재조회로 상태를 갱신한다',
        () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.setActivePet('p2')).thenAnswer((_) async {});
      when(() => repo.getActivePet(forceRefresh: true))
          .thenAnswer((_) async => _pet('p2', name: 'Second'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future); // 초기 로드 p1

      await container
          .read(activePetViewModelProvider.notifier)
          .switchPet('p2');

      final pet = container.read(activePetViewModelProvider).valueOrNull;
      expect(pet?.id, 'p2');
      verifyInOrder([
        () => repo.setActivePet('p2'),
        () => repo.getActivePet(forceRefresh: true),
      ]);
    });

    test('switchPet() 실패 시 AsyncError 상태로 전파된다', () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.setActivePet('p2'))
          .thenThrow(Exception('network error'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future);

      await container
          .read(activePetViewModelProvider.notifier)
          .switchPet('p2');

      final state = container.read(activePetViewModelProvider);
      expect(state.hasError, isTrue);
    });

    test('deletePet: 서버+캐시 삭제 후 남은 펫으로 전환', () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.deletePet(any())).thenAnswer((_) async {});
      when(() => repo.removeLocalCache(any())).thenAnswer((_) async {});
      when(() => repo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => [_pet('p2')]);
      when(() => repo.setActivePet(any())).thenAnswer((_) async {});
      when(() => repo.getActivePet(forceRefresh: true))
          .thenAnswer((_) async => _pet('p2'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future); // 초기 로드 p1

      await container
          .read(activePetViewModelProvider.notifier)
          .deletePet('p1');

      verify(() => repo.deletePet('p1')).called(1);
      verify(() => repo.removeLocalCache('p1')).called(1);
      verify(() => repo.setActivePet('p2')).called(1);

      final pet = container.read(activePetViewModelProvider).valueOrNull;
      expect(pet?.id, 'p2');
    });

    test('deletePet: 남은 펫이 없으면 clear()로 상태를 비운다', () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.deletePet(any())).thenAnswer((_) async {});
      when(() => repo.removeLocalCache(any())).thenAnswer((_) async {});
      when(() => repo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => <Pet>[]);

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future); // 초기 로드 p1

      await container
          .read(activePetViewModelProvider.notifier)
          .deletePet('p1');

      verify(() => repo.deletePet('p1')).called(1);
      verify(() => repo.removeLocalCache('p1')).called(1);
      verifyNever(() => repo.setActivePet(any()));

      final pet = container.read(activePetViewModelProvider).valueOrNull;
      expect(pet, isNull);
    });

    test('deletePet: getMyPets 실패 시 getLocalPets()로 폴백하여 남은 펫으로 전환',
        () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.deletePet(any())).thenAnswer((_) async {});
      when(() => repo.removeLocalCache(any())).thenAnswer((_) async {});
      when(() => repo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
          .thenThrow(Exception('network error'));
      when(() => repo.getLocalPets()).thenAnswer((_) async => [_pet('p3')]);
      when(() => repo.setActivePet(any())).thenAnswer((_) async {});
      when(() => repo.getActivePet(forceRefresh: true))
          .thenAnswer((_) async => _pet('p3'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future); // 초기 로드 p1

      await container
          .read(activePetViewModelProvider.notifier)
          .deletePet('p1');

      verify(() => repo.deletePet('p1')).called(1);
      verify(() => repo.removeLocalCache('p1')).called(1);
      verify(() => repo.getMyPets(forceRefresh: true)).called(1);
      verify(() => repo.getLocalPets()).called(1);
      verify(() => repo.setActivePet('p3')).called(1);

      final pet = container.read(activePetViewModelProvider).valueOrNull;
      expect(pet?.id, 'p3');
    });
  });
}
