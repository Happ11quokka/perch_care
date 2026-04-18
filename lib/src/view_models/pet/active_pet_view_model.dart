import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/pet_repository.dart';
import '../base/async_view_model.dart';

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

  /// 로그아웃 시 상태 초기화 — caller(`auth_actions.performLogout`)가
  /// provider를 invalidate하므로 여기서는 상태만 초기화.
  void clear() {
    state = const AsyncData(null);
  }
}

final activePetViewModelProvider =
    AsyncNotifierProvider<ActivePetViewModel, Pet?>(ActivePetViewModel.new);
