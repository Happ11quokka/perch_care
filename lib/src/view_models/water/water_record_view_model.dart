import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import '../../repositories/save_outcome.dart';
import '../../repositories/water_repository.dart';
import '../../services/analytics/analytics_service.dart';

/// 수분 기록 ViewModel — 일 단위 totalMl/count 로드 + 저장.
class WaterRecordViewModel extends AsyncNotifier<void> {
  WaterRepository get _repo => ref.read(waterRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<({double totalMl, int count})?> loadByDate({
    required String petId,
    required DateTime date,
  }) {
    return _repo.loadByDate(petId: petId, date: date);
  }

  Future<SaveOutcome> save({
    required String petId,
    required DateTime date,
    required double totalMl,
    required double targetMl,
    required int count,
  }) async {
    final outcome = await _repo.save(
      petId: petId,
      date: date,
      totalMl: totalMl,
      targetMl: targetMl,
      count: count,
    );
    try {
      AnalyticsService.instance.logWaterRecorded(petId);
    } catch (_) {}
    return outcome;
  }
}

final waterRecordViewModelProvider =
    AsyncNotifierProvider<WaterRecordViewModel, void>(WaterRecordViewModel.new);
