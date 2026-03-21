import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/src/services/sync/sync_service.dart';

// ---------------------------------------------------------------------------
// 헬퍼 팩토리 — 테스트마다 반복되는 SyncItem 생성을 단순화
// ---------------------------------------------------------------------------
SyncItem _makeItem({
  String type = 'food',
  String petId = 'pet-1',
  String date = '2026-03-21',
  String? entityId,
  Map<String, dynamic>? payload,
  int retryCount = 0,
  int totalRetryCount = 0,
  DateTime? createdAt,
}) {
  return SyncItem(
    type: type,
    petId: petId,
    date: date,
    entityId: entityId,
    payload: payload ?? {'totalGrams': 100.0},
    retryCount: retryCount,
    totalRetryCount: totalRetryCount,
    createdAt: createdAt,
  );
}

// ---------------------------------------------------------------------------
// SharedPreferences 큐를 직접 세팅하는 유틸리티
// ---------------------------------------------------------------------------
Future<void> _setQueueInPrefs(List<SyncItem> items) async {
  final raw = items.map((i) => jsonEncode(i.toJson())).toList();
  SharedPreferences.setMockInitialValues({'sync_queue': raw});
}

void main() {
  // WidgetsBinding이 필요한 init() 호출을 위해 한 번만 초기화
  TestWidgetsFlutterBinding.ensureInitialized();

  // ------------------------------------------------------------------
  // group 1 : SyncItem 모델
  // ------------------------------------------------------------------
  group('SyncItem', () {
    test('fromJson 전체 필드 정상 파싱', () {
      final now = DateTime(2026, 3, 21, 9, 0, 0);
      final json = {
        'type': 'weight',
        'petId': 'pet-42',
        'date': '2026-03-21',
        'entityId': '9:30',
        'payload': {'weight': 3500.0},
        'createdAt': now.toIso8601String(),
        'retryCount': 2,
        'totalRetryCount': 7,
      };

      final item = SyncItem.fromJson(json);

      expect(item.type, 'weight');
      expect(item.petId, 'pet-42');
      expect(item.date, '2026-03-21');
      expect(item.entityId, '9:30');
      expect(item.payload, {'weight': 3500.0});
      expect(item.createdAt, now);
      expect(item.retryCount, 2);
      expect(item.totalRetryCount, 7);
    });

    test('fromJson 선택 필드 기본값 — entityId=default, retryCount=0', () {
      final json = {
        'type': 'water',
        'petId': 'pet-1',
        'date': '2026-03-21',
        // entityId 생략
        'payload': {'totalMl': 200.0},
        'createdAt': DateTime(2026, 3, 21).toIso8601String(),
        // retryCount / totalRetryCount 생략
      };

      final item = SyncItem.fromJson(json);

      expect(item.entityId, SyncService.defaultEntityId);
      expect(item.retryCount, 0);
      expect(item.totalRetryCount, 0);
    });

    test('toJson → fromJson 왕복 변환 후 동일 값 유지', () {
      final original = _makeItem(
        type: 'food',
        petId: 'pet-99',
        date: '2026-01-15',
        entityId: 'default',
        payload: {'totalGrams': 250.5, 'count': 3},
        retryCount: 1,
        totalRetryCount: 4,
        createdAt: DateTime(2026, 1, 15, 12, 30),
      );

      final roundTripped = SyncItem.fromJson(original.toJson());

      expect(roundTripped.type, original.type);
      expect(roundTripped.petId, original.petId);
      expect(roundTripped.date, original.date);
      expect(roundTripped.entityId, original.entityId);
      expect(roundTripped.payload, original.payload);
      expect(roundTripped.createdAt, original.createdAt);
      expect(roundTripped.retryCount, original.retryCount);
      expect(roundTripped.totalRetryCount, original.totalRetryCount);
    });

    test('toJson에 모든 필드 포함 확인', () {
      final item = _makeItem(
        type: 'food',
        petId: 'pet-1',
        date: '2026-03-21',
        entityId: 'default',
        payload: {'totalGrams': 100.0},
        retryCount: 0,
        totalRetryCount: 0,
      );

      final json = item.toJson();

      expect(json.containsKey('type'), isTrue);
      expect(json.containsKey('petId'), isTrue);
      expect(json.containsKey('date'), isTrue);
      expect(json.containsKey('entityId'), isTrue);
      expect(json.containsKey('payload'), isTrue);
      expect(json.containsKey('createdAt'), isTrue);
      expect(json.containsKey('retryCount'), isTrue);
      expect(json.containsKey('totalRetryCount'), isTrue);
      expect(json.keys.length, 8);
    });
  });

  // ------------------------------------------------------------------
  // group 2 : SyncService static helpers
  // ------------------------------------------------------------------
  group('SyncService static helpers', () {
    test('dateKey — DateTime을 YYYY-MM-DD 문자열로 변환', () {
      expect(SyncService.dateKey(DateTime(2026, 3, 21)), '2026-03-21');
      expect(SyncService.dateKey(DateTime(2024, 1, 1)), '2024-01-01');
      expect(SyncService.dateKey(DateTime(2024, 12, 31)), '2024-12-31');
    });

    test('weightEntityId — hour:minute 형식 반환', () {
      expect(SyncService.weightEntityId(recordedHour: 9, recordedMinute: 30), '9:30');
      expect(SyncService.weightEntityId(recordedHour: 0, recordedMinute: 0), '0:0');
      expect(SyncService.weightEntityId(recordedHour: 23, recordedMinute: 59), '23:59');
    });

    test('weightEntityId — 인수가 null이면 defaultEntityId 반환', () {
      expect(SyncService.weightEntityId(), SyncService.defaultEntityId);
      expect(
        SyncService.weightEntityId(recordedHour: 9, recordedMinute: null),
        SyncService.defaultEntityId,
      );
      expect(
        SyncService.weightEntityId(recordedHour: null, recordedMinute: 30),
        SyncService.defaultEntityId,
      );
    });

    test('defaultEntityId 상수값은 "default"', () {
      expect(SyncService.defaultEntityId, 'default');
    });
  });

  // ------------------------------------------------------------------
  // group 3 : SyncService 큐 관리 (SharedPreferences mock)
  // ------------------------------------------------------------------
  group('SyncService 큐 관리', () {
    // 각 테스트 전에 SharedPreferences와 큐를 초기화 상태로 되돌린다.
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SyncService.instance.init();
    });

    // ----------------------------------------------------------------
    // init
    // ----------------------------------------------------------------
    test('init — 빈 큐를 로드한다', () async {
      // setUp에서 이미 init()이 호출됐으므로 큐가 비어 있어야 한다.
      expect(SyncService.instance.hasPending('food', 'pet-1', '2026-03-21'), isFalse);
      expect(SyncService.instance.getPendingItems('food', 'pet-1'), isEmpty);
    });

    test('init — 저장된 큐를 로드하고 세션 retryCount를 0으로 리셋한다', () async {
      // retryCount=3인 항목을 SharedPreferences에 직접 설정
      final storedItem = _makeItem(retryCount: 3, totalRetryCount: 5);
      await _setQueueInPrefs([storedItem]);

      // 새 세션 시뮬레이션 — init() 재호출
      await SyncService.instance.init();

      final pending = SyncService.instance.getPendingItems('food', 'pet-1');
      expect(pending.length, 1);
      // retryCount는 세션 시작 시 0으로 리셋, totalRetryCount는 유지
      expect(pending.first.retryCount, 0);
      expect(pending.first.totalRetryCount, 5);
    });

    // ----------------------------------------------------------------
    // enqueue
    // ----------------------------------------------------------------
    test('enqueue — 신규 항목을 큐에 추가한다', () async {
      final item = _makeItem(type: 'food', petId: 'pet-1', date: '2026-03-21');
      await SyncService.instance.enqueue(item);

      expect(SyncService.instance.hasPending('food', 'pet-1', '2026-03-21'), isTrue);
      final pending = SyncService.instance.getPendingItems('food', 'pet-1');
      expect(pending.length, 1);
    });

    test('enqueue — 동일 키(type+petId+date+entityId)는 최신 항목으로 교체한다', () async {
      final first = _makeItem(payload: {'totalGrams': 100.0});
      final second = _makeItem(payload: {'totalGrams': 200.0});

      await SyncService.instance.enqueue(first);
      await SyncService.instance.enqueue(second);

      final pending = SyncService.instance.getPendingItems('food', 'pet-1');
      expect(pending.length, 1);
      expect(pending.first.payload['totalGrams'], 200.0);
    });

    test('enqueue — 다른 entityId는 별도 항목으로 유지한다', () async {
      final itemA = _makeItem(
        type: 'weight',
        petId: 'pet-1',
        date: '2026-03-21',
        entityId: '9:0',
        payload: {'weight': 3200.0},
      );
      final itemB = _makeItem(
        type: 'weight',
        petId: 'pet-1',
        date: '2026-03-21',
        entityId: '18:30',
        payload: {'weight': 3250.0},
      );

      await SyncService.instance.enqueue(itemA);
      await SyncService.instance.enqueue(itemB);

      final pending = SyncService.instance.getPendingItems('weight', 'pet-1');
      expect(pending.length, 2);

      final entityIds = pending.map((i) => i.entityId).toSet();
      expect(entityIds, containsAll(['9:0', '18:30']));
    });

    // ----------------------------------------------------------------
    // hasPending
    // ----------------------------------------------------------------
    test('hasPending — 해당 type+petId+date 항목이 존재하면 true', () async {
      await SyncService.instance.enqueue(
        _makeItem(type: 'water', petId: 'pet-2', date: '2026-03-20'),
      );

      expect(SyncService.instance.hasPending('water', 'pet-2', '2026-03-20'), isTrue);
    });

    test('hasPending — 항목이 없으면 false', () {
      expect(SyncService.instance.hasPending('water', 'pet-2', '2026-03-20'), isFalse);
    });

    // ----------------------------------------------------------------
    // getPendingItems
    // ----------------------------------------------------------------
    test('getPendingItems — type+petId로 필터링하여 반환한다', () async {
      // pet-1 food 2건
      await SyncService.instance.enqueue(
        _makeItem(type: 'food', petId: 'pet-1', date: '2026-03-21'),
      );
      await SyncService.instance.enqueue(
        _makeItem(type: 'food', petId: 'pet-1', date: '2026-03-20'),
      );
      // pet-2 food 1건 — 필터에 걸리지 않아야 함
      await SyncService.instance.enqueue(
        _makeItem(type: 'food', petId: 'pet-2', date: '2026-03-21'),
      );
      // pet-1 water 1건 — 다른 type이므로 필터에 걸리지 않아야 함
      await SyncService.instance.enqueue(
        _makeItem(type: 'water', petId: 'pet-1', date: '2026-03-21'),
      );

      final result = SyncService.instance.getPendingItems('food', 'pet-1');

      expect(result.length, 2);
      expect(result.every((i) => i.type == 'food' && i.petId == 'pet-1'), isTrue);
    });

    // ----------------------------------------------------------------
    // markMutationSynced
    // ----------------------------------------------------------------
    test('markMutationSynced — 정확한 항목만 제거한다', () async {
      final target = _makeItem(
        type: 'food',
        petId: 'pet-1',
        date: '2026-03-21',
        entityId: SyncService.defaultEntityId,
      );
      final other = _makeItem(
        type: 'food',
        petId: 'pet-1',
        date: '2026-03-20', // 다른 날짜
        entityId: SyncService.defaultEntityId,
      );

      await SyncService.instance.enqueue(target);
      await SyncService.instance.enqueue(other);

      await SyncService.instance.markMutationSynced(
        type: 'food',
        petId: 'pet-1',
        date: '2026-03-21',
        entityId: SyncService.defaultEntityId,
      );

      // 타겟 항목은 제거됐어야 함
      expect(SyncService.instance.hasPending('food', 'pet-1', '2026-03-21'), isFalse);
      // 다른 날짜 항목은 유지됐어야 함
      expect(SyncService.instance.hasPending('food', 'pet-1', '2026-03-20'), isTrue);
    });

    test('markMutationSynced — 큐에 없는 항목이면 큐를 변경하지 않는다', () async {
      final item = _makeItem(type: 'food', petId: 'pet-1', date: '2026-03-21');
      await SyncService.instance.enqueue(item);

      // 존재하지 않는 날짜로 호출
      await SyncService.instance.markMutationSynced(
        type: 'food',
        petId: 'pet-1',
        date: '2025-01-01',
        entityId: SyncService.defaultEntityId,
      );

      // 기존 항목은 그대로여야 함
      expect(SyncService.instance.hasPending('food', 'pet-1', '2026-03-21'), isTrue);
      expect(SyncService.instance.getPendingItems('food', 'pet-1').length, 1);
    });
  });
}
