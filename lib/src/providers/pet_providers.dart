import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pet.dart';
import '../services/pet/pet_service.dart';
import '../services/pet/active_pet_notifier.dart' as legacy;

/// 활성 펫 SSOT — 모든 스크린이 이 provider를 watch하여 펫 데이터를 공유
final activePetProvider = AsyncNotifierProvider<ActivePetNotifier, Pet?>(
  ActivePetNotifier.new,
);

class ActivePetNotifier extends AsyncNotifier<Pet?> {
  @override
  Future<Pet?> build() async {
    return await PetService.instance.getActivePet();
  }

  /// 펫 전환 (PetProfileScreen 등에서 호출)
  Future<void> switchPet(String petId) async {
    state = const AsyncLoading<Pet?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      await PetService.instance.setActivePet(petId);
      PetService.instance.invalidateCache();
      final pet = await PetService.instance.getActivePet(forceRefresh: true);
      // 레거시 브릿지: 미전환 스크린용 (Phase 7에서 제거)
      if (pet != null) legacy.ActivePetNotifier.instance.notify(pet.id);
      return pet;
    });
  }

  /// 강제 새로고침 (펫 정보 수정 후 등)
  Future<void> refresh() async {
    state = const AsyncLoading<Pet?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return await PetService.instance.getActivePet(forceRefresh: true);
    });
  }

  /// 로그아웃 시 상태 초기화
  void clear() {
    PetService.instance.invalidateCache();
    state = const AsyncData(null);
  }
}

/// 펫 목록 provider
final petListProvider = AsyncNotifierProvider<PetListNotifier, List<Pet>>(
  PetListNotifier.new,
);

class PetListNotifier extends AsyncNotifier<List<Pet>> {
  @override
  Future<List<Pet>> build() async {
    return await PetService.instance.getMyPets();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<Pet>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return await PetService.instance.getMyPets(forceRefresh: true);
    });
  }
}
