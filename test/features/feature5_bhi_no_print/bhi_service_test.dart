import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:perch_care/src/models/bhi_result.dart';

void main() {
  group('Feature 5: BHI 서비스 디버그 print 제거', () {
    test('5.1 bhi_service.dart에 print() 호출 없음 (회귀 방지)', () {
      final file = File('lib/src/services/bhi/bhi_service.dart');
      final content = file.readAsStringSync();
      final printMatches = RegExp(r'\bprint\s*\(').allMatches(content);
      expect(
        printMatches.length,
        0,
        reason: 'bhi_service.dart에 print() 호출이 남아있습니다. 프로덕션 코드에서 제거하세요.',
      );
    });

    test('5.2 bhi_service.dart에 debugPrint() 호출 없음', () {
      final file = File('lib/src/services/bhi/bhi_service.dart');
      final content = file.readAsStringSync();
      final debugPrintMatches =
          RegExp(r'\bdebugPrint\s*\(').allMatches(content);
      expect(
        debugPrintMatches.length,
        0,
        reason: 'bhi_service.dart에 debugPrint() 호출이 남아있습니다.',
      );
    });

    group('BhiResult.fromJson', () {
      test('5.3 필수 필드 정상 파싱', () {
        final json = {
          'bhi_score': 85.5,
          'weight_score': 90.0,
          'food_score': 80.0,
          'water_score': 75.0,
          'wci_level': 3,
          'target_date': '2026-02-27',
          'has_weight_data': true,
          'has_food_data': true,
          'has_water_data': false,
        };

        final result = BhiResult.fromJson(json);

        expect(result.bhiScore, 85.5);
        expect(result.weightScore, 90.0);
        expect(result.foodScore, 80.0);
        expect(result.waterScore, 75.0);
        expect(result.wciLevel, 3);
        expect(result.targetDate, DateTime(2026, 2, 27));
        expect(result.hasWeightData, isTrue);
        expect(result.hasFoodData, isTrue);
        expect(result.hasWaterData, isFalse);
      });

      test('5.4 선택 필드(debug) 정상 파싱', () {
        final json = {
          'bhi_score': 85.5,
          'weight_score': 90.0,
          'food_score': 80.0,
          'water_score': 75.0,
          'wci_level': 3,
          'target_date': '2026-02-27',
          'has_weight_data': true,
          'has_food_data': true,
          'has_water_data': true,
          'growth_stage': 'adult',
          'debug_food_total': 25.0,
          'debug_food_target': 30.0,
          'debug_water_total': 50.0,
          'debug_water_target': 60.0,
        };

        final result = BhiResult.fromJson(json);

        expect(result.growthStage, 'adult');
        expect(result.debugFoodTotal, 25.0);
        expect(result.debugFoodTarget, 30.0);
        expect(result.debugWaterTotal, 50.0);
        expect(result.debugWaterTarget, 60.0);
      });

      test('5.5 선택 필드 null일 때 정상 처리', () {
        final json = {
          'bhi_score': 50.0,
          'weight_score': 50.0,
          'food_score': 50.0,
          'water_score': 50.0,
          'wci_level': 1,
          'target_date': '2026-01-01',
          'has_weight_data': false,
          'has_food_data': false,
          'has_water_data': false,
        };

        final result = BhiResult.fromJson(json);

        expect(result.growthStage, isNull);
        expect(result.debugFoodTotal, isNull);
        expect(result.debugFoodTarget, isNull);
        expect(result.debugWaterTotal, isNull);
        expect(result.debugWaterTarget, isNull);
      });

      test('5.6 정수값을 double로 정상 변환 (num.toDouble)', () {
        final json = {
          'bhi_score': 85, // int, not double
          'weight_score': 90,
          'food_score': 80,
          'water_score': 75,
          'wci_level': 3,
          'target_date': '2026-02-27',
          'has_weight_data': true,
          'has_food_data': true,
          'has_water_data': true,
        };

        final result = BhiResult.fromJson(json);

        expect(result.bhiScore, 85.0);
        expect(result.bhiScore, isA<double>());
      });
    });
  });
}
