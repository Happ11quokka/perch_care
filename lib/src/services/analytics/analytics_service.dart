import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final InAppReview _inAppReview = InAppReview.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // --- Core Events ---

  Future<void> logSignUp(String method) =>
      _analytics.logSignUp(signUpMethod: method);

  Future<void> logLogin(String method) =>
      _analytics.logLogin(loginMethod: method);

  Future<void> logPetRegistered(String species) =>
      _analytics.logEvent(name: 'pet_registered', parameters: {'species': species});

  Future<void> logWeightRecorded(String petId) async {
    await _analytics.logEvent(name: 'weight_recorded', parameters: {'pet_id': petId});
    await _checkReviewPrompt();
  }

  Future<void> logFoodRecorded(String petId, int entryCount) =>
      _analytics.logEvent(name: 'food_recorded', parameters: {
        'pet_id': petId,
        'entry_count': entryCount,
      });

  Future<void> logWaterRecorded(String petId) =>
      _analytics.logEvent(name: 'water_recorded', parameters: {'pet_id': petId});

  Future<void> logAiChatSent() =>
      _analytics.logEvent(name: 'ai_chat_sent');

  Future<void> logBhiViewed(String petId) =>
      _analytics.logEvent(name: 'bhi_viewed', parameters: {'pet_id': petId});

  Future<void> logPetDeleted() =>
      _analytics.logEvent(name: 'pet_deleted');

  Future<void> logAccountDeleted() =>
      _analytics.logEvent(name: 'account_deleted');

  // --- In-App Review ---

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
