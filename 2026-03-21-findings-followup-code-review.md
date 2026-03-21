# Riverpod 마이그레이션 구현 기록

> 구현일: 2026-03-21 | findings.md H-5 (상태관리 SSOT 부재) 후속 작업

---

## 배경

코드 리뷰(2026-03-20)에서 발견된 H-5 이슈:
- 10+ 스크린이 `PetService.getActivePet()`을 독립 호출 → 중복 네트워크 요청, 화면 간 데이터 불일치
- ChangeNotifier 2개(`ActivePetNotifier`, `LocaleProvider`) + 서비스 싱글턴 27개의 수동 상태 관리
- `addListener/removeListener` 패턴 → 메모리 누수 위험

`flutter_riverpod: ^2.6.1` 도입으로 SSOT 확보.

---

## 구현 완료 Phase (0-7)

### Phase 0: Foundation

| 항목 | 내용 |
|------|------|
| 의존성 | `pubspec.yaml`에 `flutter_riverpod: ^2.6.1` 추가 |
| ProviderScope | `main.dart` — `runApp(ProviderScope(child: MyApp()))` |
| Provider 파일 | 5개 빈 껍데기 생성 (`pet_providers`, `premium_provider`, `bhi_provider`, `service_providers`, `auth_actions`) |

### Phase 1: Core SSOT — Active Pet

**신규 Provider:**

```
activePetProvider   (AsyncNotifierProvider<ActivePetNotifier, Pet?>)
├── build(): PetService.instance.getActivePet() 호출
├── switchPet(petId): setActivePet → invalidateCache → forceRefresh + bhiProvider 무효화
├── refresh(): forceRefresh
└── clear(): 로그아웃용

petListProvider     (AsyncNotifierProvider<PetListNotifier, List<Pet>>)
├── build(): PetService.instance.getMyPets()
└── refresh(): forceRefresh

localeNotifierProvider  (NotifierProvider<LocaleNotifier, Locale?>)
├── build(): LocaleProvider.instance.locale (bridge)
└── setLocale(locale): LocaleProvider 위임
```

**main.dart 전환:**
- `MyApp`: `StatefulWidget` → `ConsumerWidget`
- `LocaleProvider.instance.addListener` / `removeListener` / `_onLocaleChanged` 제거
- `locale: ref.watch(localeNotifierProvider)`

**스크린 전환 (14개):**

| 스크린 | 주요 변경 |
|--------|-----------|
| HomeScreen | `ConsumerStatefulWidget` + `ref.watch(activePetProvider)` + `addPostFrameCallback`으로 펫 변경 감지 |
| WeightDetailScreen | 동일 패턴 + `_switchPet` 트리거 |
| FoodRecordScreen | `getActivePet()` → `ref.read(activePetProvider).valueOrNull` |
| WaterRecordScreen | 동일 |
| AIEncyclopediaScreen | 동일 (SSE 스트리밍 로컬 상태 미변경) |
| PetProfileScreen | `ActivePetNotifier.instance.notify()` → `ref.read(activePetProvider.notifier).switchPet()` |
| PetProfileDetailScreen | `getActivePet()` 교체 + `notify()` → `switchPet()` |
| ProfileScreen | `getActivePet()` 교체 + `notify()` → `switchPet()` |
| WeightAddScreen | `ref.read(activePetProvider).valueOrNull` (one-shot) |
| WeightRecordScreen | 동일 |
| HealthCheckHistoryScreen | `addListener/removeListener` 제거 + `ref.listen` 사용 |
| HealthCheckAnalyzingScreen | `activePetId` 접근 교체 |
| HealthCheckResultScreen | 동일 |
| VetSummaryScreen | 동일 |

**레거시 브릿지:**
- `pet_providers.dart`의 `switchPet()` 내에서 `legacy.ActivePetNotifier.instance.notify(petId)` 호출
- Phase 7 (미구현)에서 제거 예정

### Phase 2: Premium & BHI Providers

