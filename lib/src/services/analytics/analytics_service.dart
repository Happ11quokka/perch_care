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

  // --- IAP / Paywall Events ---

  Future<void> logPaywallView({required String source, String? feature}) =>
      _analytics.logEvent(name: 'paywall_view', parameters: {
        'source': source,
        if (feature != null) 'feature': feature,
      });

  Future<void> logPlanSelected({required String plan, required String source}) =>
      _analytics.logEvent(name: 'plan_selected', parameters: {
        'plan': plan,
        'source': source,
      });

  Future<void> logCheckoutStarted({required String store, required String productId, required String source}) =>
      _analytics.logEvent(name: 'checkout_started', parameters: {
        'store': store,
        'product_id': productId,
        'source': source,
      });

  Future<void> logPurchaseSuccess({required String store, required String productId, bool isRestore = false}) =>
      _analytics.logEvent(name: 'purchase_success', parameters: {
        'store': store,
        'product_id': productId,
        'is_restore': isRestore,
      });

  Future<void> logPurchaseFailed({required String store, required String productId, required String reason}) =>
      _analytics.logEvent(name: 'purchase_failed', parameters: {
        'store': store,
        'product_id': productId,
        'reason': reason,
      });

  Future<void> logRestoreSuccess({required String store}) =>
      _analytics.logEvent(name: 'restore_success', parameters: {'store': store});

  Future<void> logPremiumFeatureBlocked({required String feature, required String sourceScreen}) =>
      _analytics.logEvent(name: 'premium_feature_blocked', parameters: {
        'feature': feature,
        'source_screen': sourceScreen,
      });

  Future<void> logPromoCodeEntryOpened({required String source}) =>
      _analytics.logEvent(name: 'promo_code_entry_opened', parameters: {'source': source});

  Future<void> logPromoCodeActivated({required String codePrefix}) =>
      _analytics.logEvent(name: 'promo_code_activated', parameters: {'code_prefix': codePrefix});

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
