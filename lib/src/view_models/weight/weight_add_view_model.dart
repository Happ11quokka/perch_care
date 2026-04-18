import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/weight_record.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/weight_repository.dart';
import '../../services/analytics/analytics_service.dart';

/// 체중 추가 입력 ViewModel.
///
/// - View: `WeightAddScreen`, `WeightRecordScreen`(인라인 입력 모드)
/// - 상태: `AsyncValue<void>` (진행 중/완료/에러)
/// - 규약: 로컬 저장 성공이 곧 UX 성공. 백엔드 동기화는 Repository가 fire-and-forget 처리.
class WeightAddViewModel extends AsyncNotifier<void> {
  WeightRepository get _repo => ref.read(weightRepositoryProvider);

  @override
  Future<void> build() async {}

  /// 체중 기록 저장 — 로컬 영속화 + 백엔드 sync(enqueue 포함)를 Repository에 위임.
  Future<WeightRecord> saveRecord(WeightRecord record) async {
    state = const AsyncLoading<void>();
    try {
      final local = await _repo.saveRecord(record);
      try {
        AnalyticsService.instance.logWeightRecorded(record.petId);
      } catch (_) {
        // Firebase 미초기화(예: 테스트) 환경에서는 무시
      }
      state = const AsyncData(null);
      return local;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }
}

final weightAddViewModelProvider =
    AsyncNotifierProvider<WeightAddViewModel, void>(WeightAddViewModel.new);
