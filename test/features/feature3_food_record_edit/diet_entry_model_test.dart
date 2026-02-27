import 'package:flutter_test/flutter_test.dart';
import 'package:perch_care/src/models/diet_entry.dart';

void main() {
  group('Feature 3: DietEntry 모델 테스트', () {
    group('fromJson', () {
      test('3.1 전체 필드 정상 파싱', () {
        final json = {
          'foodName': '사과',
          'type': 'eating',
          'grams': 15.5,
          'recordedHour': 8,
          'recordedMinute': 30,
          'memo': '잘 먹음',
        };

        final entry = DietEntry.fromJson(json);

        expect(entry.foodName, '사과');
        expect(entry.type, DietType.eating);
        expect(entry.grams, 15.5);
        expect(entry.recordedHour, 8);
        expect(entry.recordedMinute, 30);
        expect(entry.memo, '잘 먹음');
      });

      test('3.1b type=serving 정상 파싱', () {
        final json = {
          'foodName': '펠렛',
          'type': 'serving',
          'grams': 20.0,
        };

        final entry = DietEntry.fromJson(json);

        expect(entry.type, DietType.serving);
      });

      test('3.1c 선택 필드 없을 때 기본값 처리', () {
        final json = {
          'foodName': '씨앗',
          'type': 'eating',
          'grams': 10.0,
        };

        final entry = DietEntry.fromJson(json);

        expect(entry.recordedHour, isNull);
        expect(entry.recordedMinute, isNull);
        expect(entry.memo, isNull);
      });

      test('3.1d null foodName → 빈 문자열 기본값', () {
        final json = {
          'type': 'eating',
          'grams': 5.0,
        };

        final entry = DietEntry.fromJson(json);

        expect(entry.foodName, '');
      });

      test('3.1e null grams → 0 기본값', () {
        final json = {
          'foodName': '사과',
          'type': 'eating',
        };

        final entry = DietEntry.fromJson(json);

        expect(entry.grams, 0);
      });
    });

    group('fromLegacyJson', () {
      test('3.1f 기존 형식 마이그레이션 (name → foodName, totalGrams → grams)', () {
        final legacyJson = {
          'name': '해바라기씨',
          'totalGrams': 25.0,
        };

        final entry = DietEntry.fromLegacyJson(legacyJson);

        expect(entry.foodName, '해바라기씨');
        expect(entry.grams, 25.0);
        expect(entry.type, DietType.eating); // 기존 데이터는 모두 취식
        expect(entry.recordedHour, isNull);
        expect(entry.memo, isNull);
      });
    });

    group('toJson / 왕복 변환', () {
      test('3.2 toJson → fromJson 왕복 변환', () {
        const original = DietEntry(
          foodName: '사과',
          type: DietType.eating,
          grams: 15.5,
          recordedHour: 14,
          recordedMinute: 30,
          memo: '테스트 메모',
        );

        final json = original.toJson();
        final restored = DietEntry.fromJson(json);

        expect(restored.foodName, original.foodName);
        expect(restored.type, original.type);
        expect(restored.grams, original.grams);
        expect(restored.recordedHour, original.recordedHour);
        expect(restored.recordedMinute, original.recordedMinute);
        expect(restored.memo, original.memo);
      });

      test('3.2b toJson에서 null 필드 제외', () {
        const entry = DietEntry(
          foodName: '펠렛',
          type: DietType.serving,
          grams: 20.0,
        );

        final json = entry.toJson();

        expect(json.containsKey('recordedHour'), isFalse);
        expect(json.containsKey('recordedMinute'), isFalse);
        expect(json.containsKey('memo'), isFalse);
      });

      test('3.2c type 직렬화 (serving/eating 문자열)', () {
        const serving = DietEntry(
          foodName: 'A', type: DietType.serving, grams: 10,
        );
        const eating = DietEntry(
          foodName: 'B', type: DietType.eating, grams: 10,
        );

        expect(serving.toJson()['type'], 'serving');
        expect(eating.toJson()['type'], 'eating');
      });
    });

    group('copyWith', () {
      test('3.2d copyWith로 foodName만 변경', () {
        const original = DietEntry(
          foodName: '사과',
          type: DietType.eating,
          grams: 15.0,
          recordedHour: 8,
          recordedMinute: 0,
        );

        final modified = original.copyWith(foodName: '바나나');

        expect(modified.foodName, '바나나');
        expect(modified.type, original.type);
        expect(modified.grams, original.grams);
        expect(modified.recordedHour, original.recordedHour);
      });
    });

    group('hasTime / timeDisplayString', () {
      test('3.2e hasTime - hour와 minute 모두 있으면 true', () {
        const entry = DietEntry(
          foodName: 'A', type: DietType.eating, grams: 10,
          recordedHour: 8, recordedMinute: 30,
        );
        expect(entry.hasTime, isTrue);
      });

      test('3.2f hasTime - hour만 있으면 false', () {
        const entry = DietEntry(
          foodName: 'A', type: DietType.eating, grams: 10,
          recordedHour: 8,
        );
        expect(entry.hasTime, isFalse);
      });

      test('3.2g timeDisplayString - 오전 시간', () {
        const entry = DietEntry(
          foodName: 'A', type: DietType.eating, grams: 10,
          recordedHour: 8, recordedMinute: 5,
        );
        expect(entry.timeDisplayString, '오전 8:05');
      });

      test('3.2h timeDisplayString - 오후 시간', () {
        const entry = DietEntry(
          foodName: 'A', type: DietType.eating, grams: 10,
          recordedHour: 14, recordedMinute: 30,
        );
        expect(entry.timeDisplayString, '오후 2:30');
      });

      test('3.2i timeDisplayString - 자정 (hour=0)', () {
        const entry = DietEntry(
          foodName: 'A', type: DietType.eating, grams: 10,
          recordedHour: 0, recordedMinute: 0,
        );
        expect(entry.timeDisplayString, '오전 12:00');
      });

      test('3.2j timeDisplayString - 정오 (hour=12)', () {
        const entry = DietEntry(
          foodName: 'A', type: DietType.eating, grams: 10,
          recordedHour: 12, recordedMinute: 0,
        );
        expect(entry.timeDisplayString, '오후 12:00');
      });

      test('3.2k timeDisplayString - 시간 없으면 빈 문자열', () {
        const entry = DietEntry(
          foodName: 'A', type: DietType.eating, grams: 10,
        );
        expect(entry.timeDisplayString, '');
      });
    });

    group('리스트 조작 로직 (수정/추가)', () {
      final entry1 = const DietEntry(
        foodName: '사과', type: DietType.eating, grams: 10,
      );
      final entry2 = const DietEntry(
        foodName: '바나나', type: DietType.eating, grams: 15,
      );
      final entry3 = const DietEntry(
        foodName: '펠렛', type: DietType.serving, grams: 20,
      );

      test('3.3 수정 시 리스트 인플레이스 교체 (길이 유지)', () {
        final entries = [entry1, entry2, entry3];
        const updated = DietEntry(
          foodName: '수정된 바나나', type: DietType.eating, grams: 25,
        );

        final index = entries.indexOf(entry2);
        final result = [...entries]..[index] = updated;

        expect(result.length, 3);
        expect(result[0], entry1); // 첫 번째 유지
        expect(result[1].foodName, '수정된 바나나'); // 교체됨
        expect(result[2], entry3); // 세 번째 유지
      });

      test('3.4 추가 시 리스트 끝에 append', () {
        final entries = [entry1, entry2];
        const newEntry = DietEntry(
          foodName: '새 음식', type: DietType.serving, grams: 30,
        );

        final result = [...entries, newEntry];

        expect(result.length, 3);
        expect(result.last.foodName, '새 음식');
        expect(result[0], entry1);
        expect(result[1], entry2);
      });
    });
  });
}
