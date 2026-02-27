# Firebase Analytics + In-App Review Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Firebase Analytics event tracking (screen_view auto + 10 core events) and in-app review prompt after 5 weight records.

**Architecture:** Central `AnalyticsService` singleton following existing project pattern (PushNotificationService, CoachMarkService). `FirebaseAnalyticsObserver` on GoRouter for automatic screen tracking. SharedPreferences for review prompt state.

**Tech Stack:** `firebase_analytics`, `in_app_review`, `shared_preferences` (already installed)

---

### Task 1: Add dependencies

**Files:**
- Modify: `pubspec.yaml`

**Step 1: Add packages to pubspec.yaml**

Add under `dependencies:` after `firebase_messaging: ^15.2.4`:
```yaml
  firebase_analytics: ^11.4.2
  in_app_review: ^2.0.10
```

**Step 2: Install**

Run: `flutter pub get`
Expected: packages resolve successfully

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "feat: add firebase_analytics and in_app_review dependencies"
```

---

### Task 2: Create AnalyticsService

**Files:**
- Create: `lib/src/services/analytics/analytics_service.dart`

**Step 1: Create the service file**

```dart
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
```

**Step 2: Commit**

```bash
git add lib/src/services/analytics/analytics_service.dart
git commit -m "feat: create AnalyticsService with core events and in-app review"
```

---

### Task 3: Wire FirebaseAnalyticsObserver into GoRouter

**Files:**
- Modify: `lib/src/router/app_router.dart`

**Step 1: Add observer to GoRouter**

Add import at top:
```dart
import '../services/analytics/analytics_service.dart';
```

Add `observers` parameter to `GoRouter` constructor (after `debugLogDiagnostics: true,`):
```dart
observers: [AnalyticsService.instance.observer],
```

**Step 2: Commit**

```bash
git add lib/src/router/app_router.dart
git commit -m "feat: add FirebaseAnalyticsObserver to GoRouter"
```

---

### Task 4: Add login/signup events to AuthService

**Files:**
- Modify: `lib/src/services/auth/auth_service.dart`

**Step 1: Add analytics calls**

Add import at top:
```dart
import '../analytics/analytics_service.dart';
```

In `signUpWithEmail()` (after `PushNotificationService.instance.initialize();` at line 93):
```dart
AnalyticsService.instance.logSignUp('email');
```

In `signInWithEmailPassword()` (after `PushNotificationService.instance.initialize();` at line 110):
```dart
AnalyticsService.instance.logLogin('email');
```

In `_handleOAuthResponse()` — after `PushNotificationService.instance.initialize();` at line 166, we need the provider name. Add parameter:

Actually, the OAuth methods already know the provider. Add tracking in each OAuth method's success path:

In `signInWithGoogle()` — after `return _handleOAuthResponse(response);` won't work since it's a return. Instead, modify `_handleOAuthResponse` to accept a provider string:

**Simpler approach:** Add tracking in each caller after the `_handleOAuthResponse` returns success:

In `signInWithGoogle()` (after line 119, wrap the call):
```dart
final result = await _handleOAuthResponse(response);
if (result.success) AnalyticsService.instance.logLogin('google');
return result;
```

In `signInWithApple()` (after line 136, same pattern):
```dart
final result = await _handleOAuthResponse(response);
if (result.success) AnalyticsService.instance.logLogin('apple');
return result;
```

In `signInWithKakao()` (after line 145, same pattern):
```dart
final result = await _handleOAuthResponse(response);
if (result.success) AnalyticsService.instance.logLogin('kakao');
return result;
```

In `deleteAccount()` (before `await _api.delete('/users/me');` at line 261):
```dart
AnalyticsService.instance.logAccountDeleted();
```

**Step 2: Commit**

```bash
git add lib/src/services/auth/auth_service.dart
git commit -m "feat: add analytics events to auth flows"
```

---

### Task 5: Add weight_recorded event

**Files:**
- Modify: `lib/src/screens/weight/weight_add_screen.dart`

**Step 1: Add analytics call**

Add import:
```dart
import '../../services/analytics/analytics_service.dart';
```

In `_onSave()`, after `AppSnackBar.success(...)` at line 129:
```dart
AnalyticsService.instance.logWeightRecorded(_activePetId!);
```

This also triggers the in-app review check internally.

**Step 2: Commit**

```bash
git add lib/src/screens/weight/weight_add_screen.dart
git commit -m "feat: add weight_recorded analytics event"
```

---

### Task 6: Add food_recorded event

**Files:**
- Modify: `lib/src/screens/food/food_record_screen.dart`

**Step 1: Add analytics call**

Add import:
```dart
import '../../services/analytics/analytics_service.dart';
```

In `_saveEntries()`, at the end of the method (after the backend save try/catch, before closing brace at ~line 135):
```dart
AnalyticsService.instance.logFoodRecorded(_activePetId ?? '', _entries.length);
```

**Step 2: Commit**

```bash
git add lib/src/screens/food/food_record_screen.dart
git commit -m "feat: add food_recorded analytics event"
```

---

### Task 7: Add water_recorded event

**Files:**
- Modify: `lib/src/screens/water/water_record_screen.dart`

**Step 1: Add analytics call**

Add import:
```dart
import '../../services/analytics/analytics_service.dart';
```

In `_saveRecord()`, at the end of the method (after the backend save try/catch, before closing brace at ~line 127):
```dart
AnalyticsService.instance.logWaterRecorded(_activePetId ?? '');
```

**Step 2: Commit**

```bash
git add lib/src/screens/water/water_record_screen.dart
git commit -m "feat: add water_recorded analytics event"
```

---

### Task 8: Add pet_registered event

**Files:**
- Modify: `lib/src/screens/pet/pet_add_screen.dart`

**Step 1: Add analytics call**

Add import:
```dart
import '../../services/analytics/analytics_service.dart';
```

In `_handleSave()`, after `AppSnackBar.success(...)` at line 277, only for new pet creation:
```dart
if (_existingPet == null) {
  AnalyticsService.instance.logPetRegistered(_speciesController.text.trim());
}
```

**Step 2: Commit**

```bash
git add lib/src/screens/pet/pet_add_screen.dart
git commit -m "feat: add pet_registered analytics event"
```

---

### Task 9: Add ai_chat_sent event

**Files:**
- Modify: `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart`

**Step 1: Add analytics call**

Add import:
```dart
import '../../services/analytics/analytics_service.dart';
```

In `_handleSend()` at line 150, after the `if (text.isEmpty) return;` check:
```dart
AnalyticsService.instance.logAiChatSent();
```

**Step 2: Commit**

```bash
git add lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart
git commit -m "feat: add ai_chat_sent analytics event"
```

---

### Task 10: Add bhi_viewed event

**Files:**
- Modify: `lib/src/screens/home/home_screen.dart`

**Step 1: Add analytics call**

Add import:
```dart
import '../../services/analytics/analytics_service.dart';
```

In the BHI card `onTap` handler (around line 965-970), before `context.pushNamed(RouteNames.bhiDetail, ...)`:
```dart
if (_bhiResult != null) {
  AnalyticsService.instance.logBhiViewed(_bhiResult!.petId ?? '');
}
```

Note: Check if `BhiResult` has a `petId` field. If not, use the active pet ID from the screen's state.

**Step 2: Commit**

```bash
git add lib/src/screens/home/home_screen.dart
git commit -m "feat: add bhi_viewed analytics event"
```

---

### Task 11: Add pet_deleted event

**Files:**
- Modify: `lib/src/screens/pet/pet_profile_screen.dart`

**Step 1: Add analytics call**

Add import:
```dart
import '../../services/analytics/analytics_service.dart';
```

In `_deletePet()`, after `await _petService.deletePet(petId);` at line 124:
```dart
AnalyticsService.instance.logPetDeleted();
```

**Step 2: Commit**

```bash
git add lib/src/screens/pet/pet_profile_screen.dart
git commit -m "feat: add pet_deleted analytics event"
```

---

### Task 12: Verify and final commit

**Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: No new errors or warnings from our changes

**Step 2: Run the app**

Run: `flutter run`
Verify:
- App launches without crashes
- Check debug console for Firebase Analytics debug output
- Navigate between screens → screen_view events logged
- Save a weight record → weight_recorded event logged

**Step 3: Final commit (if any fixes needed)**

```bash
git add -A
git commit -m "feat: Firebase Analytics + In-App Review implementation complete"
```

---

## Verification Checklist

1. `flutter analyze` passes with no new issues
2. App launches without crashes
3. Firebase Analytics dashboard shows events after ~24h (or use DebugView for real-time)
4. Screen names appear in Firebase → Events → screen_view
5. Weight record save triggers `weight_recorded` event
6. After 5th weight record, in-app review dialog appears (iOS) or is queued (Android)
