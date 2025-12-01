import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/weight_record.dart';

/// 체중 데이터 관리 서비스
/// Supabase 테이블 `weight_records`와 연동
class WeightService {
  WeightService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _storageKey = 'local_weight_records';

  // 펫별 인메모리 데이터 저장소 (간단한 캐시)
  final Map<String, List<WeightRecord>> _recordsByPet = {};
  bool _isInitialized = false;

  /// 모든 체중 기록 조회 (메모리 캐시)
  List<WeightRecord> getWeightRecords({String? petId}) {
    if (petId != null) {
      return List.unmodifiable(_recordsByPet[petId] ?? const <WeightRecord>[]);
    }

    final allRecords = _recordsByPet.values.expand((records) => records).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return List.unmodifiable(allRecords);
  }

  /// Supabase에서 전체 체중 기록을 불러와 캐시 업데이트
  Future<List<WeightRecord>> fetchAllRecords({String? petId}) async {
    await _ensureInitialized();

    if (petId != null) {
      // Supabase에서 특정 펫의 체중 기록 조회
      final response = await _client
          .from('weight_records')
          .select()
          .eq('pet_id', petId)
          .order('recorded_date', ascending: true);

      final records = (response as List)
          .map((json) => WeightRecord.fromJson(json))
          .toList();

      // 로컬 캐시 업데이트 (해당 펫 데이터만 교체)
      _recordsByPet[petId] = records
        ..sort((a, b) => a.date.compareTo(b.date));
      await _persistToStorage();

      return List.unmodifiable(_recordsByPet[petId]!);
    }

    return getWeightRecords();
  }

  /// 특정 날짜의 체중 기록 조회 (캐시 → Supabase 순으로 탐색)
  Future<WeightRecord?> fetchRecordByDate(DateTime date, {String? petId}) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(date);

    // Try cache first
    final cached = getRecordByDate(normalizedDate, petId: petId);
    if (cached != null) {
      return cached;
    }

    // Cache miss - query Supabase if petId provided
    if (petId != null) {
      final response = await _client
          .from('weight_records')
          .select()
          .eq('pet_id', petId)
          .eq('recorded_date', _formatDate(normalizedDate))
          .maybeSingle();

      if (response != null) {
        final record = WeightRecord.fromJson(response);
        _upsertLocal(record);
        await _persistToStorage();
        return record;
      }
    }

    return null;
  }

  /// 캐시에서 특정 날짜의 기록 반환
  WeightRecord? getRecordByDate(DateTime date, {String? petId}) {
    final normalizedDate = _normalizeDate(date);
    final Iterable<List<WeightRecord>> sources;

    if (petId != null) {
      final records = _recordsByPet[petId];
      if (records == null) return null;
      sources = [records];
    } else {
      sources = _recordsByPet.values;
    }

    for (final records in sources) {
      try {
        return records.firstWhere(
          (record) => _normalizeDate(record.date) == normalizedDate,
        );
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// 체중 기록 저장 또는 수정
  /// - 동일 날짜 기록 존재 시 Update
  /// - 없으면 Insert
  Future<void> saveWeightRecord(WeightRecord record) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(record.date);

    // Supabase에 저장
    final existingRecord = await _client
        .from('weight_records')
        .select()
        .eq('pet_id', record.petId)
        .eq('recorded_date', _formatDate(normalizedDate))
        .maybeSingle();

    if (existingRecord != null) {
      // Update existing record
      await _client
          .from('weight_records')
          .update(record.toJson())
          .eq('id', existingRecord['id']);
    } else {
      // Insert new record
      await _client
          .from('weight_records')
          .insert(record.toInsertJson());
    }

    // 로컬 캐시 업데이트
    _upsertLocal(record.copyWith(date: normalizedDate));
    await _persistToStorage();
  }

  /// 특정 날짜의 체중 기록 삭제
  Future<void> deleteWeightRecord(DateTime date, String petId) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(date);

    // Supabase에서 삭제
    await _client
        .from('weight_records')
        .delete()
        .eq('pet_id', petId)
        .eq('recorded_date', _formatDate(normalizedDate));

    // 로컬 캐시에서 삭제
    final records = _recordsByPet[petId];
    records?.removeWhere(
      (record) => _normalizeDate(record.date) == normalizedDate,
    );
    if (records != null && records.isEmpty) {
      _recordsByPet.remove(petId);
    }
    await _persistToStorage();
  }

  /// 날짜 정규화 (시간 정보 제거, 날짜만 비교)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 모든 데이터 클리어 (테스트용)
  void clearAllRecords() {
    _recordsByPet.clear();
    _persistToStorage();
  }

  /// 특정 기간의 체중 기록 조회
  Future<List<WeightRecord>> getRecordsByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) async {
    final response = await _client
        .from('weight_records')
        .select()
        .eq('pet_id', petId)
        .gte('recorded_date', _formatDate(start))
        .lte('recorded_date', _formatDate(end))
        .order('recorded_date', ascending: true);

    return (response as List)
        .map((json) => WeightRecord.fromJson(json))
        .toList();
  }

  /// 월별 체중 평균 조회 (DB 함수 호출)
  Future<List<Map<String, dynamic>>> getMonthlyAverages(
    String petId, {
    int? year,
  }) async {
    final response = await _client.rpc(
      'get_monthly_weight_averages',
      params: {
        'p_pet_id': petId,
        if (year != null) 'p_year': year,
      },
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// 주간 체중 데이터 조회 (DB 함수 호출)
  Future<List<Map<String, dynamic>>> getWeeklyData(
    String petId,
    int year,
    int month,
    int week,
  ) async {
    final response = await _client.rpc(
      'get_weekly_weight_data',
      params: {
        'p_pet_id': petId,
        'p_year': year,
        'p_month': month,
        'p_week': week,
      },
    );

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// 날짜 포맷 (YYYY-MM-DD)
  String _formatDate(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  void _upsertLocal(WeightRecord record) {
    final normalizedDate = _normalizeDate(record.date);
    final normalizedRecord = record.copyWith(date: normalizedDate);
    final records = _recordsByPet.putIfAbsent(record.petId, () => []);
    final index = records.indexWhere(
      (r) => _normalizeDate(r.date) == normalizedDate,
    );
    if (index == -1) {
      records.add(normalizedRecord);
    } else {
      records[index] = normalizedRecord;
    }
    records.sort((a, b) => a.date.compareTo(b.date));
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
        petId: map['petId'] as String? ?? 'default',
        date: DateTime.parse(map['date'] as String),
        weight: (map['weight'] as num).toDouble(),
      );
      loaded.putIfAbsent(record.petId, () => []).add(record);
    }

    for (final entries in loaded.entries) {
      entries.value.sort((a, b) => a.date.compareTo(b.date));
    }

    _recordsByPet
      ..clear()
      ..addAll(loaded);
  }

  Future<void> _persistToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _recordsByPet.values
        .expand((records) => records)
        .map((record) => jsonEncode({
              'petId': record.petId,
              'date': record.date.toIso8601String(),
              'weight': record.weight,
            }))
        .toList();
    await prefs.setStringList(_storageKey, data);
  }
}
