import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/weight_record.dart';
import '../services/sync/sync_service.dart';
import '../services/weight/weight_service.dart';

/// 체중 기록 Repository.
///
/// ViewModel은 이 인터페이스만 보고 `WeightService` / `SyncService`를 직접 호출하지 않는다.
/// 기록 저장 시 "로컬 먼저 + 백엔드 fire-and-forget + 실패 시 오프라인 큐"의 규약을 캡슐화한다.
abstract class WeightRepository {
  /// 서버에서 전체 기록 로드 (인메모리 캐시에 반영).
  Future<List<WeightRecord>> fetchAll({required String petId});

  /// 로컬 캐시에서 전체 기록 (네트워크 미사용).
  Future<List<WeightRecord>> fetchLocal({required String petId});

  /// 메모리 캐시에서 특정 날짜 기록 리스트.
  List<WeightRecord> getByDate(DateTime date, {required String petId});

  /// 특정 날짜 일평균.
  double? getDailyAverage(DateTime date, {required String petId});

  /// 기록 저장 — 로컬 저장 + 백엔드 동기화(실패 시 SyncService 큐에 적재).
  ///
  /// 반환: 로컬에 저장된 (ID 부여된) 레코드. 백엔드 실패는 내부에서 처리(SyncItem으로 enqueue)
  /// 하고 호출자에게 throw하지 않는다.
  Future<WeightRecord> saveRecord(WeightRecord record);

  /// 날짜 기반 삭제 (서버).
  Future<void> deleteByDate(DateTime date, {required String petId});

  /// ID 기반 로컬 삭제.
  Future<void> deleteById(String recordId, {required String petId});

  /// 월별 평균 (차트용).
  Future<List<Map<String, dynamic>>> getMonthlyAverages(
    String petId, {
    int? year,
  });

  /// 주간 데이터 (차트용).
  Future<List<Map<String, dynamic>>> getWeeklyData(
    String petId,
    int year,
    int month,
    int week,
  );

  /// 기간 기반 기록 조회.
  Future<List<WeightRecord>> getRecordsByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  );
}

class WeightRepositoryImpl implements WeightRepository {
  WeightRepositoryImpl({
    WeightService? service,
    SyncService? sync,
  })  : _service = service ?? WeightService.instance,
        _sync = sync ?? SyncService.instance;

  final WeightService _service;
  final SyncService _sync;

  @override
  Future<List<WeightRecord>> fetchAll({required String petId}) =>
      _service.fetchAllRecords(petId: petId);

  @override
  Future<List<WeightRecord>> fetchLocal({required String petId}) =>
      _service.fetchLocalRecords(petId: petId);

  @override
  List<WeightRecord> getByDate(DateTime date, {required String petId}) =>
      _service.getRecordsByDate(date, petId: petId);

  @override
  double? getDailyAverage(DateTime date, {required String petId}) =>
      _service.getDailyAverageWeight(date, petId: petId);

  @override
  Future<WeightRecord> saveRecord(WeightRecord record) async {
    // 1) 로컬 저장 (사용자 입력 손실 방지 — 실패하면 즉시 throw)
    final local = await _service.saveLocalWeightRecord(record);

    // 2) 백엔드 동기화는 fire-and-forget (UI 블로킹 방지). 실패 시 큐에 적재.
    unawaited(_syncToBackend(local));

    return local;
  }

  Future<void> _syncToBackend(WeightRecord local) async {
    final dateKey = SyncService.dateKey(local.date);
    final entityId = SyncService.weightEntityId(
      recordedHour: local.recordedHour,
      recordedMinute: local.recordedMinute,
    );
    try {
      await _service.saveWeightRecord(local);
      await _sync.markMutationSynced(
        type: 'weight',
        petId: local.petId,
        date: dateKey,
        entityId: entityId,
      );
      await _sync.drainAfterSuccess();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WeightRepository] backend save failed, enqueue: $e');
      }
      await _sync.enqueue(SyncItem(
        type: 'weight',
        petId: local.petId,
        date: dateKey,
        entityId: entityId,
        payload: {
          'localId': local.id,
          'weight': local.weight,
          'recordedHour': local.recordedHour,
          'recordedMinute': local.recordedMinute,
          if (local.memo != null) 'memo': local.memo,
        },
      ));
    }
  }

  @override
  Future<void> deleteByDate(DateTime date, {required String petId}) =>
      _service.deleteWeightRecord(date, petId);

  @override
  Future<void> deleteById(String recordId, {required String petId}) =>
      _service.deleteWeightRecordById(recordId, petId);

  @override
  Future<List<Map<String, dynamic>>> getMonthlyAverages(
    String petId, {
    int? year,
  }) =>
      _service.getMonthlyAverages(petId, year: year);

  @override
  Future<List<Map<String, dynamic>>> getWeeklyData(
    String petId,
    int year,
    int month,
    int week,
  ) =>
      _service.getWeeklyData(petId, year, month, week);

  @override
  Future<List<WeightRecord>> getRecordsByDateRange(
    String petId,
    DateTime start,
    DateTime end,
  ) =>
      _service.getRecordsByDateRange(petId, start, end);
}
