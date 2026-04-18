import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/diet_entry.dart';
import '../services/food/food_record_service.dart';
import '../services/sync/sync_service.dart';
import 'save_outcome.dart';

/// 음식 기록 Repository — 일 단위 엔트리 리스트 관리.
///
/// Food 저장은 (1) 로컬 SharedPreferences → (2) 서버 upsert → (3) 실패 시 큐 적재 순서.
/// 로컬이 SSOT이며, pending sync가 있으면 서버 대신 로컬에서 로드한다.
abstract class FoodRepository {
  /// 해당 날짜의 엔트리 로드. pending sync 있으면 로컬, 없으면 서버 → 로컬 순 fallback.
  Future<List<DietEntry>> loadEntriesByDate({
    required String petId,
    required DateTime date,
  });

  /// 로컬 + 서버 저장 (실패 시 enqueue).
  /// 반환: 서버 성공이면 online, 실패(→ enqueue)면 offline.
  Future<SaveOutcome> saveEntries({
    required String petId,
    required DateTime date,
    required List<DietEntry> entries,
    required double totalEaten,
    required double totalServed,
  });
}

class FoodRepositoryImpl implements FoodRepository {
  FoodRepositoryImpl({
    FoodRecordService? service,
    SyncService? sync,
  })  : _service = service ?? FoodRecordService.instance,
        _sync = sync ?? SyncService.instance;

  final FoodRecordService _service;
  final SyncService _sync;

  String _storageKey(String petId, DateTime date) {
    final d = '${date.year}-${date.month}-${date.day}';
    return 'food_${petId}_$d';
  }

  @override
  Future<List<DietEntry>> loadEntriesByDate({
    required String petId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;

    // pending sync가 있으면 서버 대신 로컬
    if (!_sync.hasPending('food', petId, dateStr)) {
      try {
        final record = await _service.getByDate(petId, date);
        if (record?.entriesJson != null) {
          return _decodeEntries(record!.entriesJson!);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[FoodRepo] server load failed: $e');
      }
    }

    // 로컬 fallback
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(petId, date));
    if (raw == null) return [];
    return _decodeEntries(raw);
  }

  List<DietEntry> _decodeEntries(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((item) {
      final map = item as Map<String, dynamic>;
      return map.containsKey('type')
          ? DietEntry.fromJson(map)
          : DietEntry.fromLegacyJson(map);
    }).toList();
  }

  @override
  Future<SaveOutcome> saveEntries({
    required String petId,
    required DateTime date,
    required List<DietEntry> entries,
    required double totalEaten,
    required double totalServed,
  }) async {
    final data = entries.map((e) => e.toJson()).toList();
    final entriesJson = jsonEncode(data);

    // 1) 로컬 영속화
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(petId, date), entriesJson);

    // 2) 서버 upsert
    final dateKey = SyncService.dateKey(date);
    try {
      await _service.upsert(
        petId: petId,
        recordedDate: date,
        totalGrams: totalEaten,
        targetGrams: totalServed,
        count: entries.length,
        entriesJson: entriesJson,
      );
      await _sync.markMutationSynced(
        type: 'food',
        petId: petId,
        date: dateKey,
      );
      await _sync.drainAfterSuccess();
      return SaveOutcome.online;
    } catch (e) {
      if (kDebugMode) debugPrint('[FoodRepo] backend failed, enqueue: $e');
      await _sync.enqueue(SyncItem(
        type: 'food',
        petId: petId,
        date: dateKey,
        payload: {
          'totalGrams': totalEaten,
          'targetGrams': totalServed,
          'count': entries.length,
          'entriesJson': entriesJson,
        },
      ));
      return SaveOutcome.offline;
    }
  }
}
