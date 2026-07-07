import 'package:shared_preferences/shared_preferences.dart';

import '../models/bhi_result.dart';
import '../models/health_summary.dart';
import '../models/pet.dart';
import '../models/pet_insight.dart';
import '../services/api/api_client.dart';
import '../services/bhi/bhi_service.dart';
import '../services/pet/pet_local_cache_service.dart';
import '../services/pet/pet_service.dart';
import '../services/sync/sync_service.dart';
import '../services/weight/weight_service.dart';

/// 홈 화면 전용 aggregated data fetcher.
///
/// 홈 화면은 Pet + BHI + HealthSummary + Insight + 오프라인 로컬 데이터
/// 유무까지 한 화면에서 필요로 한다. 이를 각각 다른 ViewModel에서 구독시키지 않고
/// HomeRepository가 묶어서 제공하여 HomeViewModel이 단일 의존으로 처리하도록 한다.
abstract class HomeRepository {
  /// 펫 정보 + 오늘의 BHI 병렬 로드 (홈 진입/펫 전환 시).
  /// BHI 실패 시 bhi는 null.
  Future<({Pet? pet, BhiResult? bhi})> loadPetWithBhi(
    String petId,
    DateTime targetDate,
  );

  /// 특정 날짜의 BHI만 재조회 (기간 선택 변경 시).
  Future<BhiResult> loadBhiForDate(String petId, DateTime targetDate,
      {bool forceRefresh = false});

  /// 펫 로컬 캐시에서 Pet 정보 복원 (서버 실패 시 fallback).
  Future<Pet?> loadPetFromLocalCache(String petId);

  /// 오프라인 상태에서 UI 배지용 로컬 데이터 존재 여부 확인.
  Future<LocalDataAvailability> checkLocalDataAvailability(
    String petId,
    DateTime date,
  );

  /// 건강 요약 + 주간 인사이트 로드.
  Future<HomeDerivedData> loadHealthDerivedData(String petId);

  /// 오프라인 큐 처리 (fire-and-forget 용도; 실패는 내부 로깅).
  Future<void> processOfflineQueue();

  /// 최초 1회 로컬 전체 데이터 서버 업로드 (펫별).
  Future<void> syncLocalRecordsIfNeeded(String petId);

  /// BHI 서버 마지막 조회 시점 (UI 타임스탬프 표시용).
  DateTime? get lastBhiFetchTime;
}

/// 오프라인 상황에서 배지 색을 결정하기 위한 로컬 데이터 존재 여부.
class LocalDataAvailability {
  final bool hasWeight;
  final bool hasFood;
  final bool hasWater;

  const LocalDataAvailability({
    required this.hasWeight,
    required this.hasFood,
    required this.hasWater,
  });
}

/// 건강 요약/인사이트의 한 번에 묶인 응답.
class HomeDerivedData {
  final HealthSummary? healthSummary;
  final PetInsight? insight;

  const HomeDerivedData({
    this.healthSummary,
    this.insight,
  });
}

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl({
    PetService? petService,
    PetLocalCacheService? petCache,
    BhiService? bhiService,
    ApiClient? apiClient,
    WeightService? weightService,
    SyncService? syncService,
  })  : _petService = petService ?? PetService.instance,
        _petCache = petCache ?? PetLocalCacheService.instance,
        _bhiService = bhiService ?? BhiService.instance,
        _api = apiClient ?? ApiClient.instance,
        _weightService = weightService ?? WeightService.instance,
        _syncService = syncService ?? SyncService.instance;

  final PetService _petService;
  final PetLocalCacheService _petCache;
  final BhiService _bhiService;
  final ApiClient _api;
  final WeightService _weightService;
  final SyncService _syncService;

  @override
  DateTime? get lastBhiFetchTime => _bhiService.lastServerFetchTime;

  @override
  Future<({Pet? pet, BhiResult? bhi})> loadPetWithBhi(
    String petId,
    DateTime targetDate,
  ) async {
    final petFuture = _petService.getPetById(petId);
    final bhiFuture = _bhiService
        .getBhi(petId, targetDate: targetDate)
        .then<BhiResult?>((v) => v)
        .catchError((_) => null);
    final results = await Future.wait<dynamic>([petFuture, bhiFuture]);
    return (pet: results[0] as Pet?, bhi: results[1] as BhiResult?);
  }

  @override
  Future<BhiResult> loadBhiForDate(String petId, DateTime targetDate,
          {bool forceRefresh = false}) =>
      _bhiService.getBhi(petId,
          targetDate: targetDate, forceRefresh: forceRefresh);

  @override
  Future<Pet?> loadPetFromLocalCache(String petId) async {
    final cached = await _petCache.getActivePet();
    if (cached == null || cached.id != petId) return null;
    return Pet(
      id: cached.id,
      userId: '',
      name: cached.name,
      species: cached.species ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<LocalDataAvailability> checkLocalDataAvailability(
    String petId,
    DateTime date,
  ) async {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    final prefs = await SharedPreferences.getInstance();
    final hasWeight = _weightService
        .getRecordsByDate(date, petId: petId)
        .isNotEmpty;
    final hasFood = prefs.getString('food_${petId}_$dateKey') != null;
    final hasWater = prefs.getString('water_${petId}_$dateKey') != null;
    return LocalDataAvailability(
      hasWeight: hasWeight,
      hasFood: hasFood,
      hasWater: hasWater,
    );
  }

  @override
  Future<HomeDerivedData> loadHealthDerivedData(String petId) async {
    final summaryFuture = _api.get('/pets/$petId/health-summary');
    // 주간 인사이트는 항상 조회 (프리미엄 게이트 제거).
    // catchError를 Future.wait 이전에 부착해 insight 실패는 null로 흡수하고,
    // summary가 먼저 실패해도 insight future가 unhandled async error가 되지 않게 한다.
    final insightFuture = _api
        .get('/pets/$petId/insights?type=weekly')
        .then<PetInsight?>((insightJson) => insightJson != null
            ? PetInsight.fromJson(insightJson as Map<String, dynamic>)
            : null)
        .catchError((_) => null);

    final results =
        await Future.wait<dynamic>([summaryFuture, insightFuture]);

    final summary =
        HealthSummary.fromJson(results[0] as Map<String, dynamic>);
    final insight = results[1] as PetInsight?;

    return HomeDerivedData(
      healthSummary: summary,
      insight: insight,
    );
  }

  @override
  Future<void> processOfflineQueue() => _syncService.processQueue();

  @override
  Future<void> syncLocalRecordsIfNeeded(String petId) =>
      _syncService.syncLocalRecordsIfNeeded(petId);
}
