import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sync/sync_service.dart';
import '../services/water/water_record_service.dart';
import 'save_outcome.dart';

/// 수분 기록 Repository — 일 단위 totalMl + count 관리.
abstract class WaterRepository {
  /// 해당 날짜 수분 기록 로드 (서버 우선, 로컬 fallback, pending 있으면 로컬).
  /// 반환: (totalMl, count) 또는 null(데이터 없음).
  Future<({double totalMl, int count})?> loadByDate({
    required String petId,
    required DateTime date,
  });

  /// 저장: 로컬 + 서버 (실패 시 enqueue).
  Future<SaveOutcome> save({
    required String petId,
    required DateTime date,
    required double totalMl,
    required double targetMl,
    required int count,
  });
}

class WaterRepositoryImpl implements WaterRepository {
  WaterRepositoryImpl({
    WaterRecordService? service,
    SyncService? sync,
  })  : _service = service ?? WaterRecordService.instance,
        _sync = sync ?? SyncService.instance;

  final WaterRecordService _service;
  final SyncService _sync;

  String _storageKey(String petId, DateTime date) {
    final d = '${date.year}-${date.month}-${date.day}';
    return 'water_${petId}_$d';
  }

  @override
  Future<({double totalMl, int count})?> loadByDate({
    required String petId,
    required DateTime date,
  }) async {
    final dateStr = date.toIso8601String().split('T').first;

    if (!_sync.hasPending('water', petId, dateStr)) {
      try {
        final record = await _service.getByDate(petId, date);
        if (record != null) {
          return (totalMl: record.totalMl, count: record.count);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[WaterRepo] server load failed: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey(petId, date));
    if (raw == null) return null;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return (
      totalMl: (map['totalMl'] as num).toDouble(),
      count: map['count'] as int? ?? 0,
    );
  }

  @override
  Future<SaveOutcome> save({
    required String petId,
    required DateTime date,
    required double totalMl,
    required double targetMl,
    required int count,
  }) async {
    // 1) 로컬
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(petId, date),
      jsonEncode({'totalMl': totalMl, 'count': count}),
    );

    // 2) 서버 upsert
    final dateKey = SyncService.dateKey(date);
    try {
      await _service.upsert(
        petId: petId,
        recordedDate: date,
        totalMl: totalMl,
        targetMl: targetMl,
        count: count,
      );
      await _sync.markMutationSynced(
        type: 'water',
        petId: petId,
        date: dateKey,
      );
      await _sync.drainAfterSuccess();
      return SaveOutcome.online;
    } catch (e) {
      if (kDebugMode) debugPrint('[WaterRepo] backend failed, enqueue: $e');
      await _sync.enqueue(SyncItem(
        type: 'water',
        petId: petId,
        date: dateKey,
        payload: {
          'totalMl': totalMl,
          'targetMl': targetMl,
          'count': count,
        },
      ));
      return SaveOutcome.offline;
    }
  }
}
