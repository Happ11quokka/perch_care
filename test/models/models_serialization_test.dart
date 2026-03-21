import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/models/weight_record.dart';
import 'package:perch_care/src/models/food_record.dart';
import 'package:perch_care/src/models/water_intake_record.dart';
import 'package:perch_care/src/models/daily_record.dart';
import 'package:perch_care/src/models/schedule_record.dart';
import 'package:perch_care/src/models/breed_standard.dart';
import 'package:perch_care/src/models/health_summary.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Pet
  // ---------------------------------------------------------------------------
  group('Pet', () {
    // 공통 픽스처
    Map<String, dynamic> fullJson() => {
          'id': 'pet-001',
          'user_id': 'user-abc',
          'name': '코코',
          'species': 'budgerigar',
          'breed': '잉꼬',
          'breed_id': 'breed-1',
          'birth_date': '2022-03-15',
          'gender': 'male',
          'growth_stage': 'adult',
          'weight': 35.5,
          'adoption_date': '2022-04-01',
          'profile_image_url': 'https://example.com/coco.jpg',
          'is_active': true,
          'created_at': '2022-04-01T10:00:00.000Z',
          'updated_at': '2024-01-10T08:30:00.000Z',
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final pet = Pet.fromJson(fullJson());

      expect(pet.id, 'pet-001');
      expect(pet.userId, 'user-abc');
      expect(pet.name, '코코');
      expect(pet.species, 'budgerigar');
      expect(pet.breed, '잉꼬');
      expect(pet.breedId, 'breed-1');
      expect(pet.birthDate, DateTime(2022, 3, 15));
      expect(pet.gender, 'male');
      expect(pet.growthStage, 'adult');
      expect(pet.weight, 35.5);
      expect(pet.weight, isA<double>());
      expect(pet.adoptionDate, DateTime(2022, 4, 1));
      expect(pet.profileImageUrl, 'https://example.com/coco.jpg');
      expect(pet.isActive, isTrue);
      expect(pet.createdAt, DateTime.parse('2022-04-01T10:00:00.000Z'));
      expect(pet.updatedAt, DateTime.parse('2024-01-10T08:30:00.000Z'));
    });

    test('fromJson nullable 필드 모두 null 처리', () {
      final json = {
        'id': 'pet-002',
        'user_id': 'user-abc',
        'name': '미미',
        'species': 'cat',
        'breed': null,
        'birth_date': null,
        'gender': null,
        'growth_stage': null,
        'weight': null,
        'adoption_date': null,
        'profile_image_url': null,
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-01T00:00:00.000Z',
      };

      final pet = Pet.fromJson(json);

      expect(pet.breed, isNull);
      expect(pet.breedId, isNull);
      expect(pet.birthDate, isNull);
      expect(pet.gender, isNull);
      expect(pet.growthStage, isNull);
      expect(pet.weight, isNull);
      expect(pet.adoptionDate, isNull);
      expect(pet.profileImageUrl, isNull);
    });

    test('fromJson is_active 키 없으면 기본값 true', () {
      final json = {
        'id': 'pet-003',
        'user_id': 'user-abc',
        'name': '두부',
        'species': 'dog',
        'created_at': '2023-06-01T00:00:00.000Z',
        'updated_at': '2023-06-01T00:00:00.000Z',
      };

      final pet = Pet.fromJson(json);

      expect(pet.isActive, isTrue);
    });

    test('fromJson num → double 변환 (정수 입력)', () {
      final json = {
        ...fullJson(),
        'weight': 36, // int 타입으로 전달
      };

      final pet = Pet.fromJson(json);

      expect(pet.weight, 36.0);
      expect(pet.weight, isA<double>());
    });

    test('toJson → fromJson 왕복 변환', () {
      final original = Pet.fromJson(fullJson());
      final restored = Pet.fromJson({
        ...original.toJson(),
        'created_at': original.createdAt.toIso8601String(),
        'updated_at': original.updatedAt.toIso8601String(),
      });

      expect(restored.id, original.id);
      expect(restored.userId, original.userId);
      expect(restored.name, original.name);
      expect(restored.species, original.species);
      expect(restored.breed, original.breed);
      expect(restored.breedId, original.breedId);
      expect(restored.birthDate, original.birthDate);
      expect(restored.gender, original.gender);
      expect(restored.growthStage, original.growthStage);
      expect(restored.weight, original.weight);
      expect(restored.adoptionDate, original.adoptionDate);
      expect(restored.profileImageUrl, original.profileImageUrl);
      expect(restored.isActive, original.isActive);
    });

    test('toJson 날짜는 날짜 부분(yyyy-MM-dd)만 직렬화', () {
      final pet = Pet.fromJson(fullJson());
      final json = pet.toJson();

      expect(json['birth_date'], '2022-03-15');
      expect(json['adoption_date'], '2022-04-01');
      // created_at / updated_at 은 toJson 미포함
      expect(json.containsKey('created_at'), isFalse);
      expect(json.containsKey('updated_at'), isFalse);
    });

    test('toJson nullable null 필드는 null 값으로 직렬화, optional null 필드는 미포함', () {
      final json = {
        'id': 'pet-004',
        'user_id': 'user-abc',
        'name': '루나',
        'species': 'cat',
        'breed': null,
        'birth_date': null,
        'gender': null,
        'growth_stage': null,
        'weight': null,
        'adoption_date': null,
        'profile_image_url': null,
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-01T00:00:00.000Z',
      };

      final pet = Pet.fromJson(json);
      final out = pet.toJson();

      // breed_id null이면 키 자체 미포함 (if 조건)
      expect(out.containsKey('breed_id'), isFalse);
      // weight null이면 키 자체 미포함 (if 조건)
      expect(out.containsKey('weight'), isFalse);
      // breed는 키 존재, 값 null
      expect(out['breed'], isNull);
    });

    test('toInsertJson id / created_at / updated_at 미포함', () {
      final pet = Pet.fromJson(fullJson());
      final insert = pet.toInsertJson();

      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('created_at'), isFalse);
      expect(insert.containsKey('updated_at'), isFalse);
      expect(insert['user_id'], 'user-abc');
      expect(insert['name'], '코코');
      expect(insert['species'], 'budgerigar');
    });

    test('toInsertJson nullable 없으면 해당 키 미포함', () {
      final json = {
        'id': 'pet-005',
        'user_id': 'user-abc',
        'name': '하늘',
        'species': 'bird',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-01T00:00:00.000Z',
      };

      final pet = Pet.fromJson(json);
      final insert = pet.toInsertJson();

      expect(insert.containsKey('breed'), isFalse);
      expect(insert.containsKey('breed_id'), isFalse);
      expect(insert.containsKey('birth_date'), isFalse);
      expect(insert.containsKey('gender'), isFalse);
      expect(insert.containsKey('growth_stage'), isFalse);
      expect(insert.containsKey('weight'), isFalse);
      expect(insert.containsKey('adoption_date'), isFalse);
      expect(insert.containsKey('profile_image_url'), isFalse);
      expect(insert['is_active'], isTrue);
    });

    test('copyWith 특정 필드만 변경, 나머지 유지', () {
      final original = Pet.fromJson(fullJson());
      final modified = original.copyWith(name: '새이름', weight: 40.0);

      expect(modified.name, '새이름');
      expect(modified.weight, 40.0);
      // 변경되지 않은 필드 유지
      expect(modified.id, original.id);
      expect(modified.userId, original.userId);
      expect(modified.species, original.species);
      expect(modified.breed, original.breed);
      expect(modified.isActive, original.isActive);
    });

    test('copyWith 인수 없이 호출하면 동일 값 반환', () {
      final original = Pet.fromJson(fullJson());
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.weight, original.weight);
    });

    test('equality id 기반 동등성 비교', () {
      final a = Pet.fromJson(fullJson());
      final b = Pet.fromJson({...fullJson(), 'name': '다른이름'});
      final c = Pet.fromJson({...fullJson(), 'id': 'pet-999'});

      expect(a, equals(b)); // id 같으면 동일
      expect(a, isNot(equals(c))); // id 다르면 다름
    });
  });

  // ---------------------------------------------------------------------------
  // WeightRecord
  // ---------------------------------------------------------------------------
  group('WeightRecord', () {
    Map<String, dynamic> fullJson() => {
          'id': 'wr-001',
          'pet_id': 'pet-001',
          'recorded_date': '2024-05-10',
          'weight': 34.2,
          'memo': '건강 체크 후',
          'recorded_hour': 9,
          'recorded_minute': 30,
          'created_at': '2024-05-10T09:30:00.000Z',
          'updated_at': '2024-05-10T09:30:00.000Z',
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final record = WeightRecord.fromJson(fullJson());

      expect(record.id, 'wr-001');
      expect(record.petId, 'pet-001');
      expect(record.date, DateTime(2024, 5, 10));
      expect(record.weight, 34.2);
      expect(record.weight, isA<double>());
      expect(record.memo, '건강 체크 후');
      expect(record.recordedHour, 9);
      expect(record.recordedMinute, 30);
      expect(record.createdAt, DateTime.parse('2024-05-10T09:30:00.000Z'));
      expect(record.updatedAt, DateTime.parse('2024-05-10T09:30:00.000Z'));
    });

    test('fromJson nullable 필드 null 처리', () {
      final json = {
        'pet_id': 'pet-001',
        'recorded_date': '2024-06-01',
        'weight': 35.0,
      };

      final record = WeightRecord.fromJson(json);

      expect(record.id, isNull);
      expect(record.memo, isNull);
      expect(record.recordedHour, isNull);
      expect(record.recordedMinute, isNull);
      expect(record.createdAt, isNull);
      expect(record.updatedAt, isNull);
    });

    test('fromJson num → double 변환 (정수 입력)', () {
      final json = {
        'pet_id': 'pet-001',
        'recorded_date': '2024-06-01',
        'weight': 35, // int
      };

      final record = WeightRecord.fromJson(json);

      expect(record.weight, 35.0);
      expect(record.weight, isA<double>());
    });

    test('toJson id 있을 때 포함, null이면 미포함', () {
      final withId = WeightRecord.fromJson(fullJson());
      final withoutId = WeightRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-06-01',
        'weight': 35.0,
      });

      expect(withId.toJson().containsKey('id'), isTrue);
      expect(withoutId.toJson().containsKey('id'), isFalse);
    });

    test('toJson memo / recorded_hour / recorded_minute 조건부 포함', () {
      final record = WeightRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-06-01',
        'weight': 35.0,
      });

      final json = record.toJson();

      expect(json.containsKey('memo'), isFalse);
      expect(json.containsKey('recorded_hour'), isFalse);
      expect(json.containsKey('recorded_minute'), isFalse);
      expect(json['pet_id'], 'pet-001');
      expect(json['recorded_date'], '2024-06-01');
      expect(json['weight'], 35.0);
    });

    test('toJson → fromJson 왕복 변환', () {
      final original = WeightRecord.fromJson(fullJson());
      final restored = WeightRecord.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.petId, original.petId);
      expect(restored.date, original.date);
      expect(restored.weight, original.weight);
      expect(restored.memo, original.memo);
      expect(restored.recordedHour, original.recordedHour);
      expect(restored.recordedMinute, original.recordedMinute);
    });

    test('toInsertJson id 미포함, 나머지 동일', () {
      final record = WeightRecord.fromJson(fullJson());
      final insert = record.toInsertJson();

      expect(insert.containsKey('id'), isFalse);
      expect(insert['pet_id'], 'pet-001');
      expect(insert['recorded_date'], '2024-05-10');
      expect(insert['weight'], 34.2);
      expect(insert['memo'], '건강 체크 후');
      expect(insert['recorded_hour'], 9);
      expect(insert['recorded_minute'], 30);
    });

    test('toInsertJson null 옵션 필드 미포함', () {
      final record = WeightRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-06-01',
        'weight': 35.0,
      });
      final insert = record.toInsertJson();

      expect(insert.containsKey('memo'), isFalse);
      expect(insert.containsKey('recorded_hour'), isFalse);
      expect(insert.containsKey('recorded_minute'), isFalse);
    });

    test('hasTime hour와 minute 모두 있으면 true', () {
      final record = WeightRecord.fromJson(fullJson());
      expect(record.hasTime, isTrue);
    });

    test('hasTime hour만 있으면 false', () {
      final record = WeightRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-06-01',
        'weight': 35.0,
        'recorded_hour': 9,
        // recorded_minute 없음 → null
      });
      expect(record.hasTime, isFalse);
    });

    test('hasTime 둘 다 null이면 false', () {
      final record = WeightRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-06-01',
        'weight': 35.0,
      });
      expect(record.hasTime, isFalse);
    });

    test('copyWith 특정 필드만 변경', () {
      final original = WeightRecord.fromJson(fullJson());
      final modified = original.copyWith(weight: 36.0, memo: '수정됨');

      expect(modified.weight, 36.0);
      expect(modified.memo, '수정됨');
      expect(modified.id, original.id);
      expect(modified.petId, original.petId);
      expect(modified.date, original.date);
      expect(modified.recordedHour, original.recordedHour);
    });
  });

  // ---------------------------------------------------------------------------
  // FoodRecord
  // ---------------------------------------------------------------------------
  group('FoodRecord', () {
    Map<String, dynamic> fullJson() => {
          'id': 'fr-001',
          'pet_id': 'pet-001',
          'recorded_date': '2024-05-10',
          'total_grams': 18.5,
          'target_grams': 20.0,
          'count': 3,
          'entries_json': '[{"foodName":"펠렛","grams":10}]',
          'created_at': '2024-05-10T08:00:00.000Z',
          'updated_at': '2024-05-10T18:00:00.000Z',
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final record = FoodRecord.fromJson(fullJson());

      expect(record.id, 'fr-001');
      expect(record.petId, 'pet-001');
      expect(record.recordedDate, DateTime(2024, 5, 10));
      expect(record.totalGrams, 18.5);
      expect(record.totalGrams, isA<double>());
      expect(record.targetGrams, 20.0);
      expect(record.targetGrams, isA<double>());
      expect(record.count, 3);
      expect(record.entriesJson, '[{"foodName":"펠렛","grams":10}]');
      expect(record.createdAt, DateTime.parse('2024-05-10T08:00:00.000Z'));
      expect(record.updatedAt, DateTime.parse('2024-05-10T18:00:00.000Z'));
    });

    test('fromJson entries_json null 처리', () {
      final json = {
        ...fullJson(),
        'entries_json': null,
      };

      final record = FoodRecord.fromJson(json);

      expect(record.entriesJson, isNull);
    });

    test('fromJson num → double 변환 (정수 입력)', () {
      final json = {
        ...fullJson(),
        'total_grams': 18,
        'target_grams': 20,
      };

      final record = FoodRecord.fromJson(json);

      expect(record.totalGrams, 18.0);
      expect(record.targetGrams, 20.0);
      expect(record.totalGrams, isA<double>());
    });

    test('toCreateJson id / petId / timestamps 미포함', () {
      final record = FoodRecord.fromJson(fullJson());
      final create = record.toCreateJson();

      expect(create.containsKey('id'), isFalse);
      expect(create.containsKey('pet_id'), isFalse);
      expect(create.containsKey('created_at'), isFalse);
      expect(create.containsKey('updated_at'), isFalse);
      expect(create['recorded_date'], '2024-05-10');
      expect(create['total_grams'], 18.5);
      expect(create['target_grams'], 20.0);
      expect(create['count'], 3);
      expect(create['entries_json'], '[{"foodName":"펠렛","grams":10}]');
    });

    test('toCreateJson entries_json null이면 키 미포함', () {
      final json = {...fullJson(), 'entries_json': null};
      final record = FoodRecord.fromJson(json);
      final create = record.toCreateJson();

      expect(create.containsKey('entries_json'), isFalse);
    });

    test('copyWith 특정 필드만 변경', () {
      final original = FoodRecord.fromJson(fullJson());
      final modified = original.copyWith(totalGrams: 22.0, count: 4);

      expect(modified.totalGrams, 22.0);
      expect(modified.count, 4);
      expect(modified.id, original.id);
      expect(modified.petId, original.petId);
      expect(modified.targetGrams, original.targetGrams);
      expect(modified.entriesJson, original.entriesJson);
    });

    test('equality id 기반 동등성 비교', () {
      final a = FoodRecord.fromJson(fullJson());
      final b = FoodRecord.fromJson({...fullJson(), 'total_grams': 99.0});
      final c = FoodRecord.fromJson({...fullJson(), 'id': 'fr-999'});

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // WaterIntakeRecord
  // ---------------------------------------------------------------------------
  group('WaterIntakeRecord', () {
    Map<String, dynamic> fullJson() => {
          'id': 'wi-001',
          'pet_id': 'pet-001',
          'recorded_date': '2024-05-10',
          'total_ml': 45.0,
          'target_ml': 60.0,
          'count': 5,
          'created_at': '2024-05-10T08:00:00.000Z',
          'updated_at': '2024-05-10T18:00:00.000Z',
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final record = WaterIntakeRecord.fromJson(fullJson());

      expect(record.id, 'wi-001');
      expect(record.petId, 'pet-001');
      expect(record.recordedDate, DateTime(2024, 5, 10));
      expect(record.totalMl, 45.0);
      expect(record.totalMl, isA<double>());
      expect(record.targetMl, 60.0);
      expect(record.targetMl, isA<double>());
      expect(record.count, 5);
      expect(record.createdAt, DateTime.parse('2024-05-10T08:00:00.000Z'));
      expect(record.updatedAt, DateTime.parse('2024-05-10T18:00:00.000Z'));
    });

    test('fromJson num → double 변환 (정수 입력)', () {
      final json = {
        ...fullJson(),
        'total_ml': 45,
        'target_ml': 60,
      };

      final record = WaterIntakeRecord.fromJson(json);

      expect(record.totalMl, 45.0);
      expect(record.targetMl, 60.0);
      expect(record.totalMl, isA<double>());
    });

    test('toCreateJson id / petId / timestamps 미포함', () {
      final record = WaterIntakeRecord.fromJson(fullJson());
      final create = record.toCreateJson();

      expect(create.containsKey('id'), isFalse);
      expect(create.containsKey('pet_id'), isFalse);
      expect(create.containsKey('created_at'), isFalse);
      expect(create.containsKey('updated_at'), isFalse);
      expect(create['recorded_date'], '2024-05-10');
      expect(create['total_ml'], 45.0);
      expect(create['target_ml'], 60.0);
      expect(create['count'], 5);
    });

    test('toCreateJson → fromJson 왕복 변환 (날짜 일치)', () {
      final original = WaterIntakeRecord.fromJson(fullJson());
      final create = original.toCreateJson();

      // toCreateJson은 pet_id, id, timestamps 없으므로 수동으로 보충
      final restored = WaterIntakeRecord.fromJson({
        'id': original.id,
        'pet_id': original.petId,
        'created_at': original.createdAt.toIso8601String(),
        'updated_at': original.updatedAt.toIso8601String(),
        ...create,
      });

      expect(restored.totalMl, original.totalMl);
      expect(restored.targetMl, original.targetMl);
      expect(restored.count, original.count);
      expect(restored.recordedDate, original.recordedDate);
    });

    test('copyWith 특정 필드만 변경', () {
      final original = WaterIntakeRecord.fromJson(fullJson());
      final modified = original.copyWith(totalMl: 55.0, count: 6);

      expect(modified.totalMl, 55.0);
      expect(modified.count, 6);
      expect(modified.id, original.id);
      expect(modified.petId, original.petId);
      expect(modified.targetMl, original.targetMl);
    });

    test('equality id 기반 동등성 비교', () {
      final a = WaterIntakeRecord.fromJson(fullJson());
      final b = WaterIntakeRecord.fromJson({...fullJson(), 'total_ml': 99.0});
      final c = WaterIntakeRecord.fromJson({...fullJson(), 'id': 'wi-999'});

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // DailyRecord
  // ---------------------------------------------------------------------------
  group('DailyRecord', () {
    Map<String, dynamic> fullJson() => {
          'id': 'dr-001',
          'pet_id': 'pet-001',
          'recorded_date': '2024-05-10',
          'notes': '오늘 컨디션 좋음',
          'mood': 'great',
          'activity_level': 4,
          'created_at': '2024-05-10T09:00:00.000Z',
          'updated_at': '2024-05-10T21:00:00.000Z',
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final record = DailyRecord.fromJson(fullJson());

      expect(record.id, 'dr-001');
      expect(record.petId, 'pet-001');
      expect(record.recordedDate, DateTime(2024, 5, 10));
      expect(record.notes, '오늘 컨디션 좋음');
      expect(record.mood, 'great');
      expect(record.activityLevel, 4);
      expect(record.createdAt, DateTime.parse('2024-05-10T09:00:00.000Z'));
      expect(record.updatedAt, DateTime.parse('2024-05-10T21:00:00.000Z'));
    });

    test('fromJson nullable 필드 null 처리', () {
      final json = {
        'pet_id': 'pet-001',
        'recorded_date': '2024-05-10',
      };

      final record = DailyRecord.fromJson(json);

      expect(record.id, isNull);
      expect(record.notes, isNull);
      expect(record.mood, isNull);
      expect(record.activityLevel, isNull);
      expect(record.createdAt, isNull);
      expect(record.updatedAt, isNull);
    });

    test('toJson id 있을 때 포함, null이면 미포함', () {
      final withId = DailyRecord.fromJson(fullJson());
      final withoutId = DailyRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-05-10',
      });

      expect(withId.toJson().containsKey('id'), isTrue);
      expect(withoutId.toJson().containsKey('id'), isFalse);
    });

    test('toJson 조건부 필드 notes/mood/activity_level null이면 미포함', () {
      final record = DailyRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-05-10',
      });

      final json = record.toJson();

      expect(json.containsKey('notes'), isFalse);
      expect(json.containsKey('mood'), isFalse);
      expect(json.containsKey('activity_level'), isFalse);
      expect(json['pet_id'], 'pet-001');
      expect(json['recorded_date'], '2024-05-10');
    });

    test('toJson → fromJson 왕복 변환', () {
      final original = DailyRecord.fromJson(fullJson());
      final restored = DailyRecord.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.petId, original.petId);
      expect(restored.recordedDate, original.recordedDate);
      expect(restored.notes, original.notes);
      expect(restored.mood, original.mood);
      expect(restored.activityLevel, original.activityLevel);
    });

    test('toInsertJson pet_id 포함, id 미포함', () {
      final record = DailyRecord.fromJson(fullJson());
      final insert = record.toInsertJson();

      expect(insert.containsKey('id'), isFalse);
      expect(insert['pet_id'], 'pet-001');
      expect(insert['recorded_date'], '2024-05-10');
      expect(insert['notes'], '오늘 컨디션 좋음');
      expect(insert['mood'], 'great');
      expect(insert['activity_level'], 4);
    });

    test('toInsertJson null 옵션 필드 미포함', () {
      final record = DailyRecord.fromJson({
        'pet_id': 'pet-001',
        'recorded_date': '2024-05-10',
      });
      final insert = record.toInsertJson();

      expect(insert.containsKey('notes'), isFalse);
      expect(insert.containsKey('mood'), isFalse);
      expect(insert.containsKey('activity_level'), isFalse);
    });

    test('copyWith 특정 필드만 변경', () {
      final original = DailyRecord.fromJson(fullJson());
      final modified = original.copyWith(mood: 'bad', activityLevel: 2);

      expect(modified.mood, 'bad');
      expect(modified.activityLevel, 2);
      expect(modified.id, original.id);
      expect(modified.petId, original.petId);
      expect(modified.notes, original.notes);
    });

    test('Mood.fromValue 정상 파싱', () {
      expect(Mood.fromValue('great'), Mood.great);
      expect(Mood.fromValue('good'), Mood.good);
      expect(Mood.fromValue('normal'), Mood.normal);
      expect(Mood.fromValue('bad'), Mood.bad);
      expect(Mood.fromValue('sick'), Mood.sick);
    });

    test('Mood.fromValue null 입력 시 null 반환', () {
      expect(Mood.fromValue(null), isNull);
    });

    test('Mood.fromValue 알 수 없는 값은 normal fallback', () {
      expect(Mood.fromValue('unknown_value'), Mood.normal);
    });

    test('equality id 기반 동등성 비교', () {
      final a = DailyRecord.fromJson(fullJson());
      final b = DailyRecord.fromJson({...fullJson(), 'mood': 'bad'});
      final c = DailyRecord.fromJson({...fullJson(), 'id': 'dr-999'});

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // ScheduleRecord
  // ---------------------------------------------------------------------------
  group('ScheduleRecord', () {
    Map<String, dynamic> fullJson() => {
          'id': 'sr-001',
          'pet_id': 'pet-001',
          'start_time': '2024-05-10T09:00:00.000',
          'end_time': '2024-05-10T10:00:00.000',
          'title': '병원 방문',
          'description': '정기 건강 검진',
          'color': '#FF9A42',
          'reminder_minutes': 30,
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final record = ScheduleRecord.fromJson(fullJson());

      expect(record.id, 'sr-001');
      expect(record.petId, 'pet-001');
      expect(record.startTime, DateTime(2024, 5, 10, 9, 0, 0));
      expect(record.endTime, DateTime(2024, 5, 10, 10, 0, 0));
      expect(record.title, '병원 방문');
      expect(record.description, '정기 건강 검진');
      expect(record.color, const Color(0xFFFF9A42));
      expect(record.reminderMinutes, 30);
    });

    test('fromJson description / reminderMinutes null 처리', () {
      final json = {
        'id': 'sr-002',
        'pet_id': 'pet-001',
        'start_time': '2024-05-10T09:00:00.000',
        'end_time': '2024-05-10T10:00:00.000',
        'title': '산책',
        'color': '#6BCB77',
      };

      final record = ScheduleRecord.fromJson(json);

      expect(record.description, isNull);
      expect(record.reminderMinutes, isNull);
    });

    test('fromJson color 키 없을 때 브랜드 색상(#FF9A42) 기본값 사용', () {
      final json = {
        'id': 'sr-003',
        'pet_id': 'pet-001',
        'start_time': '2024-05-10T09:00:00.000',
        'end_time': '2024-05-10T10:00:00.000',
        'title': '식사',
      };

      final record = ScheduleRecord.fromJson(json);

      expect(record.color, const Color(0xFFFF9A42));
    });

    test('colorHex 정상 변환', () {
      final record = ScheduleRecord.fromJson(fullJson());
      expect(record.colorHex, '#FF9A42');
    });

    test('colorFromHex # 포함/미포함 모두 동일 Color 반환', () {
      final withHash = ScheduleRecord.colorFromHex('#FF9A42');
      final withoutHash = ScheduleRecord.colorFromHex('FF9A42');

      expect(withHash, const Color(0xFFFF9A42));
      expect(withoutHash, const Color(0xFFFF9A42));
    });

    test('toJson → fromJson 왕복 변환', () {
      final original = ScheduleRecord.fromJson(fullJson());
      final restored = ScheduleRecord.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.petId, original.petId);
      expect(restored.startTime, original.startTime);
      expect(restored.endTime, original.endTime);
      expect(restored.title, original.title);
      expect(restored.description, original.description);
      expect(restored.color, original.color);
      expect(restored.reminderMinutes, original.reminderMinutes);
    });

    test('toInsertJson id / pet_id 미포함', () {
      final record = ScheduleRecord.fromJson(fullJson());
      final insert = record.toInsertJson();

      expect(insert.containsKey('id'), isFalse);
      expect(insert.containsKey('pet_id'), isFalse);
      expect(insert['start_time'], isNotNull);
      expect(insert['end_time'], isNotNull);
      expect(insert['title'], '병원 방문');
      expect(insert['description'], '정기 건강 검진');
      expect(insert['color'], '#FF9A42');
      expect(insert['reminder_minutes'], 30);
    });

    test('copyWith 특정 필드만 변경', () {
      final original = ScheduleRecord.fromJson(fullJson());
      final modified = original.copyWith(
        title: '목욕',
        reminderMinutes: 15,
        color: const Color(0xFF4D96FF),
      );

      expect(modified.title, '목욕');
      expect(modified.reminderMinutes, 15);
      expect(modified.color, const Color(0xFF4D96FF));
      expect(modified.id, original.id);
      expect(modified.petId, original.petId);
      expect(modified.startTime, original.startTime);
    });

    test('id 미전달 시 자동 생성 (타임스탬프 기반)', () {
      final record = ScheduleRecord(
        petId: 'pet-001',
        startTime: DateTime(2024, 5, 10, 9),
        endTime: DateTime(2024, 5, 10, 10),
        title: '자동 ID 테스트',
        color: const Color(0xFFFF9A42),
      );

      expect(record.id, isNotEmpty);
      expect(int.tryParse(record.id), isNotNull); // 숫자 문자열
    });

    test('formattedStartTime 오전 9:00', () {
      final record = ScheduleRecord.fromJson(fullJson());
      expect(record.formattedStartTime, '오전 09:00');
    });

    test('formattedEndTime 오전 10:00', () {
      final record = ScheduleRecord.fromJson(fullJson());
      expect(record.formattedEndTime, '오전 10:00');
    });

    test('formattedStartTime 오후 2:30 (hour=14)', () {
      final record = ScheduleRecord.fromJson({
        ...fullJson(),
        'start_time': '2024-05-10T14:30:00.000',
      });
      expect(record.formattedStartTime, '오후 02:30');
    });
  });

  // ---------------------------------------------------------------------------
  // BreedStandard & WeightRangeInfo
  // ---------------------------------------------------------------------------
  group('BreedStandard', () {
    Map<String, dynamic> fullJson() => {
          'id': 'bs-001',
          'display_name': '왕관앵무',
          'species_category': 'cockatiel',
          'breed_variant': null,
          'weight_min_g': 70.0,
          'weight_ideal_min_g': 80.0,
          'weight_ideal_max_g': 100.0,
          'weight_max_g': 120.0,
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final standard = BreedStandard.fromJson(fullJson());

      expect(standard.id, 'bs-001');
      expect(standard.displayName, '왕관앵무');
      expect(standard.speciesCategory, 'cockatiel');
      expect(standard.breedVariant, isNull);
      expect(standard.weightMinG, 70.0);
      expect(standard.weightMinG, isA<double>());
      expect(standard.weightIdealMinG, 80.0);
      expect(standard.weightIdealMaxG, 100.0);
      expect(standard.weightMaxG, 120.0);
    });

    test('fromJson breed_variant 있을 때 파싱', () {
      final json = {
        ...fullJson(),
        'breed_variant': 'Normal',
      };

      final standard = BreedStandard.fromJson(json);

      expect(standard.breedVariant, 'Normal');
    });

    test('fromJson num → double 변환 (정수 입력)', () {
      final json = {
        ...fullJson(),
        'weight_min_g': 70,
        'weight_ideal_min_g': 80,
        'weight_ideal_max_g': 100,
        'weight_max_g': 120,
      };

      final standard = BreedStandard.fromJson(json);

      expect(standard.weightMinG, 70.0);
      expect(standard.weightIdealMinG, 80.0);
      expect(standard.weightIdealMaxG, 100.0);
      expect(standard.weightMaxG, 120.0);
      expect(standard.weightMinG, isA<double>());
    });

    test('idealRangeText 형식 검증', () {
      final standard = BreedStandard.fromJson(fullJson());
      expect(standard.idealRangeText, '80g - 100g');
    });

    test('fullRangeText 형식 검증', () {
      final standard = BreedStandard.fromJson(fullJson());
      expect(standard.fullRangeText, '70g - 120g');
    });

    test('idealRangeText 소수점이 있으면 반올림 없이 정수로 표시', () {
      final json = {
        ...fullJson(),
        'weight_ideal_min_g': 85.0,
        'weight_ideal_max_g': 95.0,
      };

      final standard = BreedStandard.fromJson(json);

      expect(standard.idealRangeText, '85g - 95g');
    });
  });

  group('WeightRangeInfo', () {
    Map<String, dynamic> fullJson() => {
          'min_g': 70.0,
          'ideal_min_g': 80.0,
          'ideal_max_g': 100.0,
          'max_g': 120.0,
          'current_position': 'in_ideal',
          'current_percentage': 55.0,
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final info = WeightRangeInfo.fromJson(fullJson());

      expect(info.minG, 70.0);
      expect(info.minG, isA<double>());
      expect(info.idealMinG, 80.0);
      expect(info.idealMaxG, 100.0);
      expect(info.maxG, 120.0);
      expect(info.currentPosition, 'in_ideal');
      expect(info.currentPercentage, 55.0);
      expect(info.currentPercentage, isA<double>());
    });

    test('fromJson currentPosition 다양한 값 파싱', () {
      for (final position in [
        'below_min',
        'below_ideal',
        'in_ideal',
        'above_ideal',
        'above_max',
      ]) {
        final json = {...fullJson(), 'current_position': position};
        final info = WeightRangeInfo.fromJson(json);
        expect(info.currentPosition, position);
      }
    });

    test('fromJson num → double 변환 (정수 입력)', () {
      final json = {
        'min_g': 70,
        'ideal_min_g': 80,
        'ideal_max_g': 100,
        'max_g': 120,
        'current_position': 'in_ideal',
        'current_percentage': 55,
      };

      final info = WeightRangeInfo.fromJson(json);

      expect(info.minG, 70.0);
      expect(info.currentPercentage, 55.0);
      expect(info.minG, isA<double>());
    });
  });

  // ---------------------------------------------------------------------------
  // HealthSummary
  // ---------------------------------------------------------------------------
  group('HealthSummary', () {
    Map<String, dynamic> fullJson() => {
          'bhi_score': 82.5,
          'wci_level': 3,
          'weight_current': 35.0,
          'weight_change_percent': -1.5,
          'weight_trend': 'down',
          'has_data': true,
          'target_date': '2024-05-10',
          'abnormal_count': 2,
          'food_consistency': 0.87,
          'water_consistency': 0.92,
          'bhi_trend': 'improving',
          'bhi_previous': 79.0,
        };

    test('fromJson 전체 필드 정상 파싱', () {
      final summary = HealthSummary.fromJson(fullJson());

      expect(summary.bhiScore, 82.5);
      expect(summary.bhiScore, isA<double>());
      expect(summary.wciLevel, 3);
      expect(summary.weightCurrent, 35.0);
      expect(summary.weightCurrent, isA<double>());
      expect(summary.weightChangePercent, -1.5);
      expect(summary.weightTrend, 'down');
      expect(summary.hasData, isTrue);
      expect(summary.targetDate, DateTime(2024, 5, 10));
      expect(summary.abnormalCount, 2);
      expect(summary.foodConsistency, 0.87);
      expect(summary.waterConsistency, 0.92);
      expect(summary.bhiTrend, 'improving');
      expect(summary.bhiPrevious, 79.0);
    });

    test('fromJson nullable Premium 필드 null 처리', () {
      final json = {
        'wci_level': 1,
        'weight_trend': 'stable',
        'has_data': false,
        'target_date': '2024-05-10',
      };

      final summary = HealthSummary.fromJson(json);

      expect(summary.bhiScore, isNull);
      expect(summary.weightCurrent, isNull);
      expect(summary.weightChangePercent, isNull);
      expect(summary.abnormalCount, isNull);
      expect(summary.foodConsistency, isNull);
      expect(summary.waterConsistency, isNull);
      expect(summary.bhiTrend, isNull);
      expect(summary.bhiPrevious, isNull);
    });

    test('fromJson wci_level 키 없으면 기본값 0', () {
      final json = {
        'weight_trend': 'stable',
        'has_data': false,
        'target_date': '2024-05-10',
      };

      final summary = HealthSummary.fromJson(json);

      expect(summary.wciLevel, 0);
    });

    test('fromJson weight_trend 키 없으면 기본값 stable', () {
      final json = {
        'wci_level': 2,
        'has_data': true,
        'target_date': '2024-05-10',
      };

      final summary = HealthSummary.fromJson(json);

      expect(summary.weightTrend, 'stable');
    });

    test('fromJson has_data 키 없으면 기본값 false', () {
      final json = {
        'wci_level': 0,
        'weight_trend': 'stable',
        'target_date': '2024-05-10',
      };

      final summary = HealthSummary.fromJson(json);

      expect(summary.hasData, isFalse);
    });

    test('fromJson num → double 변환 (정수 입력)', () {
      final json = {
        ...fullJson(),
        'bhi_score': 82,
        'weight_current': 35,
        'weight_change_percent': -1,
        'food_consistency': 1,
        'water_consistency': 1,
        'bhi_previous': 79,
      };

      final summary = HealthSummary.fromJson(json);

      expect(summary.bhiScore, 82.0);
      expect(summary.weightCurrent, 35.0);
      expect(summary.weightChangePercent, -1.0);
      expect(summary.foodConsistency, 1.0);
      expect(summary.waterConsistency, 1.0);
      expect(summary.bhiPrevious, 79.0);
      expect(summary.bhiScore, isA<double>());
    });

    test('fromJson weightTrend up/down/stable 각각 파싱', () {
      for (final trend in ['up', 'down', 'stable']) {
        final json = {
          ...fullJson(),
          'weight_trend': trend,
        };
        final summary = HealthSummary.fromJson(json);
        expect(summary.weightTrend, trend);
      }
    });

    test('fromJson bhiTrend improving/declining/stable 각각 파싱', () {
      for (final trend in ['improving', 'declining', 'stable']) {
        final json = {
          ...fullJson(),
          'bhi_trend': trend,
        };
        final summary = HealthSummary.fromJson(json);
        expect(summary.bhiTrend, trend);
      }
    });
  });
}
