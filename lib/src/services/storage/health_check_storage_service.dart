import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';

/// 건강체크 결과 로컬 저장용 레코드 모델
class HealthCheckRecord {
  final String id;
  final String? petId;
  final String mode; // VisionMode.value (full_body, part_specific, droppings, food)
  final String? imageUrl; // 서버 이미지 상대 경로 (30일 보관)
  final Map<String, dynamic> result;
  final double? confidenceScore;
  final String status; // overall_status
  final DateTime checkedAt;

  const HealthCheckRecord({
    required this.id,
    this.petId,
    required this.mode,
    this.imageUrl,
    required this.result,
    this.confidenceScore,
    required this.status,
    required this.checkedAt,
  });

  factory HealthCheckRecord.fromJson(Map<String, dynamic> json) {
    return HealthCheckRecord(
      id: json['id'] as String,
      petId: json['pet_id'] as String?,
      mode: json['mode'] as String,
      imageUrl: json['image_url'] as String?,
      result: json['result'] as Map<String, dynamic>,
      confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'normal',
      checkedAt: DateTime.parse(json['checked_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (petId != null) 'pet_id': petId,
      'mode': mode,
      if (imageUrl != null) 'image_url': imageUrl,
      'result': result,
      if (confidenceScore != null) 'confidence_score': confidenceScore,
      'status': status,
      'checked_at': checkedAt.toIso8601String(),
    };
  }
}

/// 건강체크 결과 로컬 저장 서비스 (SharedPreferences 기반)
class HealthCheckStorageService {
  static final HealthCheckStorageService instance =
      HealthCheckStorageService._();

  HealthCheckStorageService._();

  static const _keyPrefix = 'health_check_history_';
  static const _globalKey = '${_keyPrefix}global';
  static const _maxRecords = 50;

  SharedPreferences? _prefs;
  Future<void>? _writeLock;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String _getKey(String? petId) {
    if (petId == null || petId.isEmpty) {
      return _globalKey;
    }
    return '$_keyPrefix$petId';
  }

  /// 건강체크 결과 저장
  Future<void> saveRecord(HealthCheckRecord record) async {
    // 동시 쓰기 방지: 이전 쓰기 완료 대기
    while (_writeLock != null) {
      await _writeLock;
    }
    final completer = Completer<void>();
    _writeLock = completer.future;
    try {
      final prefs = await _getPrefs();
      final key = _getKey(record.petId);
      final existing = await getRecords(record.petId);

      // 중복 방지
      existing.removeWhere((r) => r.id == record.id);
      existing.insert(0, record);

      // 최대 개수 제한 (FIFO)
      final trimmed =
          existing.length > _maxRecords ? existing.sublist(0, _maxRecords) : existing;

      final jsonList = trimmed.map((r) => r.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));
    } catch (e) {
      debugPrint('[HealthCheckStorage] 저장 실패: $e');
    } finally {
      _writeLock = null;
      completer.complete();
    }
  }

  /// 특정 펫의 건강체크 기록 조회
  Future<List<HealthCheckRecord>> getRecords(String? petId) async {
    try {
      final prefs = await _getPrefs();
      final key = _getKey(petId);
      final jsonString = prefs.getString(key);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((item) =>
              HealthCheckRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[HealthCheckStorage] 조회 실패: $e');
      return [];
    }
  }

  /// 모든 펫의 건강체크 기록 조회 (히스토리 화면용)
  Future<List<HealthCheckRecord>> getAllRecords() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
      final allRecords = <HealthCheckRecord>[];

      for (final key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null && jsonString.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(jsonString);
          allRecords.addAll(jsonList.map((item) =>
              HealthCheckRecord.fromJson(item as Map<String, dynamic>)));
        }
      }

      // 최신순 정렬
      allRecords.sort((a, b) => b.checkedAt.compareTo(a.checkedAt));
      return allRecords;
    } catch (e) {
      debugPrint('[HealthCheckStorage] 전체 조회 실패: $e');
      return [];
    }
  }

  /// 특정 기록 삭제
  Future<void> deleteRecord(String? petId, String recordId) async {
    try {
      final prefs = await _getPrefs();
      final key = _getKey(petId);
      final records = await getRecords(petId);
      records.removeWhere((r) => r.id == recordId);

      if (records.isEmpty) {
        await prefs.remove(key);
      } else {
        final jsonList = records.map((r) => r.toJson()).toList();
        await prefs.setString(key, json.encode(jsonList));
      }
    } catch (e) {
      debugPrint('[HealthCheckStorage] 삭제 실패: $e');
    }
  }

  /// 전체 기록 삭제
  Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('[HealthCheckStorage] 전체 삭제 실패: $e');
    }
  }

  /// 서버에서 건강체크 기록 가져오기
  Future<List<HealthCheckRecord>> fetchFromServer(String petId) async {
    try {
      final data = await ApiClient.instance.get('/pets/$petId/health-checks/');
      final list = data as List<dynamic>;
      return list.map((item) {
        final json = item as Map<String, dynamic>;
        return HealthCheckRecord(
          id: json['id'] as String,
          petId: json['pet_id'] as String?,
          mode: json['check_type'] as String,
          imageUrl: json['image_url'] as String?,
          result: json['result'] as Map<String, dynamic>,
          confidenceScore: (json['confidence_score'] as num?)?.toDouble(),
          status: json['status'] as String? ?? 'normal',
          checkedAt: DateTime.parse(json['checked_at'] as String),
        );
      }).toList();
    } catch (e) {
      debugPrint('[HealthCheckStorage] 서버 조회 실패: $e');
      rethrow;
    }
  }

  /// 서버 데이터로 로컬 캐시 갱신
  Future<void> syncWithServer(String petId) async {
    final serverRecords = await fetchFromServer(petId);
    final prefs = await _getPrefs();
    final key = _getKey(petId);
    if (serverRecords.isEmpty) {
      await prefs.remove(key);
    } else {
      final jsonList = serverRecords.map((r) => r.toJson()).toList();
      await prefs.setString(key, json.encode(jsonList));
    }
  }
}
