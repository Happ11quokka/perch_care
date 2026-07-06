import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pet_providers.dart';
import '../../providers/repository_providers.dart';
import '../../services/storage/health_check_storage_service.dart';
import '../base/async_view_model.dart';

/// health_check_history 화면용 ViewModel.
///
/// `activePetViewModelProvider`를 watch → 펫 전환 시 build()가 자동 재실행되어
/// 히스토리를 재조회한다. (기존 화면의 `ref.listen(activePetProvider, ...)` +
/// 수동 `_loadRecords()` 재호출 패턴을 이 watch가 대체한다.)
///
/// 날짜별 그루핑(`_groupByDate`)은 View의 파생 표시 로직으로 유지 —
/// 여기서는 flat list만 관리한다.
class HealthCheckHistoryViewModel
    extends AsyncViewModel<List<HealthCheckRecord>> {
  @override
  Future<List<HealthCheckRecord>> build() async {
    final pet = ref.watch(activePetViewModelProvider).valueOrNull;
    if (pet == null) return const [];
    return ref.read(healthCheckRepositoryProvider).loadHistory(pet.id);
  }

  /// 스와이프 삭제 — repo.delete(로컬+이미지+서버 best-effort) 후 state에서 낙관적으로 제거.
  Future<void> delete(HealthCheckRecord record) async {
    await ref.read(healthCheckRepositoryProvider).delete(record);
    final current = state.valueOrNull ?? const [];
    state = AsyncData(current.where((r) => r.id != record.id).toList());
  }

  /// Pull-to-refresh — 활성 펫 기준으로 서버 재조회.
  Future<void> refresh() async {
    final pet = ref.read(activePetViewModelProvider).valueOrNull;
    if (pet == null) {
      state = const AsyncData([]);
      return;
    }
    await runLoad(() => ref.read(healthCheckRepositoryProvider).loadHistory(pet.id));
  }
}

final healthCheckHistoryViewModelProvider = AsyncNotifierProvider<
    HealthCheckHistoryViewModel, List<HealthCheckRecord>>(
  HealthCheckHistoryViewModel.new,
);
