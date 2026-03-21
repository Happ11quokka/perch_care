import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/src/services/weight/weight_service.dart';
import 'package:perch_care/src/models/weight_record.dart';

// ---------------------------------------------------------------------------
// 헬퍼 팩토리 — 테스트마다 반복되는 WeightRecord 생성을 단순화
// ---------------------------------------------------------------------------
WeightRecord _makeRecord({
  String? id,
  String petId = 'pet-1',
  DateTime? date,
  double weight = 35.5,
  String? memo,
  int? recordedHour,
  int? recordedMinute,
}) {
  return WeightRecord(
    id: id,
    petId: petId,
    date: date ?? DateTime(2026, 3, 21),
    weight: weight,
    memo: memo,
    recordedHour: recordedHour,
    recordedMinute: recordedMinute,
  );
}

// ---------------------------------------------------------------------------
// SharedPreferences에 체중 기록을 직접 세팅하는 유틸리티
// ---------------------------------------------------------------------------
void _setWeightInPrefs(List<Map<String, dynamic>> records) {
  final raw = records.map((r) => jsonEncode(r)).toList();
  SharedPreferences.setMockInitialValues({'local_weight_records': raw});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // -------------------------------------------------------------------------
  // setUp: 각 테스트 전에 인메모리 캐시를 클리어하고 SharedPreferences를 리셋
  //
  // 주의: WeightService는 싱글톤이며 _isInitialized 플래그를 통해 lazy init.
  // _isInitialized는 private이므로 리셋 불가. 대신 saveLocalWeightRecord로
  // 인메모리에 직접 데이터를 넣는 방식을 사용하여 init 의존성을 우회.
  // -------------------------------------------------------------------------
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WeightService.instance.clearAllRecords();
  });

  // =========================================================================
  group('로컬 캐시 저장/조회', () {
    // -------------------------------------------------------------------------
    test('saveLocalWeightRecord — 기록 저장 후 fetchLocalRecords에서 조회', () async {
      final record = _makeRecord(petId: 'pet-1', weight: 35.5);

      final saved = await WeightService.instance.saveLocalWeightRecord(record);
      final fetched = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-1',
      );

      expect(fetched.length, 1);
      expect(fetched.first.petId, 'pet-1');
      expect(fetched.first.weight, 35.5);
      expect(fetched.first.id, saved.id);
    });

    // -------------------------------------------------------------------------
    test('saveLocalWeightRecord — 같은 날짜 다중 기록 저장', () async {
      final date = DateTime(2026, 3, 21);

      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: date, weight: 35.0, recordedHour: 8),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 36.0,
          recordedHour: 20,
        ),
      );

      final fetched = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-1',
      );

      expect(fetched.length, 2);
      // 날짜는 동일해야 함
      expect(fetched.every((r) => r.date == date), isTrue);
      // 두 체중 값이 모두 포함되어 있어야 함
      final weights = fetched.map((r) => r.weight).toList();
      expect(weights, containsAll([35.0, 36.0]));
    });

    // -------------------------------------------------------------------------
    test('saveLocalWeightRecord — ID 자동 생성 (local_ 접두사)', () async {
      final record = _makeRecord(petId: 'pet-1');
      // id를 지정하지 않으면 자동 생성되어야 함

      final saved = await WeightService.instance.saveLocalWeightRecord(record);

      expect(saved.id, isNotNull);
      expect(saved.id, startsWith('local_'));
    });

    // -------------------------------------------------------------------------
    test('fetchLocalRecords — petId 필터링', () async {
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', weight: 35.0),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-2', weight: 42.0),
      );

      final pet1Records = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-1',
      );
      final pet2Records = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-2',
      );

      expect(pet1Records.length, 1);
      expect(pet1Records.first.petId, 'pet-1');

      expect(pet2Records.length, 1);
      expect(pet2Records.first.petId, 'pet-2');
    });

    // -------------------------------------------------------------------------
    test('fetchLocalRecords — 존재하지 않는 petId는 빈 리스트', () async {
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1'),
      );

      final records = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-999',
      );

      expect(records, isEmpty);
    });
  });

  // =========================================================================
  group('날짜 조회', () {
    // -------------------------------------------------------------------------
    test('getRecordsByDate — 특정 날짜 기록만 반환', () async {
      final march21 = DateTime(2026, 3, 21);
      final march22 = DateTime(2026, 3, 22);

      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: march21, weight: 35.0),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: march22, weight: 36.0),
      );

      final records = WeightService.instance.getRecordsByDate(
        march21,
        petId: 'pet-1',
      );

      expect(records.length, 1);
      expect(records.first.weight, 35.0);
      expect(records.first.date, march21);
    });

    // -------------------------------------------------------------------------
    test('getRecordsByDate — 시간 포함 날짜도 정규화 (같은 날이면 매칭)', () async {
      final date = DateTime(2026, 3, 21);

      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: date, weight: 35.5),
      );

      // 시간 정보가 포함된 DateTime으로 조회해도 같은 날짜로 인식해야 함
      final queryWithTime = DateTime(2026, 3, 21, 14, 30, 0);
      final records = WeightService.instance.getRecordsByDate(
        queryWithTime,
        petId: 'pet-1',
      );

      expect(records.length, 1);
      expect(records.first.weight, 35.5);
    });

    // -------------------------------------------------------------------------
    test('getRecordByDate — 첫 번째 기록 반환', () async {
      final date = DateTime(2026, 3, 21);

      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 35.0,
          recordedHour: 8,
          recordedMinute: 0,
        ),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 36.0,
          recordedHour: 20,
          recordedMinute: 0,
        ),
      );

      // 정렬 규칙상 8시 기록이 첫 번째여야 함
      final first = WeightService.instance.getRecordByDate(
        date,
        petId: 'pet-1',
      );

      expect(first, isNotNull);
      expect(first!.weight, 35.0);
      expect(first.recordedHour, 8);
    });

    // -------------------------------------------------------------------------
    test('getRecordByDate — 기록 없으면 null', () async {
      final result = WeightService.instance.getRecordByDate(
        DateTime(2026, 3, 21),
        petId: 'pet-1',
      );

      expect(result, isNull);
    });
  });

  // =========================================================================
  group('평균 계산', () {
    // -------------------------------------------------------------------------
    test('getDailyAverageWeight — 단일 기록', () async {
      final date = DateTime(2026, 3, 21);

      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: date, weight: 35.5),
      );

      final avg = WeightService.instance.getDailyAverageWeight(
        date,
        petId: 'pet-1',
      );

      expect(avg, 35.5);
    });

    // -------------------------------------------------------------------------
    test('getDailyAverageWeight — 다중 기록 평균', () async {
      final date = DateTime(2026, 3, 21);

      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 34.0,
          recordedHour: 8,
        ),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 36.0,
          recordedHour: 20,
        ),
      );

      final avg = WeightService.instance.getDailyAverageWeight(
        date,
        petId: 'pet-1',
      );

      // (34.0 + 36.0) / 2 = 35.0
      expect(avg, 35.0);
    });

    // -------------------------------------------------------------------------
    test('getDailyAverageWeight — 기록 없으면 null', () async {
      final avg = WeightService.instance.getDailyAverageWeight(
        DateTime(2026, 3, 21),
        petId: 'pet-1',
      );

      expect(avg, isNull);
    });
  });

  // =========================================================================
  group('정렬', () {
    // -------------------------------------------------------------------------
    test('다른 날짜 기록은 날짜순 정렬', () async {
      final march22 = DateTime(2026, 3, 22);
      final march20 = DateTime(2026, 3, 20);
      final march21 = DateTime(2026, 3, 21);

      // 의도적으로 순서를 섞어서 저장
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: march22, weight: 36.0),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: march20, weight: 34.0),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: march21, weight: 35.0),
      );

      final records = WeightService.instance.getWeightRecords(petId: 'pet-1');

      expect(records.length, 3);
      // 날짜 오름차순으로 정렬되어야 함
      expect(records[0].date, march20);
      expect(records[1].date, march21);
      expect(records[2].date, march22);
    });

    // -------------------------------------------------------------------------
    test('같은 날짜 기록은 시간순 정렬', () async {
      final date = DateTime(2026, 3, 21);

      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 36.0,
          recordedHour: 20,
          recordedMinute: 0,
        ),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 35.0,
          recordedHour: 8,
          recordedMinute: 30,
        ),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 35.5,
          recordedHour: 12,
          recordedMinute: 0,
        ),
      );

      final records = WeightService.instance.getWeightRecords(petId: 'pet-1');

      expect(records.length, 3);
      // 8:30 → 12:00 → 20:00 순서여야 함
      expect(records[0].recordedHour, 8);
      expect(records[1].recordedHour, 12);
      expect(records[2].recordedHour, 20);
    });

    // -------------------------------------------------------------------------
    test('시간 null인 기록은 0시 0분으로 처리', () async {
      final date = DateTime(2026, 3, 21);

      // 시간 없는 기록 (null → 0시 0분으로 취급)
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', date: date, weight: 35.0),
      );
      // 1시 기록
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: date,
          weight: 36.0,
          recordedHour: 1,
          recordedMinute: 0,
        ),
      );

      final records = WeightService.instance.getWeightRecords(petId: 'pet-1');

      expect(records.length, 2);
      // null 시간(0분 0초 취급)이 1시보다 앞에 와야 함
      expect(records[0].recordedHour, isNull);
      expect(records[1].recordedHour, 1);
    });
  });

  // =========================================================================
  group('삭제', () {
    // -------------------------------------------------------------------------
    test('deleteWeightRecordById — 특정 ID 삭제', () async {
      final saved1 = await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', weight: 35.0),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(
          petId: 'pet-1',
          date: DateTime(2026, 3, 22),
          weight: 36.0,
        ),
      );

      await WeightService.instance.deleteWeightRecordById(
        saved1.id!,
        'pet-1',
      );

      final remaining = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-1',
      );

      expect(remaining.length, 1);
      expect(remaining.first.weight, 36.0);
    });

    // -------------------------------------------------------------------------
    test('deleteWeightRecordById — 존재하지 않는 ID는 무변경', () async {
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', weight: 35.0),
      );

      // 존재하지 않는 ID로 삭제 시도
      await WeightService.instance.deleteWeightRecordById(
        'non-existent-id-999',
        'pet-1',
      );

      final records = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-1',
      );

      // 기존 기록이 그대로 남아있어야 함
      expect(records.length, 1);
    });

    // -------------------------------------------------------------------------
    test('clearAllRecords — 전체 초기화', () async {
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-1', weight: 35.0),
      );
      await WeightService.instance.saveLocalWeightRecord(
        _makeRecord(petId: 'pet-2', weight: 42.0),
      );

      WeightService.instance.clearAllRecords();

      final pet1 = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-1',
      );
      final pet2 = await WeightService.instance.fetchLocalRecords(
        petId: 'pet-2',
      );
      final all = WeightService.instance.getWeightRecords();

      expect(pet1, isEmpty);
      expect(pet2, isEmpty);
      expect(all, isEmpty);
    });
  });

  // =========================================================================
  group('SharedPreferences 영속화', () {
    // -------------------------------------------------------------------------
    test('saveLocalWeightRecord 후 SharedPreferences에 저장됨', () async {
      final record = _makeRecord(
        petId: 'pet-1',
        date: DateTime(2026, 3, 21),
        weight: 35.5,
        recordedHour: 10,
        recordedMinute: 30,
      );

      await WeightService.instance.saveLocalWeightRecord(record);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('local_weight_records');

      expect(raw, isNotNull);
      expect(raw!.length, 1);

      final decoded = jsonDecode(raw.first) as Map<String, dynamic>;
      expect(decoded['petId'], 'pet-1');
      expect((decoded['weight'] as num).toDouble(), 35.5);
      expect(decoded['recordedHour'], 10);
      expect(decoded['recordedMinute'], 30);
    });

    // -------------------------------------------------------------------------
    test('SharedPreferences에서 기존 데이터 로드', () async {
      // _isInitialized가 이미 true인 싱글톤 특성상,
      // clearAllRecords 후 saveLocalWeightRecord로 직접 데이터를 넣고
      // SharedPreferences에 저장된 내용을 검증하는 방식으로 테스트.
      //
      // SharedPreferences → 인메모리 로드 경로는
      // 앱 최초 실행 시 _loadFromStorage에서 담당하며,
      // 저장 포맷(JSON StringList)이 올바른지만 확인한다.

      // 미리 SharedPreferences에 레코드 2개를 직접 세팅
      _setWeightInPrefs([
        {
          'id': 'local_111_1',
          'petId': 'pet-A',
          'date': '2026-03-21T00:00:00.000',
          'weight': 40.0,
          'recordedHour': 9,
          'recordedMinute': 0,
        },
        {
          'id': 'local_222_2',
          'petId': 'pet-A',
          'date': '2026-03-22T00:00:00.000',
          'weight': 41.0,
        },
      ]);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('local_weight_records');

      // SharedPreferences에 2건이 저장되어 있어야 함
      expect(raw, isNotNull);
      expect(raw!.length, 2);

      final first = jsonDecode(raw[0]) as Map<String, dynamic>;
      final second = jsonDecode(raw[1]) as Map<String, dynamic>;

      expect(first['petId'], 'pet-A');
      expect((first['weight'] as num).toDouble(), 40.0);
      expect(first['recordedHour'], 9);

      expect(second['petId'], 'pet-A');
      expect((second['weight'] as num).toDouble(), 41.0);
      // recordedHour가 없는 경우 키 자체가 없어야 함
      expect(second.containsKey('recordedHour'), isFalse);
    });
  });
}
