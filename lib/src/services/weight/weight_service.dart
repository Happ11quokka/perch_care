import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/weight_record.dart';
import '../api/api_client.dart';

/// 체중 데이터 관리 서비스
/// FastAPI 백엔드와 연동, 1일 다중 기록 지원
class WeightService {
  WeightService();

  final _api = ApiClient.instance;

  static const String _storageKey = 'local_weight_records';

  // 펫별 인메모리 데이터 저장소 (간단한 캐시)
  final Map<String, List<WeightRecord>> _recordsByPet = {};
  bool _isInitialized = false;

  // 로컬 ID 생성용 카운터
  int _localIdCounter = 0;

  // 디바운스 저장
  Timer? _persistTimer;
  static const _persistDebounceDelay = Duration(seconds: 2);

  /// 로컬 전용 고유 ID 생성
  String _generateLocalId() {
    _localIdCounter++;
    return 'local_${DateTime.now().millisecondsSinceEpoch}_$_localIdCounter';
  }

  /// 모든 체중 기록 조회 (메모리 캐시)
  List<WeightRecord> getWeightRecords({String? petId}) {
    if (petId != null) {
      return List.unmodifiable(_recordsByPet[petId] ?? const <WeightRecord>[]);
    }

    final allRecords = _recordsByPet.values.expand((records) => records).toList()
      ..sort(_compareRecords);
    return List.unmodifiable(allRecords);
  }

  /// 특정 날짜의 모든 기록 리스트 반환 (다중 기록 지원)
  List<WeightRecord> getRecordsByDate(DateTime date, {String? petId}) {
    final normalizedDate = _normalizeDate(date);
    final List<WeightRecord> result = [];

    final Iterable<List<WeightRecord>> sources;
    if (petId != null) {
      final records = _recordsByPet[petId];
      if (records == null) return result;
      sources = [records];
    } else {
      sources = _recordsByPet.values;
    }

    for (final records in sources) {
      result.addAll(records.where(
        (record) => _normalizeDate(record.date) == normalizedDate,
      ));
    }

    result.sort(_compareRecords);
    return result;
  }

  /// 해당 날짜의 일평균 체중 반환
  double? getDailyAverageWeight(DateTime date, {String? petId}) {
    final records = getRecordsByDate(date, petId: petId);
    if (records.isEmpty) return null;
    final sum = records.fold(0.0, (total, r) => total + r.weight);
    return sum / records.length;
  }

  /// 서버에서 전체 체중 기록을 불러와 캐시 업데이트
  Future<List<WeightRecord>> fetchAllRecords({String? petId}) async {
    await _ensureInitialized();

    if (petId != null) {
      final response = await _api.get('/pets/$petId/weights/');
      final records = (response as List)
          .map((json) => WeightRecord.fromJson(json))
          .toList();

      _recordsByPet[petId] = records
        ..sort(_compareRecords);
      _schedulePersist();

      return List.unmodifiable(_recordsByPet[petId]!);
    }

    return getWeightRecords();
  }

  /// 로컬 캐시에서 체중 기록 로드 (서버 미사용)
  Future<List<WeightRecord>> fetchLocalRecords({String? petId}) async {
    await _ensureInitialized();
    if (petId != null) {
      return List.unmodifiable(_recordsByPet[petId] ?? const <WeightRecord>[]);
    }
    return getWeightRecords();
  }

  /// 특정 날짜의 체중 기록 조회 (캐시 → 서버 순으로 탐색)
  /// 다중 기록 중 첫 번째 반환 (하위 호환성)
  Future<WeightRecord?> fetchRecordByDate(DateTime date, {String? petId}) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(date);

    // Try cache first
    final cached = getRecordByDate(normalizedDate, petId: petId);
    if (cached != null) {
      return cached;
    }

    // Cache miss - query server if petId provided
    if (petId != null) {
      final dateStr = _formatDate(normalizedDate);
      final response = await _api.get('/pets/$petId/weights/by-date/$dateStr');

      if (response != null) {
        final record = WeightRecord.fromJson(response);
        _insertLocal(record);
        _schedulePersist();
        return record;
      }
    }

