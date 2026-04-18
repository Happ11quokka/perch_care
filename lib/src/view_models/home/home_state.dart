import '../../models/bhi_result.dart';
import '../../models/health_summary.dart';
import '../../models/pet.dart';
import '../../models/pet_insight.dart';

/// HomeScreen 데이터 상태 (불변).
///
/// ViewModel이 `AsyncValue<HomeState>`로 노출하며, View는 `ref.watch`로 구독한다.
/// UI 선택기 상태(월/주 토글, 선택 월/주 등)는 HomeScreen의 StatefulWidget state로 유지 —
/// 데이터 로직이 아닌 순수 화면 상태이기 때문.
class HomeState {
  final Pet? activePet;
  final BhiResult? bhi;
  final HealthSummary? healthSummary;
  final PetInsight? insight;
  final bool isPremium;

  /// 기간 변경 시 BHI만 재로드 중인 상태 (전체 화면 로딩과 구분).
  final bool isBhiLoading;

  /// BHI 서버 로드 실패 → 오프라인 배너 표시용.
  final bool isBhiOffline;

  final int wciLevel;
  final bool hasWeight;
  final bool hasFood;
  final bool hasWater;

  /// BHI 마지막 서버 조회 시점 (UI 타임스탬프 계산용).
  final DateTime? lastBhiFetchTime;

  const HomeState({
    this.activePet,
    this.bhi,
    this.healthSummary,
    this.insight,
    this.isPremium = false,
    this.isBhiLoading = false,
    this.isBhiOffline = false,
    this.wciLevel = 0,
    this.hasWeight = false,
    this.hasFood = false,
    this.hasWater = false,
    this.lastBhiFetchTime,
  });

  HomeState copyWith({
    Pet? activePet,
    BhiResult? bhi,
    HealthSummary? healthSummary,
    PetInsight? insight,
    bool? isPremium,
    bool? isBhiLoading,
    bool? isBhiOffline,
    int? wciLevel,
    bool? hasWeight,
    bool? hasFood,
    bool? hasWater,
    DateTime? lastBhiFetchTime,
  }) {
    return HomeState(
      activePet: activePet ?? this.activePet,
      bhi: bhi ?? this.bhi,
      healthSummary: healthSummary ?? this.healthSummary,
      insight: insight ?? this.insight,
      isPremium: isPremium ?? this.isPremium,
      isBhiLoading: isBhiLoading ?? this.isBhiLoading,
      isBhiOffline: isBhiOffline ?? this.isBhiOffline,
      wciLevel: wciLevel ?? this.wciLevel,
      hasWeight: hasWeight ?? this.hasWeight,
      hasFood: hasFood ?? this.hasFood,
      hasWater: hasWater ?? this.hasWater,
      lastBhiFetchTime: lastBhiFetchTime ?? this.lastBhiFetchTime,
    );
  }
}
