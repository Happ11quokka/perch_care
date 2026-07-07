import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';
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
      when(() => repo.getMyPets())
          .thenAnswer((_) async => [_pet('p1'), _pet('p2', name: 'Second')]);
      when(() => repo.getLocalPets())
          .thenAnswer((_) async => [_pet('p1'), _pet('p2', name: 'Second')]);
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

    // 낙관적 업데이트(2026-07 성능 개선) 회귀 테스트:
    // 서버 왕복이 끝나기 전에 로컬 데이터 기반으로 상태가 즉시 전환되어야 한다.
    test('switchPet()은 서버 응답 전에 상태를 타겟 펫으로 즉시 전환한다(낙관적 업데이트)',
        () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.getMyPets())
          .thenAnswer((_) async => [_pet('p1'), _pet('p2', name: 'Second')]);

      final setActivePetGate = Completer<void>();
      when(() => repo.setActivePet('p2'))
          .thenAnswer((_) => setActivePetGate.future);
      when(() => repo.getActivePet(forceRefresh: true))
          .thenAnswer((_) async => _pet('p2', name: 'Second'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future); // 초기 로드 p1
      // 펫 목록 provider를 미리 로드 (프로필 화면 진입 상태 재현)
      await container.read(petListViewModelProvider.future);

      final switching = container
          .read(activePetViewModelProvider.notifier)
          .switchPet('p2');

      // 서버 PUT이 완료되기 전에 이미 상태가 p2
      expect(
        container.read(activePetViewModelProvider).valueOrNull?.id,
        'p2',
        reason: '낙관적 업데이트로 서버 응답 전에 상태가 전환되어야 함',
      );

      setActivePetGate.complete();
      await switching;

      expect(
        container.read(activePetViewModelProvider).valueOrNull?.id,
        'p2',
      );
    });

    test('switchPet() 재진입 가드 — 진행 중 재호출은 무시된다', () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.getMyPets())
          .thenAnswer((_) async => [_pet('p1'), _pet('p2'), _pet('p3')]);

      final setActivePetGate = Completer<void>();
      when(() => repo.setActivePet(any()))
          .thenAnswer((_) => setActivePetGate.future);
      when(() => repo.getActivePet(forceRefresh: true))
          .thenAnswer((_) async => _pet('p2'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future);
      await container.read(petListViewModelProvider.future);

      final notifier = container.read(activePetViewModelProvider.notifier);
      final first = notifier.switchPet('p2');
      final second = notifier.switchPet('p3'); // 진행 중 연타 → 무시

      setActivePetGate.complete();
      await first;
      await second;

      verify(() => repo.setActivePet('p2')).called(1);
      verifyNever(() => repo.setActivePet('p3'));
      expect(
        container.read(activePetViewModelProvider).valueOrNull?.id,
        'p2',
      );
    });

    test('switchPet() 동일 펫 재선택은 서버 호출 없이 무시된다', () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future);

      await container
          .read(activePetViewModelProvider.notifier)
          .switchPet('p1');

      verifyNever(() => repo.setActivePet(any()));
      verifyNever(() => repo.getActivePet(forceRefresh: true));
    });

    test('switchPet() 실패 시 AsyncError 상태로 전파되고 이전 펫으로 롤백된다', () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.getMyPets())
          .thenAnswer((_) async => [_pet('p1'), _pet('p2')]);
      when(() => repo.setActivePet('p2'))
          .thenThrow(Exception('network error'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future);
      await container.read(petListViewModelProvider.future);

      await container
          .read(activePetViewModelProvider.notifier)
          .switchPet('p2');

      final state = container.read(activePetViewModelProvider);
      expect(state.hasError, isTrue);
      expect(state.valueOrNull?.id, 'p1',
          reason: '실패 시 낙관적 상태가 이전 펫으로 롤백되어야 함');
    });

    test('switchPet() 확정 재조회가 다른 펫을 반환하면(스테일 캐시 폴백) 낙관적 상태를 유지한다',
        () async {
      when(() => repo.getActivePet(forceRefresh: false))
          .thenAnswer((_) async => _pet('p1'));
      when(() => repo.getMyPets())
          .thenAnswer((_) async => [_pet('p1'), _pet('p2')]);
      when(() => repo.setActivePet('p2')).thenAnswer((_) async {});
      // PUT은 성공했지만 확정 GET이 오프라인 폴백으로 이전 펫을 반환하는 상황
      when(() => repo.getActivePet(forceRefresh: true))
          .thenAnswer((_) async => _pet('p1'));

      final container = _container(repo);
      await container.read(activePetViewModelProvider.future);
      await container.read(petListViewModelProvider.future);

      await container
          .read(activePetViewModelProvider.notifier)
          .switchPet('p2');

      expect(
        container.read(activePetViewModelProvider).valueOrNull?.id,
        'p2',
        reason: '서버 PUT이 성공했으므로 낙관적 상태가 유지되어야 함',
      );
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
      // deletePet 폴백 1회 + switchPet 낙관적 업데이트의 로컬 캐시 조회 1회
      verify(() => repo.getLocalPets()).called(2);
      verify(() => repo.setActivePet('p3')).called(1);

      final pet = container.read(activePetViewModelProvider).valueOrNull;
      expect(pet?.id, 'p3');
    });
  });
}