```
premiumStatusProvider  (AsyncNotifierProvider<PremiumStatusNotifier, PremiumStatus>)
├── build(): PremiumService.instance.getTier()
├── refresh(): forceRefresh
└── activateCode(code): 성공 시 자동 refresh

bhiProvider            (FutureProvider.autoDispose<BhiResult?>)
└── ref.watch(activePetProvider) → 펫 변경 시 자동 재fetch

bhiByDateProvider      (FutureProvider.autoDispose.family<BhiResult?, DateTime>)
└── 특정 날짜 BHI 조회 (HomeScreen 기간 선택용)
```

### Phase 3: 서비스 DI Wrappers

`lib/src/providers/service_providers.dart` — 10개 서비스 Provider 래퍼:

```dart
foodRecordServiceProvider, waterRecordServiceProvider, dailyRecordServiceProvider,
scheduleServiceProvider, notificationServiceProvider, weightServiceProvider,
breedServiceProvider, syncServiceProvider, authServiceProvider
```

### Phase 4: 로그아웃 헬퍼

`lib/src/providers/auth_actions.dart`:

```dart
Future<void> performLogout(WidgetRef ref) async {
  await AuthService.instance.signOut();
  ref.invalidate(activePetProvider);
  ref.invalidate(petListProvider);
  ref.invalidate(premiumStatusProvider);
  ref.invalidate(bhiProvider);
}
```

### Phase 5: SplashScreen Provider 시딩

`splash_screen.dart` — `_initializeServices()` 마지막에:

```dart
if (TokenService.instance.isLoggedIn) {
  await ref.read(activePetProvider.notifier).refresh();
  await ref.read(petListProvider.notifier).refresh();
}
```

→ HomeScreen 진입 시 로딩 스피너 없이 즉시 렌더

---

## 신규 파일 (5개)

| 파일 | 목적 |
|------|------|
| `lib/src/providers/pet_providers.dart` | activePetProvider, petListProvider (SSOT) |
| `lib/src/providers/premium_provider.dart` | premiumStatusProvider |
| `lib/src/providers/bhi_provider.dart` | bhiProvider, bhiByDateProvider |
| `lib/src/providers/service_providers.dart` | 10개 stateless 서비스 DI 래퍼 |
| `lib/src/providers/auth_actions.dart` | performLogout() 헬퍼 |

## 수정 파일 (19개)

| 파일 | 변경 |
|------|------|
| `pubspec.yaml` | flutter_riverpod 추가 |
| `lib/main.dart` | ProviderScope + ConsumerWidget |
| `lib/src/providers/locale_provider.dart` | localeNotifierProvider 추가 |
| `lib/src/screens/splash/splash_screen.dart` | ConsumerStatefulWidget + provider 시딩 |
| `lib/src/screens/home/home_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/weight/weight_detail_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/weight/weight_add_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/weight/weight_record_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/food/food_record_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/water/water_record_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/pet/pet_profile_screen.dart` | ConsumerStatefulWidget + switchPet |
| `lib/src/screens/profile/profile_screen.dart` | ConsumerStatefulWidget + switchPet |
| `lib/src/screens/profile/pet_profile_detail_screen.dart` | ConsumerStatefulWidget + switchPet |
| `lib/src/screens/health_check/health_check_history_screen.dart` | ConsumerStatefulWidget + ref.listen |
| `lib/src/screens/health_check/health_check_analyzing_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/health_check/health_check_result_screen.dart` | ConsumerStatefulWidget |
| `lib/src/screens/health_check/vet_summary_screen.dart` | ConsumerStatefulWidget |

## 의도적 미변경 (싱글턴 유지)

| 파일 | 이유 |
|------|------|
| `sync_service.dart` | 복잡한 라이프사이클 + WidgetsBindingObserver |
| `token_service.dart` | FlutterSecureStorage 라이프사이클 |
| `api_client.dart` | HTTP 클라이언트 |
| `local_image_storage_service.dart` | SQLite 라이프사이클 |
| `app_router.dart` | GoRouter는 위젯 트리 밖 |

---

## Phase 6: 나머지 20개 스크린 전환 (완료)

