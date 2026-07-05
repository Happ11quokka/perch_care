import '../../models/pet.dart';
import '../../models/weight_record.dart';
import '../../models/schedule_record.dart';
import '../../models/daily_record.dart';

/// weight_detail 화면 aggregated 상태. UI 선택 상태(선택 월/주-월 토글/확장 여부)는
/// 의도적으로 제외 — View 소유(폼 상태 규칙).
class WeightDetailState {
  const WeightDetailState({
    this.petList = const [],
    this.activePetId,
    this.petName = '',
    this.weightRecords = const [],
    this.scheduleRecords = const [],
    this.dailyRecords = const [],
  });

  final List<Pet> petList;
  final String? activePetId;
  final String petName;
  final List<WeightRecord> weightRecords;
  final List<ScheduleRecord> scheduleRecords;
  final List<DailyRecord> dailyRecords;

  WeightDetailState copyWith({
    List<Pet>? petList,
    String? activePetId,
    String? petName,
    List<WeightRecord>? weightRecords,
    List<ScheduleRecord>? scheduleRecords,
    List<DailyRecord>? dailyRecords,
  }) {
    return WeightDetailState(
      petList: petList ?? this.petList,
      activePetId: activePetId ?? this.activePetId,
      petName: petName ?? this.petName,
      weightRecords: weightRecords ?? this.weightRecords,
      scheduleRecords: scheduleRecords ?? this.scheduleRecords,
      dailyRecords: dailyRecords ?? this.dailyRecords,
    );
  }
}
