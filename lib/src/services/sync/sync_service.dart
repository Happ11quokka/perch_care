import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../api/token_service.dart';
import '../food/food_record_service.dart';
import '../pet/pet_service.dart';
import '../water/water_record_service.dart';
import '../weight/weight_service.dart';
import '../../models/weight_record.dart';

/// 서버 전송 실패 시 큐에 저장하고, 앱 재시작 시 자동 재전송하는 서비스
/// App resume 시에도 자동으로 큐를 재처리한다.
class SyncService with WidgetsBindingObserver {
  static final SyncService instance = SyncService._();
  SyncService._();

  static const _queueKey = 'sync_queue';
  static const _maxRetries = 5;
  static const _maxTotalRetries = 20; // 전체 세션 합산 최대 재시도
  static const defaultEntityId = 'default';

  static String dateKey(DateTime date) =>
      date.toIso8601String().split('T').first;

  static String weightEntityId({int? recordedHour, int? recordedMinute}) {
    if (recordedHour == null || recordedMinute == null) {
      return defaultEntityId;
    }
    return '$recordedHour:$recordedMinute';
  }

  /// 펫별 초기 동기화 완료 키
  String _initialSyncKey(String petId) => 'sync_initial_done_$petId';
  static const _defaultMigratedKey = 'sync_default_migrated';

  List<SyncItem> _queue = [];
  bool _isProcessing = false;

  /// 앱 시작 시 호출: SharedPreferences에서 큐 로드 + 라이프사이클 옵저버 등록
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    _queue = raw
        .map((json) {
          try {
            return SyncItem.fromJson(jsonDecode(json));
          } catch (_) {
            return null;
          }
        })
        .whereType<SyncItem>()
        .toList();
    // 새 세션이므로 retryCount 리셋 — 매 앱 시작마다 재시도 기회 부여
    for (final item in _queue) {
      item.retryCount = 0;
    }

    // App resume 시 큐 재처리를 위해 옵저버 등록
    WidgetsBinding.instance.addObserver(this);