**StatefulWidget → ConsumerStatefulWidget (16개):**
- LoginScreen, EmailLoginScreen, SignupScreen, PetAddScreen
- HealthCheckMainScreen, HealthCheckCaptureScreen
- ProfileSetupScreen, NotificationScreen
- ForgotPasswordMethodScreen, ForgotPasswordCodeScreen, ForgotPasswordResetScreen
- BhiDetailScreen, PremiumScreen, PromoCodeBottomSheet
- CountrySelectorBottomSheet, OnboardingScreen

**StatelessWidget → ConsumerWidget (4개):**
- TermsDetailScreen, WciIndexScreen, FaqScreen, ProfileSetupCompleteScreen

## Phase 7: 레거시 삭제 (완료)

- `active_pet_notifier.dart` 삭제
- `pet_providers.dart` 레거시 브릿지 코드 (`legacy.ActivePetNotifier.instance.notify`) 제거
- `pet_service.dart` — `ActivePetNotifier.instance.notify(pet.id)` + import 제거
- `auth_service.dart` — `ActivePetNotifier.instance.clear()` 2건 + import 제거

---

---

## M-2: 하드코딩 색상 전체 제거 (완료)

screens + widgets에서 `Color(0x...)` 하드코딩 ~530건 → **0건** 달성.

### 작업 내용
- 46개 파일의 모든 `Color(0xFFXXXXXX)` → `AppColors.xxx` 상수로 교체
- `colors.dart`에 35개 신규 AppColors 상수 추가:
  - 시맨틱: `danger/success/info/warning` 계열 (밝은/어두운 변형 포함)
  - 브랜드: `brandLighter`, `brandPale`, `brandAccent`, `gradientBottomAlt`
  - 오버레이/그림자: `shadowLight`, `shadowMedium`, `overlay30/50`, `overlayWhite60/80/90`
  - 차트/헬스체크/체중: `yellow`, `lime`, `partSpecificBlue`, `weightIdeal` 등

### 교체 규칙
- `Color(0xFF1A1A1A)` → `AppColors.nearBlack` (92건, 최다)
- `Color(0xFF97928A)` → `AppColors.warmGray` (93건)
- `Color(0xFFFF9A42)` → `AppColors.brandPrimary` (65건)
- `const Color(0x...)` → `AppColors.xxx` (const 키워드 제거 — AppColors가 이미 static const)

---

## M-5: 접근성 Semantics 구현 (완료)

144개 GestureDetector 전체에 `Semantics` 위젯 래핑 완료.

### 작업 내용
- 37개 파일 (screens 27개 + widgets 10개)의 모든 GestureDetector에 Semantics 추가
- 스크린리더(VoiceOver/TalkBack)가 모든 터치 영역을 인식 가능

### Semantics 적용 패턴

**버튼 (onTap 있는 GestureDetector):**
```dart
Semantics(
  button: true,
  label: '저장',  // 또는 l10n 키
  child: GestureDetector(onTap: ..., child: ...),
)
```

**체크박스 (terms_agreement_section):**
```dart
Semantics(
  button: true,
  label: '전체 동의',
  checked: isChecked,
  child: GestureDetector(...),
)
```

**선택 요소 (날짜, 색상, 탭):**
```dart
Semantics(
  button: true,
  label: 'March 21',
  selected: isSelected,
  child: GestureDetector(...),
)
```

### label 규칙
| 유형 | label 소스 | 예시 |
|------|-----------|------|
| 텍스트 버튼 | l10n 키 또는 텍스트 | `l10n.btn_save`, `l10n.profile_logout` |
| 아이콘 버튼 | 동작 설명 (영문) | `'Go back'`, `'Close'`, `'Send message'` |
| 카드/영역 | 핵심 내용 | `'Select pet'`, 펫 이름, 모드 레이블 |
| 동적 | 파라미터 기반 | `hint` (날짜 필드), `q` (채팅 칩) |

---

## 최종 검증 결과

```
flutter analyze: 0 errors
flutter test:    169/169 passed

Color(0x...) in screens + widgets: 0건
Semantics-wrapped GestureDetectors: 144건
ActivePetNotifier 레거시: 완전 삭제
```