    return null;
  }

  /// 로컬 캐시에서 특정 날짜의 체중 기록 조회 (서버 미사용)
  /// 다중 기록 중 첫 번째 반환 (하위 호환성)
  Future<WeightRecord?> fetchLocalRecordByDate(
    DateTime date, {
    String? petId,
  }) async {
    await _ensureInitialized();
    return getRecordByDate(date, petId: petId);
  }

  /// 캐시에서 특정 날짜의 기록 반환 (첫 번째, 하위 호환성)
  WeightRecord? getRecordByDate(DateTime date, {String? petId}) {
    final records = getRecordsByDate(date, petId: petId);
    return records.isNotEmpty ? records.first : null;
  }

  /// 체중 기록 저장 (서버에 전송 + 로컬 캐시)
  Future<void> saveWeightRecord(WeightRecord record) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(record.date);

    await _api.post('/pets/${record.petId}/weights/', body: {
      'recorded_date': _formatDate(normalizedDate),
      'weight': record.weight,
      if (record.memo != null) 'memo': record.memo,
    });

    // 서버 API는 날짜 기반 upsert이므로, 로컬에서만 다중 기록 관리
    // 서버 전송은 가장 최근 기록으로 덮어쓰기됨
  }

  /// 로컬 캐시에 체중 기록 추가 (다중 기록 지원)
  Future<void> saveLocalWeightRecord(WeightRecord record) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(record.date);
    final recordWithId = record.copyWith(
      id: record.id ?? _generateLocalId(),
      date: normalizedDate,
    );
    _insertLocal(recordWithId);
    _schedulePersist();
  }

  /// 특정 ID의 체중 기록 삭제 (로컬)
  Future<void> deleteWeightRecordById(String recordId, String petId) async {
    await _ensureInitialized();
    final records = _recordsByPet[petId];
    if (records == null) return;

    records.removeWhere((r) => r.id == recordId);
    if (records.isEmpty) {
      _recordsByPet.remove(petId);
    }
    _schedulePersist();
  }

  /// 특정 날짜의 체중 기록 삭제
  Future<void> deleteWeightRecord(DateTime date, String petId) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(date);
    final dateStr = _formatDate(normalizedDate);

    await _api.delete('/pets/$petId/weights/by-date/$dateStr');

    // 로컬 캐시에서 삭제
    final records = _recordsByPet[petId];
    records?.removeWhere(
      (record) => _normalizeDate(record.date) == normalizedDate,
    );
    if (records != null && records.isEmpty) {
      _recordsByPet.remove(petId);
    }
    _schedulePersist();
  }

  /// 날짜 정규화 (시간 정보 제거, 날짜만 비교)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 모든 데이터 클리어 (테스트용)
  void clearAllRecords() {
    _recordsByPet.clear();
    _schedulePersist();
  }

  /// 특정 기간의 체중 기록 조회
  Future<List<WeightRecord>> getRecordsByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _api.get('/pets/$petId/weights/range', queryParams: {
      'start': _formatDate(start),
      'end': _formatDate(end),
    });

    return (response as List)
        .map((json) => WeightRecord.fromJson(json))
        .toList();
  }

  /// 월별 체중 평균 조회
  Future<List<Map<String, dynamic>>> getMonthlyAverages(
    String petId, {
    int? year,
  }) async {
    final params = <String, String>{};
    if (year != null) params['year'] = year.toString();

    final response = await _api.get(
      '/pets/$petId/weights/monthly-averages',
      queryParams: params.isNotEmpty ? params : null,
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// 주간 체중 데이터 조회
  Future<List<Map<String, dynamic>>> getWeeklyData(
    String petId,
    int year,
    int month,
    int week,
  ) async {
    final response = await _api.get(
      '/pets/$petId/weights/weekly-data',
      queryParams: {
        'year': year.toString(),
        'month': month.toString(),
        'week': week.toString(),
      },
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// 날짜 포맷 (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  /// 레코드 정렬 비교: 날짜 → 시간 순
  int _compareRecords(WeightRecord a, WeightRecord b) {
    final dateCompare = a.date.compareTo(b.date);
    if (dateCompare != 0) return dateCompare;
    final aMinutes = (a.recordedHour ?? 0) * 60 + (a.recordedMinute ?? 0);
    final bMinutes = (b.recordedHour ?? 0) * 60 + (b.recordedMinute ?? 0);
    return aMinutes.compareTo(bMinutes);
  }

  /// 로컬 캐시에 기록 추가 (id 기반, 다중 기록 지원)
  void _insertLocal(WeightRecord record) {
    final records = _recordsByPet.putIfAbsent(record.petId, () => []);
    if (record.id != null) {
      final index = records.indexWhere((r) => r.id == record.id);
      if (index != -1) {
        records[index] = record;
      } else {
        records.add(record);
      }
    } else {
      records.add(record);
    }
    records.sort(_compareRecords);
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    _isInitialized = true;
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_storageKey) ?? [];
    final Map<String, List<WeightRecord>> loaded = {};

    for (final item in raw) {
      final map = jsonDecode(item) as Map<String, dynamic>;
      final record = WeightRecord(
        id: map['id'] as String? ?? _generateLocalId(),
        petId: map['petId'] as String? ?? 'default',
        date: DateTime.parse(map['date'] as String),
        weight: (map['weight'] as num).toDouble(),
        recordedHour: map['recordedHour'] as int?,
        recordedMinute: map['recordedMinute'] as int?,
      );
      loaded.putIfAbsent(record.petId, () => []).add(record);
    }

    for (final entries in loaded.entries) {
      entries.value.sort(_compareRecords);
    }

    _recordsByPet
      ..clear()
      ..addAll(loaded);
  }

  /// 디바운스된 저장 스케줄링 (연속 호출 시 2초 후 한 번만 저장)
  void _schedulePersist() {
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounceDelay, () {
      _persistToStorageImmediate();
    });
  }

  Future<void> _persistToStorageImmediate() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _recordsByPet.values
        .expand((records) => records)
        .map((record) => jsonEncode({
              'id': record.id,
              'petId': record.petId,
              'date': record.date.toIso8601String(),
              'weight': record.weight,
              if (record.recordedHour != null) 'recordedHour': record.recordedHour,
              if (record.recordedMinute != null) 'recordedMinute': record.recordedMinute,
            }))
        .toList();
    await prefs.setStringList(_storageKey, data);
  }
}
