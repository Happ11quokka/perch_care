import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/diet_entry.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/food_repository.dart';
import '../../repositories/save_outcome.dart';
import '../../services/analytics/analytics_service.dart';

/// 음식 기록 ViewModel — 엔트리 로드 + 저장.
class FoodRecordViewModel extends AsyncNotifier<void> {
  FoodRepository get _repo => ref.read(foodRepositoryProvider);

  @override
  Future<void> build() async {}

  Future<List<DietEntry>> loadEntries({
    required String petId,
    required DateTime date,
  }) {
    return _repo.loadEntriesByDate(petId: petId, date: date);
  }

  Future<SaveOutcome> saveEntries({
    required String petId,
    required DateTime date,
    required List<DietEntry> entries,
    required double totalEaten,
    required double totalServed,
  }) async {
    final outcome = await _repo.saveEntries(
      petId: petId,
      date: date,
      entries: entries,
      totalEaten: totalEaten,
      totalServed: totalServed,
    );
    try {
      AnalyticsService.instance.logFoodRecorded(petId, entries.length);
    } catch (_) {}
    return outcome;
  }
}

final foodRecordViewModelProvider =
    AsyncNotifierProvider<FoodRecordViewModel, void>(FoodRecordViewModel.new);
