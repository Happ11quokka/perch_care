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
    // 펫 '표시 내용' 키만 select — switchPet의 AsyncLoading 재발행(내용 불변)에는
    // 재빌드하지 않아, 펫 전환 1회당 구 펫 대상 낭비 리로드(BHI+요약+인사이트)를 막는다.
    // 펫 전환(id)·프로필 수정(name 등) 시에만 정확히 1회 재로드된다.
    final petKey =
        ref.watch(activePetViewModelProvider.select(activePetContentKey));
    if (petKey == null) {
      return const HomeState();
    }
    final pet = ref.read(activePetViewModelProvider).valueOrNull;
    if (pet == null) {
      return const HomeState();
    }
    return _buildInitialState(pet, DateTime.now());
  }

  /// 활성 펫 기반 초기 상태 (Pet+BHI, 파생 데이터, 로컬 배지까지 한 번에 채움).
  ///
  /// Pet+BHI와 건강요약/인사이트는 서로 독립 요청이므로 병렬로 발사해
  /// 순차 왕복 1단계를 제거한다. derived 실패는 메인 상태에 영향 없음(null 처리).
  Future<HomeState> _buildInitialState(Pet pet, DateTime targetDate) async {
    final base = HomeState(activePet: pet);

    final pairFuture = _repo.loadPetWithBhi(pet.id, targetDate);
    final derivedFuture = _repo
        .loadHealthDerivedData(pet.id)
        .then<HomeDerivedData?>((v) => v)
        .catchError((Object e) {
      if (kDebugMode) debugPrint('[HomeViewModel] derived data failed: $e');
      return null;
    });

    final pair = await pairFuture;
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

    final derived = await derivedFuture;
    if (derived != null) {
      next = next.copyWith(
        healthSummary: derived.healthSummary,
        insight: derived.insight,
      );
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
  ///
  /// 저장이 없었으면 BhiService 캐시가 그대로 유효(동일 인스턴스 반환)하므로
  /// state 재발행을 생략한다 — pop 전환 애니메이션 중 홈 전체 rebuild 방지.
  /// 저장이 있었으면 Repository가 캐시를 무효화했으므로 서버 재조회 후 반영된다.
  Future<void> refreshBhi() async {
    final current = state.valueOrNull;
    final pet = current?.activePet;
    if (pet == null) return;
    try {
      final bhi = await _repo.loadBhiForDate(pet.id, DateTime.now());
      if (identical(bhi, state.valueOrNull?.bhi)) return;
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

  /// 당겨서 새로고침 — 캐시를 우회해 서버에서 [targetDate](화면에서 선택된 기간)의
  /// BHI를 강제 재조회한다. (refreshBhi는 캐시-우선이라 최신 데이터를 강제하지 못함)
  Future<void> pullToRefresh(DateTime targetDate) async {
    final current = state.valueOrNull;
    final pet = current?.activePet;
    if (pet == null) return;

    final requestId = ++_bhiRequestId;
    state = AsyncData(current!.copyWith(isBhiLoading: true));
    try {
      final bhi =
          await _repo.loadBhiForDate(pet.id, targetDate, forceRefresh: true);
      if (requestId != _bhiRequestId) return;
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
      state = AsyncData(latest.copyWith(isBhiLoading: false, isBhiOffline: true));
      if (kDebugMode) debugPrint('[HomeViewModel] pullToRefresh failed: $e');
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
