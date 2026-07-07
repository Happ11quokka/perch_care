import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/pet_repository.dart';
import '../base/async_view_model.dart';
import 'pet_list_view_model.dart';

/// 활성 펫(Active Pet) ViewModel — 앱 전역 SSOT.
///
/// - View: 홈/프로필/기록 등 거의 모든 화면이 `ref.watch(activePetViewModelProvider)`로 구독
/// - BHI/쿼터 등 파생 상태는 이 provider를 watch 하여 자동 재계산
class ActivePetViewModel extends AsyncViewModel<Pet?> {
  PetRepository get _repo => ref.read(petRepositoryProvider);

  /// switchPet 재진입 가드 — 연타 시 PUT/GET 체인이 중첩되어
  /// 응답 순서 역전으로 잘못된 펫이 확정되는 것을 방지.
  bool _switching = false;

  @override
  Future<Pet?> build() => _repo.getActivePet();

  /// 강제 새로고침 — 펫 정보 수정 직후 사용.
  Future<void> refresh() =>
      runLoad(() => _repo.getActivePet(forceRefresh: true));

  /// 활성 펫 전환 — 낙관적 업데이트.
  ///
  /// 로컬(펫 목록 provider → 영속 캐시)에서 타겟 펫을 찾으면 서버 응답을
  /// 기다리지 않고 즉시 상태를 전환해 하이라이트/파생 화면이 탭 즉시 반응한다.
  /// 이후 setActivePet 영속화 → forceRefresh 재조회로 서버 상태를 확정하고,
  /// 실패 시 이전 펫으로 롤백(AsyncError + 이전 값 유지)한다.
  Future<void> switchPet(String petId) async {
    if (_switching || state.valueOrNull?.id == petId) return;
    _switching = true;
    final previous = state;
    try {
      final optimistic = _findPetLocally(petId) ?? await _findPetInCache(petId);
      if (optimistic != null) {
        state = AsyncData(optimistic);
      } else {
        state = AsyncValue<Pet?>.loading().copyWithPrevious(state);
      }

      await _repo.setActivePet(petId);
      final confirmed = await _repo.getActivePet(forceRefresh: true);
      if (confirmed?.id == petId) {
        state = AsyncData(confirmed);
      } else if (optimistic != null) {
        // 확정 GET이 실패 폴백(stale 캐시)으로 다른 펫을 반환한 경우 —
        // 서버 PUT은 성공했으므로 낙관적 상태를 유지한다.
        state = AsyncData(optimistic);
      } else {
        state = AsyncData(confirmed);
      }
    } catch (e, st) {
      // 에러 노출(hasError) + 이전 펫 유지 → 하이라이트 롤백.
      // AsyncNotifier의 state setter는 대입값을 '현재 state'와 병합하므로,
      // 낙관적 값(신 펫)이 남지 않도록 먼저 이전 상태로 복원한 뒤 에러를 얹는다.
      state = previous;
      state = AsyncError<Pet?>(e, st).copyWithPrevious(previous);
    } finally {
      _switching = false;
    }
  }

  /// 펫 목록 provider가 이미 들고 있는 전체 Pet 객체에서 동기 조회.
  Pet? _findPetLocally(String petId) {
    final pets = ref.read(petListViewModelProvider).valueOrNull;
    if (pets == null) return null;
    for (final pet in pets) {
      if (pet.id == petId) return pet;
    }
    return null;
  }

  /// 로컬 영속 캐시 폴백 — 목록 provider가 아직 로드 전인 화면(체중 탭 등)용.
  Future<Pet?> _findPetInCache(String petId) async {
    try {
      final pets = await _repo.getLocalPets();
      for (final pet in pets) {
        if (pet.id == petId) return pet;
      }
    } catch (_) {/* 캐시 조회 실패는 낙관적 단계만 스킵 */}
    return null;
  }

  /// 로그아웃 시 상태 초기화 — caller(`AuthViewModel.logout`)가
  /// provider를 invalidate하므로 여기서는 상태만 초기화.
  void clear() {
    state = const AsyncData(null);
  }

  /// 펫 삭제 — 서버+로컬 캐시 제거 후, 남은 펫이 있으면 첫 펫으로 전환, 없으면 clear.
  Future<void> deletePet(String petId) async {
    final repo = ref.read(petRepositoryProvider);
    await repo.deletePet(petId);
    await repo.removeLocalCache(petId);
    // 서버 기준 남은 펫 (실패 시 로컬 캐시 폴백)
    List<Pet> remaining;
    try {
      remaining = await repo.getMyPets(forceRefresh: true);
    } catch (_) {
      remaining = await repo.getLocalPets();
    }
    ref.invalidate(petListViewModelProvider);
    if (remaining.isNotEmpty) {
      await switchPet(remaining.first.id);
    } else {
      clear();
    }
  }
}

final activePetViewModelProvider =
    AsyncNotifierProvider<ActivePetViewModel, Pet?>(ActivePetViewModel.new);

/// 활성 펫의 '화면 표시 내용' select 키.
///
/// 파생 ViewModel(home/weight_detail 등)이
/// `ref.watch(activePetViewModelProvider.select(activePetContentKey))`로 구독하면:
/// - runLoad의 AsyncLoading 재발행(내용 불변)에는 재빌드하지 않음
///   → 펫 전환 1회당 구 펫 대상 낭비 리로드 제거
/// - 펫 전환(id 변경)·프로필 수정(name 등 변경) 시에만 정확히 1회 재로드
///
/// Pet의 `==`는 id 기반이라 Pet 객체 자체를 select 키로 쓰면 프로필 수정이
/// 전파되지 않는다 — 표시에 영향을 주는 필드를 record로 펼쳐 비교한다.
({
  String id,
  String name,
  String? breed,
  DateTime? birthDate,
  String? gender,
  double? weight,
  String? profileImageUrl,
  DateTime updatedAt,
})? activePetContentKey(AsyncValue<Pet?> async) {
  final pet = async.valueOrNull;
  if (pet == null) return null;
  return (
    id: pet.id,
    name: pet.name,
    breed: pet.breed,
    birthDate: pet.birthDate,
    gender: pet.gender,
    weight: pet.weight,
    profileImageUrl: pet.profileImageUrl,
    updatedAt: pet.updatedAt,
  );
}
