import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/home_repository.dart';
import 'home_state.dart';
import '../pet/active_pet_view_model.dart';

/// 홈 화면 ViewModel.
///
/// - `activePetViewModelProvider`를 `ref.watch`하여 활성 펫이 바뀌면 자동 재로드.
/// - 기간 선택기 변경 시 `loadBhiForDate(targetDate)`만 재호출.
/// - 저장 화면에서 돌아왔을 때 `refreshBhi()` 호출로 BHI/로컬 배지만 갱신.
class HomeViewModel extends AsyncNotifier<HomeState> {
  HomeRepository get _repo => ref.read(homeRepositoryProvider);

  /// 기간 전환이 빠르게 연타됐을 때 오래된 응답이 최신 응답을 덮어쓰지 않도록 하는 요청 ID.
  int _bhiRequestId = 0;

  @override
  Future<HomeState> build() async {
    final petAsync = ref.watch(activePetViewModelProvider);
    final pet = petAsync.valueOrNull;
    if (pet == null) {
      return const HomeState();
    }
    return _buildInitialState(pet, DateTime.now());
  }

  /// 활성 펫 기반 초기 상태 (Pet+BHI, 파생 데이터, 로컬 배지까지 한 번에 채움).
  Future<HomeState> _buildInitialState(Pet pet, DateTime targetDate) async {
    final base = HomeState(activePet: pet);

    final pair = await _repo.loadPetWithBhi(pet.id, targetDate);
    final resolvedPet = pair.pet ?? pet;
    final bhi = pair.bhi;

    HomeState next = base.copyWith(
      activePet: resolvedPet,
      bhi: bhi,
      wciLevel: bhi?.wciLevel ?? 0,
      hasWeight: bhi?.hasWeightData ?? false,
      hasFood: bhi?.hasFoodData ?? false,
      hasWater: bhi?.hasWaterData ?? false,
      isBhiOffline: bhi == null,
      lastBhiFetchTime: _repo.lastBhiFetchTime,
    );

    // BHI 실패 시 로컬 데이터 존재 여부로 배지 복원
    if (bhi == null) {
      final local =
          await _repo.checkLocalDataAvailability(pet.id, DateTime.now());
      next = next.copyWith(
        hasWeight: next.hasWeight || local.hasWeight,
        hasFood: next.hasFood || local.hasFood,
        hasWater: next.hasWater || local.hasWater,
      );
    }

    // 건강 요약/인사이트 로드는 실패해도 메인 상태에는 영향 없게 별도 try
    try {
      final derived = await _repo.loadHealthDerivedData(pet.id);
      next = next.copyWith(
        healthSummary: derived.healthSummary,
        insight: derived.insight,
        isPremium: derived.isPremium,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeViewModel] derived data failed: $e');
    }

    return next;
  }

  /// 기간 선택기 변경 시 — BHI만 재로드. 전체 리빌드 방지 위해 isBhiLoading만 토글.
  Future<void> loadBhiForDate(DateTime targetDate) async {
    final current = state.valueOrNull;
    final pet = current?.activePet;
    if (pet == null) return;

    final requestId = ++_bhiRequestId;
    state = AsyncData(current!.copyWith(isBhiLoading: true));

    try {
      final bhi = await _repo.loadBhiForDate(pet.id, targetDate);
      if (requestId != _bhiRequestId) return; // 최신 요청이 아니면 무시

      final latest = state.valueOrNull ?? current;
      state = AsyncData(latest.copyWith(
        bhi: bhi,
        wciLevel: bhi.wciLevel,
        hasWeight: bhi.hasWeightData,
        hasFood: bhi.hasFoodData,
        hasWater: bhi.hasWaterData,
        isBhiLoading: false,
        isBhiOffline: false,
        lastBhiFetchTime: _repo.lastBhiFetchTime,
      ));
    } catch (e) {
      if (requestId != _bhiRequestId) return;
      final latest = state.valueOrNull ?? current;
      final local =
          await _repo.checkLocalDataAvailability(pet.id, DateTime.now());
      state = AsyncData(latest.copyWith(
        isBhiLoading: false,
        isBhiOffline: true,
        hasWeight: latest.hasWeight || local.hasWeight,
        hasFood: latest.hasFood || local.hasFood,
        hasWater: latest.hasWater || local.hasWater,
      ));
      if (kDebugMode) debugPrint('[HomeViewModel] BHI reload failed: $e');
    }
  }

  /// 기록 화면에서 돌아온 후 오늘자 BHI만 갱신 (저장 직후 UI 반영).
  Future<void> refreshBhi() async {
    final current = state.valueOrNull;
    final pet = current?.activePet;
    if (pet == null) return;
    try {
      final bhi = await _repo.loadBhiForDate(pet.id, DateTime.now());
      final latest = state.valueOrNull ?? current!;
      state = AsyncData(latest.copyWith(
        bhi: bhi,
        wciLevel: bhi.wciLevel,
        hasWeight: bhi.hasWeightData,
        hasFood: bhi.hasFoodData,
        hasWater: bhi.hasWaterData,
        isBhiOffline: false,
        lastBhiFetchTime: _repo.lastBhiFetchTime,
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeViewModel] refreshBhi failed: $e');
    }
  }

  /// 오프라인 큐 처리 (fire-and-forget).
  Future<void> processOfflineQueue() async {
    try {
      await _repo.processOfflineQueue();
      final pet = state.valueOrNull?.activePet;
      if (pet != null) {
        await _repo.syncLocalRecordsIfNeeded(pet.id);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[HomeViewModel] offline sync failed: $e');
    }
  }
}

final homeViewModelProvider =
    AsyncNotifierProvider<HomeViewModel, HomeState>(HomeViewModel.new);
