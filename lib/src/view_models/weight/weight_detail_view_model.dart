import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/pet.dart';
import '../../models/weight_record.dart';
import '../../models/schedule_record.dart';
import '../../models/daily_record.dart';
import '../../providers/pet_providers.dart';
import '../../providers/repository_providers.dart';
import 'weight_detail_state.dart';

/// weight_detail 화면용 aggregated ViewModel.
///
/// activePetViewModelProvider를 watch → 활성 펫 전환 시 자동 재빌드/재로드.
/// (기존 화면의 provider→로컬 단방향 동기화 가드를 이 watch가 대체한다.)
/// 선택 월은 View 소유이므로 월 스코프 메서드는 year/month를 인자로 받는다.
class WeightDetailViewModel extends AsyncNotifier<WeightDetailState> {
  // build()가 재실행(펫 전환 등)되어도 AsyncNotifier 인스턴스는 유지되므로,
  // 마지막으로 loadForMonth()가 기록한 포커스 월을 인스턴스 필드로 기억해
  // build() 재조회 시 now()가 아닌 "View가 보고 있던 월"을 다시 로드한다.
  int? _focusedYear;
  int? _focusedMonth;

  @override
  Future<WeightDetailState> build() async {
    // 펫 '표시 내용' 키만 select — switchPet의 AsyncLoading 재발행에는 재빌드하지
    // 않아 구 펫 대상 낭비 리로드(전체 체중+일정+데일리)를 막는다.
    final petKey =
        ref.watch(activePetViewModelProvider.select(activePetContentKey));
    final activePet = petKey == null
        ? null
        : ref.read(activePetViewModelProvider).valueOrNull;
    final petRepo = ref.read(petRepositoryProvider);

    // 셀렉터용 펫 목록 (실패해도 화면은 뜬다)
    List<Pet> pets = const [];
    try {
      pets = await petRepo.getMyPets();
    } catch (_) {}

    // 활성 펫: watch 값 우선, 없으면 repository(서비스+로컬 폴백 내장)
    Pet? pet = activePet;
    if (pet == null) {
      try {
        pet = await petRepo.getActivePet();
      } catch (_) {}
    }

    if (pet == null) {
      return WeightDetailState(petList: pets);
    }

    final now = DateTime.now();
    final year = _focusedYear ?? now.year;
    final month = _focusedMonth ?? now.month;
    final results = await Future.wait([
      _loadWeight(pet.id),
      _loadSchedules(pet.id, year, month),
      _loadDailies(pet.id, year, month),
    ]);

    return WeightDetailState(
      petList: pets,
      activePetId: pet.id,
      petName: pet.name,
      weightRecords: results[0].cast<WeightRecord>(),
      scheduleRecords: results[1].cast<ScheduleRecord>(),
      dailyRecords: results[2].cast<DailyRecord>(),
    );
  }

  // 개별 로더 — 실패 시 빈 리스트 (화면이 죽지 않도록)
  Future<List> _loadWeight(String petId) async {
    final repo = ref.read(weightRepositoryProvider);
    try {
      return await repo.fetchAll(petId: petId);
    } catch (_) {
      try {
        return await repo.fetchLocal(petId: petId);
      } catch (_) {
        return const [];
      }
    }
  }

  Future<List> _loadSchedules(String petId, int year, int month) async {
    try {
      return await ref
          .read(scheduleRepositoryProvider)
          .fetchByMonth(petId: petId, year: year, month: month);
    } catch (_) {
      return const [];
    }
  }

  Future<List> _loadDailies(String petId, int year, int month) async {
    try {
      return await ref
          .read(dailyRecordRepositoryProvider)
          .getByMonth(petId, year, month);
    } catch (_) {
      return const [];
    }
  }

  String? get _petId => state.valueOrNull?.activePetId;

  /// 월 변경 시 schedule+daily만 재조회(weight는 전체이므로 불변).
  Future<void> loadForMonth(int year, int month) async {
    _focusedYear = year;
    _focusedMonth = month;
    final petId = _petId;
    final current = state.valueOrNull;
    if (petId == null || current == null) return;
    final results = await Future.wait([
      _loadSchedules(petId, year, month),
      _loadDailies(petId, year, month),
    ]);
    state = AsyncData(current.copyWith(
      scheduleRecords: results[0].cast<ScheduleRecord>(),
      dailyRecords: results[1].cast<DailyRecord>(),
    ));
  }

  Future<void> reloadWeight() async {
    final petId = _petId;
    final current = state.valueOrNull;
    if (petId == null || current == null) return;
    final records = await _loadWeight(petId);
    state = AsyncData(
        current.copyWith(weightRecords: records.cast<WeightRecord>()));
  }

  Future<void> createSchedule(
      ScheduleRecord schedule, {required int year, required int month}) async {
    await ref.read(scheduleRepositoryProvider).create(schedule);
    await loadForMonth(year, month);
  }

  /// 낙관적 삭제 — state에서 즉시 제거 후 서버 삭제. 실패 시 loadForMonth 롤백 후 rethrow.
  Future<void> deleteSchedule(
      ScheduleRecord schedule, {required int year, required int month}) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      scheduleRecords:
          current.scheduleRecords.where((r) => r.id != schedule.id).toList(),
    ));
    try {
      await ref
          .read(scheduleRepositoryProvider)
          .delete(schedule.id, petId: schedule.petId);
    } catch (e) {
      await loadForMonth(year, month);
      rethrow;
    }
  }

  Future<void> saveDailyRecord(
      DailyRecord record, {required int year, required int month}) async {
    await ref.read(dailyRecordRepositoryProvider).save(record);
    await loadForMonth(year, month);
  }

  /// 리로드형 삭제 — 성공/실패 모두 loadForMonth. 실패 시 rethrow(View 스낵바).
  Future<void> deleteDailyRecordByDate(
      DateTime date, {required int year, required int month}) async {
    final petId = _petId;
    if (petId == null) return;
    try {
      await ref.read(dailyRecordRepositoryProvider).deleteByDate(petId, date);
      await loadForMonth(year, month);
    } catch (e) {
      await loadForMonth(year, month);
      rethrow;
    }
  }
}

final weightDetailViewModelProvider =
    AsyncNotifierProvider<WeightDetailViewModel, WeightDetailState>(
        WeightDetailViewModel.new);
