import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_init.dart';

/// 이벤트 로깅 + 인앱 리뷰 유도.
///
/// Firebase 초기화가 실패한 환경에서는 모든 로깅이 no-op이 된다. `.instance`
/// 접근 자체가 예외를 던지므로 필드로 보관하지 않고 매번 지연 조회한다.
/// 인앱 리뷰는 Firebase와 무관하므로 그대로 동작한다.
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  FirebaseAnalytics? get _analytics =>
      FirebaseInit.isAvailable ? FirebaseAnalytics.instance : null;
  final InAppReview _inAppReview = InAppReview.instance;

  /// 라우터에 넘길 관찰자. Firebase를 쓸 수 없으면 빈 목록이다.
  List<NavigatorObserver> get navigatorObservers {
    final analytics = _analytics;
    if (analytics == null) return const [];
    return [FirebaseAnalyticsObserver(analytics: analytics)];
  }

  // --- Core Events ---

  Future<void> logSignUp(String method) =>
      _analytics?.logSignUp(signUpMethod: method) ?? Future<void>.value();

  Future<void> logLogin(String method) =>
      _analytics?.logLogin(loginMethod: method) ?? Future<void>.value();

  Future<void> logPetRegistered(String species) =>
      _analytics?.logEvent(name: 'pet_registered', parameters: {'species': species})
          ?? Future<void>.value();

  Future<void> logWeightRecorded(String petId) async {
    await _analytics?.logEvent(name: 'weight_recorded', parameters: {'pet_id': petId});
    await _checkReviewPrompt();
  }

  Future<void> logFoodRecorded(String petId, int entryCount) =>
      _analytics?.logEvent(name: 'food_recorded', parameters: {
        'pet_id': petId,
        'entry_count': entryCount,
      }) ?? Future<void>.value();

  Future<void> logWaterRecorded(String petId) =>
      _analytics?.logEvent(name: 'water_recorded', parameters: {'pet_id': petId})
          ?? Future<void>.value();

  Future<void> logAiChatSent() =>
      _analytics?.logEvent(name: 'ai_chat_sent') ?? Future<void>.value();

  Future<void> logBhiViewed(String petId) =>
      _analytics?.logEvent(name: 'bhi_viewed', parameters: {'pet_id': petId})
          ?? Future<void>.value();

  Future<void> logPetDeleted() =>
      _analytics?.logEvent(name: 'pet_deleted') ?? Future<void>.value();

  Future<void> logAccountDeleted() =>
      _analytics?.logEvent(name: 'account_deleted') ?? Future<void>.value();

  // --- In-App Review ---

  Future<void> openStoreListing() =>
      _inAppReview.openStoreListing(appStoreId: '6758549078');

  static const _kWeightCountKey = 'analytics_weight_record_count';
  static const _kReviewPromptedKey = 'analytics_review_prompted';
  static const _kReviewThreshold = 5;

  Future<void> _checkReviewPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_kReviewPromptedKey) ?? false;
    if (alreadyPrompted) return;

    final count = (prefs.getInt(_kWeightCountKey) ?? 0) + 1;
    await prefs.setInt(_kWeightCountKey, count);

    if (count >= _kReviewThreshold) {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        await prefs.setBool(_kReviewPromptedKey, true);
      }
    }
  }
}
