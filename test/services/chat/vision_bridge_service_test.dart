import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/services/chat/vision_bridge_service.dart';
import 'package:perch_care/src/services/health_check/health_check_service.dart';

class _MockHealthCheckService extends Mock implements HealthCheckService {}

void main() {
  late _MockHealthCheckService mockService;
  late VisionBridgeService bridge;

  final Uint8List bytes = Uint8List.fromList([1, 2, 3]);
  const String fileName = 'photo.jpg';

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    mockService = _MockHealthCheckService();
    bridge = VisionBridgeService.forTest(mockService);
  });

  Future<VisionBridgeResult> analyze({String? userText}) {
    return bridge.analyze(
      imageBytes: bytes,
      fileName: fileName,
      userText: userText,
    );
  }

  void stubSuccess(Map<String, dynamic> raw) {
    when(() => mockService.analyzeFood(
          imageBytes: any(named: 'imageBytes'),
          fileName: any(named: 'fileName'),
          notes: any(named: 'notes'),
          language: any(named: 'language'),
        )).thenAnswer((_) async => raw);
  }

  group('VisionBridgeService.analyze', () {
    test('성공 — 사용자 텍스트 + overall_status 요약 → augmented prompt 조립', () async {
      stubSuccess({
        'result': {
          'overall_status': '깃털이 건강해 보입니다.',
          'findings': [
            {'description': '큰 이상 없음'},
          ],
        },
        'confidence_score': 0.92,
        'status': 'normal',
      });

      final result = await analyze(userText: '이 앵무새 괜찮아?');

      expect(result.summary, contains('깃털이 건강해 보입니다.'));
      expect(result.summary, contains('• 큰 이상 없음'));
      expect(result.confidence, 0.92);
      expect(result.status, 'normal');
      expect(result.augmentedPrompt, contains('[첨부 이미지 분석]'));
      expect(result.augmentedPrompt, contains('깃털이 건강해 보입니다.'));
      expect(result.augmentedPrompt, contains('confidence 0.92'));
      expect(result.augmentedPrompt, contains('status normal'));
      expect(result.augmentedPrompt, contains('[사용자 질문]'));
      expect(result.augmentedPrompt, contains('이 앵무새 괜찮아?'));
    });

    test('성공 — 사용자 텍스트 없으면 [사용자 질문] 블록 생략', () async {
      stubSuccess({
        'result': {'overall_status': '정상'},
        'confidence_score': 0.8,
      });

      final result = await analyze(userText: null);

      expect(result.augmentedPrompt, contains('[첨부 이미지 분석]'));
      expect(result.augmentedPrompt, contains('정상'));
      expect(result.augmentedPrompt, isNot(contains('[사용자 질문]')));
    });

    test('성공 — 공백만 입력된 userText 는 주석 없음과 동일하게 처리', () async {
      stubSuccess({
        'result': {'overall_status': '정상'},
      });
      final result = await analyze(userText: '   ');
      expect(result.augmentedPrompt, isNot(contains('[사용자 질문]')));
    });

    test('음식 모드 — identified_items + nutrition_balance 포함', () async {
      stubSuccess({
        'result': {
          'overall_diet_assessment': '균형 잡힌 식단',
          'identified_items': [
            {'name': '펠렛'},
            {'name': '씨앗'},
          ],
          'nutrition_balance': '지방 과다 가능성',
        },
      });

      final result = await analyze(userText: '이 먹이 괜찮아?');

      expect(result.summary, contains('균형 잡힌 식단'));
      expect(result.summary, contains('식별: 펠렛, 씨앗'));
      expect(result.summary, contains('영양 균형: 지방 과다 가능성'));
    });

    test('결과가 빈 맵이면 fallback 요약 문구', () async {
      stubSuccess({'result': <String, dynamic>{}});
      final result = await analyze();
      expect(result.summary, '분석 결과 요약 없음');
    });

    test('result 필드가 없거나 타입이 이상하면 안전 폴백', () async {
      stubSuccess({'result': 'some-string', 'confidence_score': 0.5});
      final result = await analyze();
      expect(result.summary, '분석 결과를 읽을 수 없음');
    });

    test('findings 가 문자열 리스트여도 파싱', () async {
      stubSuccess({
        'result': {
          'findings': ['경미한 깃털 손실', '발바닥 붉어짐'],
        },
      });
      final result = await analyze();
      expect(result.summary, contains('• 경미한 깃털 손실'));
      expect(result.summary, contains('• 발바닥 붉어짐'));
    });

    test('findings 5개 초과 시 앞에서 5개만 포함', () async {
      stubSuccess({
        'result': {
          'findings': ['1', '2', '3', '4', '5', '6', '7'],
        },
      });
      final result = await analyze();
      expect(result.summary, contains('• 1'));
      expect(result.summary, contains('• 5'));
      expect(result.summary, isNot(contains('• 6')));
    });

    test('서비스 호출 실패 → VisionBridgeException 으로 감싸서 던짐', () async {
      when(() => mockService.analyzeFood(
            imageBytes: any(named: 'imageBytes'),
            fileName: any(named: 'fileName'),
            notes: any(named: 'notes'),
            language: any(named: 'language'),
          )).thenThrow(Exception('network'));

      expect(
        () => analyze(userText: 'test'),
        throwsA(isA<VisionBridgeException>()),
      );
    });

    test('notes 파라미터에 사용자 텍스트 전달 — trim 된 상태', () async {
      stubSuccess({
        'result': {'overall_status': '정상'},
      });

      await analyze(userText: '  사용자 질문  ');

      verify(() => mockService.analyzeFood(
            imageBytes: bytes,
            fileName: fileName,
            notes: '사용자 질문',
            language: null,
          )).called(1);
    });

    test('notes 파라미터 — userText 공백 / null 이면 null', () async {
      stubSuccess({
        'result': {'overall_status': '정상'},
      });

      await analyze(userText: '   ');

      verify(() => mockService.analyzeFood(
            imageBytes: bytes,
            fileName: fileName,
            notes: null,
            language: null,
          )).called(1);
    });
  });
}
