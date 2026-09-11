import 'package:flutter_test/flutter_test.dart';
import 'package:perch_care/src/services/analytics/analytics_service.dart';
import 'package:perch_care/src/services/firebase/firebase_init.dart';
import 'package:perch_care/src/services/push/push_notification_service.dart';

/// Firebase 초기화가 실패한 환경(지원하지 않는 플랫폼, 자격 파일 누락)에서
/// 앱이 계속 동작해야 한다 — 감사 F12.
///
/// 이 파일은 `Firebase.initializeApp()`을 호출하지 않으므로 실제로 초기화되지
/// 않은 상태다. `FirebaseAnalytics.instance` 등에 접근하면 예외가 발생한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => FirebaseInit.setAvailableForTest(value: false));

  test('초기화되지 않았으면 isAvailable이 false다', () {
    expect(FirebaseInit.isAvailable, isFalse);
  });

  test('ensureInitialized는 실패해도 예외를 전파하지 않는다', () async {
    // 테스트 환경에는 firebase_core 플랫폼 구현이 없으므로 초기화가 실패한다.
    await expectLater(FirebaseInit.ensureInitialized(), completes);
    expect(FirebaseInit.isAvailable, isFalse);
  });

  test('분석 관찰자는 빈 목록이라 라우터를 만들 수 있다', () {
    expect(AnalyticsService.instance.navigatorObservers, isEmpty);
  });

  test('이벤트 로깅은 예외 없이 no-op으로 완료된다', () async {
    final analytics = AnalyticsService.instance;
    await expectLater(analytics.logLogin('email'), completes);
    await expectLater(analytics.logSignUp('email'), completes);
    await expectLater(analytics.logPetRegistered('budgie'), completes);
    await expectLater(analytics.logFoodRecorded('pet-1', 2), completes);
    await expectLater(analytics.logWaterRecorded('pet-1'), completes);
    await expectLater(analytics.logAiChatSent(), completes);
    await expectLater(analytics.logBhiViewed('pet-1'), completes);
    await expectLater(analytics.logPetDeleted(), completes);
    await expectLater(analytics.logAccountDeleted(), completes);
  });

  test('푸시 초기화는 조용히 건너뛴다', () async {
    await expectLater(PushNotificationService.instance.initialize(), completes);
  });

  tearDownAll(() => FirebaseInit.setAvailableForTest(value: false));
}
