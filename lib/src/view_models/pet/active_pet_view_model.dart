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

  @override
  Future<Pet?> build() => _repo.getActivePet();

  /// 강제 새로고침 — 펫 정보 수정 직후 사용.
  Future<void> refresh() =>
      runLoad(() => _repo.getActivePet(forceRefresh: true));

  /// 활성 펫 전환 — setActivePet 내부에서 service 캐시가 invalidate되므로
  /// forceRefresh로 재조회만 하면 된다.
  Future<void> switchPet(String petId) {
    return runLoad(() async {
      await _repo.setActivePet(petId);
      return _repo.getActivePet(forceRefresh: true);
    });
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