    if (kDebugMode) { debugPrint('[SyncService] Loaded ${_queue.length} pending items'); }
  }

  /// App resume 시 큐 자동 재처리
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _queue.isNotEmpty) {
      if (kDebugMode) debugPrint(
        '[SyncService] App resumed, draining queue (${_queue.length} items)',
      );
      processQueue();
    }
  }

  /// 특정 type+petId+date 조합에 대해 pending 항목이 있는지 확인
  bool hasPending(String type, String petId, String date) {
    return _queue.any(
      (item) => item.type == type && item.petId == petId && item.date == date,
    );
  }

  /// 특정 type+petId의 모든 pending 항목 반환
  List<SyncItem> getPendingItems(String type, String petId) {
    return _queue
        .where((item) => item.type == type && item.petId == petId)
        .toList();
  }

  /// 직접 서버 저장이 성공한 항목은 큐에서 제거해 stale payload 재전송을 막는다.
  Future<void> markMutationSynced({
    required String type,
    required String petId,
    required String date,
    String entityId = defaultEntityId,
  }) async {
    final before = _queue.length;
    _queue.removeWhere(
      (item) =>
          item.type == type &&
          item.petId == petId &&
          item.date == date &&
          item.entityId == entityId,
    );
    if (_queue.length == before) return;
    await _persist();
    if (kDebugMode) debugPrint(
      '[SyncService] Cleared pending: $type $date (entity: $entityId)',
    );
  }

  /// 서버 저장 성공 후 호출: 큐에 남은 항목이 있으면 백그라운드 드레인
  Future<void> drainAfterSuccess() async {
    if (_queue.isNotEmpty && !_isProcessing) {
      if (kDebugMode) debugPrint(
        '[SyncService] Drain after successful save (${_queue.length} items)',
      );
      await processQueue();
    }
  }

  /// 큐에 아이템 추가
  Future<void> enqueue(SyncItem item) async {
    // 같은 type+petId+date+entityId 조합이 있으면 최신 것으로 교체
    // weight는 같은 날 여러 건이 있을 수 있으므로 entityId로 구분
    _queue.removeWhere(
      (existing) =>
          existing.type == item.type &&
          existing.petId == item.petId &&
          existing.date == item.date &&
          existing.entityId == item.entityId,
    );
    _queue.add(item);
    await _persist();
    if (kDebugMode) debugPrint(
      '[SyncService] Enqueued: ${item.type} ${item.date} (entity: ${item.entityId})',
    );
  }

  /// 재시도해도 성공할 수 없는 에러인지 판별
  bool _isNonRetryableError(Object error) {
    if (error is ApiException) {
      // 4xx 클라이언트 에러는 대부분 재시도 무의미
      // 단, 408 (Request Timeout), 429 (Too Many Requests)는 일시적이므로 재시도
      if (error.statusCode >= 400 && error.statusCode < 500) {
        return !{401, 403, 408, 429}.contains(error.statusCode);
      }
      // 500이면서 FK/integrity 관련 메시지 → 비재시도
      if (error.statusCode == 500) {
        final msg = error.message.toLowerCase();
        return msg.contains('foreign key') ||
            msg.contains('integrity') ||
            msg.contains('not found') ||
            msg.contains('does not exist');
      }
    }
    return false;
  }

  /// 큐의 모든 아이템을 서버로 전송 시도
  Future<void> processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    // 토큰 없으면 전송 시도 자체를 스킵 — 다음 로그인 후 처리
    if (TokenService.instance.accessToken == null) {
      if (kDebugMode) { debugPrint('[SyncService] No auth token, skipping queue processing'); }
      return;
    }

    _isProcessing = true;

    final succeeded = <SyncItem>[];

    for (final item in List.of(_queue)) {
      if (item.totalRetryCount >= _maxTotalRetries) {
        // 전체 누적 최대치 도달 — 영구 제거
        succeeded.add(item);
        if (kDebugMode) debugPrint(
          '[SyncService] Removing item after ${item.totalRetryCount} total retries: ${item.type} ${item.date}',
        );
        continue;
      }
      if (item.retryCount >= _maxRetries) {
        if (kDebugMode) debugPrint(
          '[SyncService] Skipping this session after max retries: ${item.type} ${item.date}',
        );
        continue;
      }
      try {
        await _sendToServer(item);
        succeeded.add(item);
        if (kDebugMode) { debugPrint('[SyncService] Synced: ${item.type} ${item.date}'); }
      } catch (e) {
        if (e is FormatException || e is StateError) {
          // 데이터 자체가 손상 — retry 무의미, 즉시 제거
          succeeded.add(item);
          if (kDebugMode) debugPrint(
            '[SyncService] Removing corrupted item: ${item.type} ${item.date} - $e',
          );
        } else if (_isNonRetryableError(e)) {
          // 서버가 명확히 거부 (404, 422, FK violation 등) — 재시도 무의미
          succeeded.add(item);
          if (kDebugMode) debugPrint(
            '[SyncService] Removing non-retryable item: ${item.type} ${item.date} - $e',
          );
        } else {
          item.retryCount++;
          item.totalRetryCount++;
          if (kDebugMode) debugPrint(
            '[SyncService] Failed (${item.retryCount}/$_maxRetries, total: ${item.totalRetryCount}/$_maxTotalRetries): ${item.type} ${item.date} - $e',
          );
          if (item.retryCount >= _maxRetries) {
            // 이번 세션에서는 스킵, 다음 세션에서 재시도 (데이터 삭제 안 함)
            if (kDebugMode) debugPrint(
              '[SyncService] Max retries this session, will retry next launch: ${item.type} ${item.date}',
            );
          }
        }
      }
    }

    _queue.removeWhere(succeeded.contains);
    await _persist();
    _isProcessing = false;
    if (kDebugMode) { debugPrint('[SyncService] Queue remaining: ${_queue.length}'); }
  }

  /// 최초 1회: 로컬 SharedPreferences의 food/water 데이터를 서버로 업로드
  Future<void> syncLocalRecordsIfNeeded(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_initialSyncKey(petId)) == true) return;

    // default 키는 1회만 처리 (여러 펫 순회 시 중복 방지)
    final defaultAlreadyMigrated = prefs.getBool(_defaultMigratedKey) == true;

    if (kDebugMode) debugPrint(
      '[SyncService] Starting initial local→server sync for pet: $petId (defaultMigrated: $defaultAlreadyMigrated)',
    );
    int synced = 0;
    int failed = 0;

    final allKeys = prefs.getKeys();

    // Food 기록 동기화
    final foodKeys = allKeys.where(
      (k) => k.startsWith('food_') && !k.startsWith('food_names_'),
    );
    for (final key in foodKeys) {
      try {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        final entries = jsonDecode(raw) as List;
        if (entries.isEmpty) continue;

        // 키에서 petId와 date 추출: food_{petId}_{date}
        final parts = key.split('_');
        if (parts.length < 3) continue;
        final keyPetId = parts[1];
        final dateStr = parts.sublist(2).join('-'); // year-month-day

        // default 키는 이미 처리됐으면 스킵
        if (keyPetId == 'default' && defaultAlreadyMigrated) continue;
        // 해당 펫 또는 default 키만 처리
        if (keyPetId != petId && keyPetId != 'default') continue;

        final dateParts = dateStr.split('-');
        if (dateParts.length != 3) continue;
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        double totalEaten = 0;
        double totalServed = 0;
        int count = entries.length;
        for (final e in entries) {
          final grams = (e['grams'] as num?)?.toDouble() ?? 0;
          final type = e['type'] as String?;
          if (type == 'eating') {
            totalEaten += grams;
          } else {
            totalServed += grams;
          }
        }

        await FoodRecordService.instance.upsert(
          petId: keyPetId == 'default' ? petId : keyPetId,
          recordedDate: date,
          totalGrams: totalEaten,
          targetGrams: totalServed,
          count: count,
          entriesJson: jsonEncode(entries),
        );
        synced++;
      } catch (e) {
        failed++;
        if (kDebugMode) { debugPrint('[SyncService] Food sync failed for $key: $e'); }
      }
    }

    // Water 기록 동기화
    final waterKeys = allKeys.where((k) => k.startsWith('water_'));
    for (final key in waterKeys) {
      try {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        final data = jsonDecode(raw) as Map<String, dynamic>;

        final parts = key.split('_');
        if (parts.length < 3) continue;
        final keyPetId = parts[1];
        final dateStr = parts.sublist(2).join('-');

        // default 키는 이미 처리됐으면 스킵
        if (keyPetId == 'default' && defaultAlreadyMigrated) continue;
        if (keyPetId != petId && keyPetId != 'default') continue;

        final dateParts = dateStr.split('-');
        if (dateParts.length != 3) continue;
        final date = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );

        final totalMl = (data['totalMl'] as num?)?.toDouble() ?? 0;
        final count = (data['count'] as num?)?.toInt() ?? 1;

        await WaterRecordService.instance.upsert(
          petId: keyPetId == 'default' ? petId : keyPetId,
          recordedDate: date,
          totalMl: totalMl,
          targetMl: totalMl, // 로컬에 targetMl 없으면 totalMl로 대체
          count: count,
        );
        synced++;
      } catch (e) {
        failed++;
        if (kDebugMode) { debugPrint('[SyncService] Water sync failed for $key: $e'); }
      }
    }

    // Weight 자동 마이그레이션은 의도적으로 제외.
    // local_weight_records에는 서버에서 내려받은 캐시도 함께 섞여 있어
    // production 첫 실행 시 전체 재업로드를 수행하면 중복 생성 위험이 있다.
    // weight는 명시적 offline queue(processQueue) 경로만 서버 재전송 대상으로 취급한다.

    // 실패가 있으면 완료 마킹하지 않음 — 다음 앱 시작 시 재시도
    if (failed > 0) {
      if (kDebugMode) debugPrint(
        '[SyncService] Initial sync partial: $synced synced, $failed failed — will retry next launch',
      );
    } else {
      await prefs.setBool(_initialSyncKey(petId), true);
      // default 키도 처리 완료 마킹 (첫 번째 펫 순회 시)
      if (!defaultAlreadyMigrated) {
        await prefs.setBool(_defaultMigratedKey, true);
      }
      if (kDebugMode) { debugPrint('[SyncService] Initial sync complete: $synced records synced'); }
    }
  }

  /// 서버로 전송 (pet 존재 확인 포함)
  Future<void> _sendToServer(SyncItem item) async {
    // pet_id가 서버에 존재하는지 확인 — 없으면 StateError로 즉시 큐에서 제거
    final pet = await PetService.instance.getPetById(item.petId);
    if (pet == null) {
      throw StateError('Pet ${item.petId} does not exist on server');
    }

    final dateParts = item.date.split('-');
    final date = DateTime(
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      int.parse(dateParts[2]),
    );

    switch (item.type) {
      case 'food':
        await FoodRecordService.instance.upsert(
          petId: item.petId,
          recordedDate: date,
          totalGrams: (item.payload['totalGrams'] as num?)?.toDouble() ?? 0,
          targetGrams: (item.payload['targetGrams'] as num?)?.toDouble() ?? 0,
          count: (item.payload['count'] as num?)?.toInt() ?? 1,
          entriesJson: item.payload['entriesJson'] as String?,
        );
        break;
      case 'water':
        await WaterRecordService.instance.upsert(
          petId: item.petId,
          recordedDate: date,
          totalMl: (item.payload['totalMl'] as num?)?.toDouble() ?? 0,
          targetMl: (item.payload['targetMl'] as num?)?.toDouble() ?? 0,
          count: (item.payload['count'] as num?)?.toInt() ?? 1,
        );
        break;
      case 'weight':
        await WeightService.instance.saveWeightRecord(
          WeightRecord(
            id: item.payload['localId'] as String?,
            petId: item.petId,
            weight: (item.payload['weight'] as num?)?.toDouble() ?? 0,
            date: date,
            memo: item.payload['memo'] as String?,
            recordedHour: (item.payload['recordedHour'] as num?)?.toInt(),
            recordedMinute: (item.payload['recordedMinute'] as num?)?.toInt(),
          ),
        );
        break;
      default:
        throw StateError('Unknown sync type: ${item.type}');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _queue.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_queueKey, raw);
  }
}

/// 동기화 큐 아이템
class SyncItem {
  final String type; // 'food', 'water', 'weight'
  final String petId;
  final String date; // YYYY-MM-DD
  final String entityId; // dedup 키 — food/water는 default, weight는 시간 등으로 구분
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  int retryCount;
  int totalRetryCount; // 전체 세션 누적 재시도 (init에서 리셋 안 함)

  SyncItem({
    required this.type,
    required this.petId,
    required this.date,
    required this.payload,
    String? entityId,
    DateTime? createdAt,
    this.retryCount = 0,
    this.totalRetryCount = 0,
  }) : entityId = entityId ?? SyncService.defaultEntityId,
       createdAt = createdAt ?? DateTime.now();

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    return SyncItem(
      type: json['type'] as String,
      petId: json['petId'] as String,
      date: json['date'] as String,
      entityId: json['entityId'] as String? ?? SyncService.defaultEntityId,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      totalRetryCount: (json['totalRetryCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'petId': petId,
    'date': date,
    'entityId': entityId,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
    'totalRetryCount': totalRetryCount,
  };
}
