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

  // 인메모리 데이터 저장소 (간단한 캐시)
  final List<WeightRecord> _records = [];
  bool _isInitialized = false;

  /// 모든 체중 기록 조회 (메모리 캐시)
  List<WeightRecord> getWeightRecords() => List.unmodifiable(_records);

  /// Supabase에서 전체 체중 기록을 불러와 캐시 업데이트
  Future<List<WeightRecord>> fetchAllRecords() async {
    await _ensureInitialized();
    return getWeightRecords();
  }

  /// 특정 날짜의 체중 기록 조회 (캐시 → Supabase 순으로 탐색)
  Future<WeightRecord?> fetchRecordByDate(DateTime date) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(date);
    final cached = getRecordByDate(normalizedDate);
    if (cached != null) {
      return cached;
    }
    return null;
  }

  /// 캐시에서 특정 날짜의 기록 반환
  WeightRecord? getRecordByDate(DateTime date) {
    final normalizedDate = _normalizeDate(date);
    try {
      return _records.firstWhere(
        (record) => _normalizeDate(record.date) == normalizedDate,
      );
    } catch (_) {
      return null;
    }
  }

  /// 체중 기록 저장 또는 수정
  /// - 동일 날짜 기록 존재 시 Update
  /// - 없으면 Insert
  Future<void> saveWeightRecord(WeightRecord record) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(record.date);
    _upsertLocal(record.copyWith(date: normalizedDate));
    await _persistToStorage();
  }

  /// 특정 날짜의 체중 기록 삭제
  Future<void> deleteWeightRecord(DateTime date) async {
    await _ensureInitialized();
    final normalizedDate = _normalizeDate(date);
    _records.removeWhere(
      (record) => _normalizeDate(record.date) == normalizedDate,
    );
    await _persistToStorage();
  }

  /// 날짜 정규화 (시간 정보 제거, 날짜만 비교)
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// 모든 데이터 클리어 (테스트용)
  void clearAllRecords() {
    _records.clear();
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
    final index = _records.indexWhere(
      (r) => _normalizeDate(r.date) == normalizedDate,
    );
    final normalizedRecord = record.copyWith(date: normalizedDate);
    if (index == -1) {
      _records.add(normalizedRecord);
    } else {
      _records[index] = normalizedRecord;
    }
    _records.sort((a, b) => a.date.compareTo(b.date));
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    await _loadFromStorage();
    _isInitialized = true;
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = prefs.getStringList(_storageKey) ?? [];
    final records = raw.map((e) {
      final map = jsonDecode(e) as Map<String, dynamic>;
      return WeightRecord(
        petId: map['petId'] as String? ?? 'default',
        date: DateTime.parse(map['date'] as String),
        weight: (map['weight'] as num).toDouble(),
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    _records
      ..clear()
      ..addAll(records);
  }

  Future<void> _persistToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _records
        .map((record) => jsonEncode({
              'date': record.date.toIso8601String(),
              'weight': record.weight,
            }))
        .toList();
    await prefs.setStringList(_storageKey, data);
  }
}
