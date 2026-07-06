# Stage 3 — S/M 도메인 MVVM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 소형 도메인(bhi 데드코드 제거, notification, breed/image 공용 위젯, locale 역참조 제거, profile 화면 pet/locale 부분)을 MVVM 규약(View→VM/Repository→Service)으로 정리한다.

**Architecture:** 기존 5-layer 유지. 데드 provider는 삭제, 서비스→provider 역참조는 resolver 주입(composition root 배선)으로 제거, 화면의 서비스 싱글턴 직접 호출은 기존/신설 provider·ViewModel 경유로 교체.

**Tech Stack:** Flutter, flutter_riverpod, mocktail + ProviderContainer 단위 테스트.

## Global Constraints

- **behavior-preserving**: 순수 구조 변경. UI·네트워크·에러 처리·언어 헤더 값·부트스트랩 동작을 바꾸지 않는다(명시된 버그 수정 제외).
- **CoachMarkService / AnalyticsService는 View/VM 직접 호출 허용**(cross-cutting 예외). provider로 감싸지 않는다.
- **LocaleProvider.initialize는 반드시 main()에서 runApp 이전에 await 유지** — splash로 옮기지 않는다(LocaleNotifier.build가 초기값을 읽는 시점 회귀 방지).
- **AsyncViewModel base에는 runLoad만 존재**(runAction 없음). 세밀 갱신형은 AsyncNotifier 직접 상속.
- **레거시 provider alias 유지**.
- **splash appStartupProvider 추출은 이 Stage 범위에서 제외**(app-launch critical + 단위테스트 불가 → 별도 device 검증 필요, 최종 보고에 플래그).
- **완료 게이트(매 커밋 전)**: `flutter analyze`(신규 이슈 0) + `flutter test`(전체 통과).
- 커밋 푸터:
  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  ```

---

## File Structure

**삭제:** `lib/src/providers/bhi_provider.dart`
**신규:** `lib/src/repositories/notification_repository.dart`, `lib/src/view_models/notification/notification_view_model.dart`, 각 테스트; `test/repositories/notification_repository_test.dart`, `test/view_models/notification/notification_view_model_test.dart`
**수정:** `auth_actions.dart`(bhi invalidate 제거), `service_providers.dart`(localImageStorageServiceProvider 추가), `api_client.dart`+`push_notification_service.dart`(languageCodeResolver 주입), `main.dart`(resolver 배선), `notification_screen.dart`, `breed_selector.dart`, `local_image_avatar.dart`, `profile_screen.dart`(pet/locale 부분)

---

## Task 1: bhi_provider 데드코드 제거

**근거(매핑 확정):** `bhiProvider`/`bhiByDateProvider`를 `ref.watch`하는 소비자가 앱 전체에 0건. 유일 참조는 `auth_actions.dart:11`의 `ref.invalidate(bhiProvider)`. 홈 BHI는 HomeRepository→BhiService 경로, BhiDetailScreen은 constructor 주입. → Repository 신설 대신 삭제가 옳다(스펙 "BhiRepository 신설"에서 벗어나는 의도적 결정).

**Files:**
- Delete: `lib/src/providers/bhi_provider.dart`
- Modify: `lib/src/providers/auth_actions.dart`

**Interfaces:** 없음(순수 제거).

- [ ] **Step 1: 안전 확인** — `grep -rn "bhi_provider\|bhiProvider\|bhiByDateProvider" lib/ test/`로 참조 전수 확인. `auth_actions.dart:4`(import) + `:11`(invalidate) 외 참조가 있으면 STOP하고 보고. (예상: 그 2곳뿐.)

- [ ] **Step 2: 제거** — `auth_actions.dart`에서 `import 'bhi_provider.dart';`(L4)와 `ref.invalidate(bhiProvider);`(L11) 삭제. 파일 `lib/src/providers/bhi_provider.dart` 삭제.

- [ ] **Step 3: 검증**

Run: `flutter analyze lib/ test/` → No issues. `grep -rn "bhiProvider\|bhi_provider" lib/ test/` → 0 매치.
Run: `flutter test` → 전체 통과.

- [ ] **Step 4: Commit**

```bash
git rm lib/src/providers/bhi_provider.dart
git add lib/src/providers/auth_actions.dart
git commit -m "$(cat <<'EOF'
|REMOVE| bhi_provider 데드코드 제거 — watcher 0(홈은 HomeRepository 경로), auth_actions invalidate만 정리

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 2: localImageStorageServiceProvider + local_image_avatar 전환

**Files:**
- Modify: `lib/src/providers/service_providers.dart`
- Modify: `lib/src/widgets/local_image_avatar.dart`

**Interfaces:**
- Produces: `final localImageStorageServiceProvider = Provider<LocalImageStorageService>((ref) => LocalImageStorageService.instance);`
- Consumes: `LocalImageStorageService.getImage({required String ownerType, required String ownerId}) → Future<Uint8List?>`

- [ ] **Step 1:** `service_providers.dart`에 import + provider 추가:
```dart
import '../services/storage/local_image_storage_service.dart';
```
```dart
final localImageStorageServiceProvider =
    Provider<LocalImageStorageService>((ref) => LocalImageStorageService.instance);
```

- [ ] **Step 2:** `local_image_avatar.dart`(69줄) 읽기. `StatefulWidget`→`ConsumerStatefulWidget`, `State`→`ConsumerState`. `LocalImageStorageService.instance.getImage(...)`(L44) → `ref.read(localImageStorageServiceProvider).getImage(...)`. import 정리(flutter_riverpod + repository_providers 아님 service_providers). `didUpdateWidget` 재로드 로직 보존.

- [ ] **Step 3: 검증**

Run: `flutter analyze lib/src/widgets/local_image_avatar.dart lib/src/providers/service_providers.dart` → No issues. `grep -n "LocalImageStorageService.instance" lib/src/widgets/local_image_avatar.dart` → 0.
Run: `flutter test` → 통과.

- [ ] **Step 4: Commit**
```bash
git add lib/src/providers/service_providers.dart lib/src/widgets/local_image_avatar.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| local_image_avatar — localImageStorageServiceProvider 경유(Consumer 전환)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 3: breed_selector 다이얼로그 provider 전환

**Files:**
- Modify: `lib/src/widgets/breed_selector.dart`

**Interfaces:**
- Consumes: `breedServiceProvider`(service_providers.dart:20 기존) → `BreedService.fetchBreedStandards({bool forceRefresh}) → Future<List<BreedStandard>>` (실패 시 예외 대신 캐시/빈 리스트 반환 — 동작 보존).

- [ ] **Step 1:** `breed_selector.dart`(449줄) 읽기. 외부 `BreedSelector`(L24-114)는 순수 presentational — 건드리지 않음. 내부 `_BreedSearchDialog`(L117-449, StatefulWidget)만 `ConsumerStatefulWidget`으로. `BreedService.instance.fetchBreedStandards()`(L157) → `ref.read(breedServiceProvider).fetchBreedStandards()`. import 추가(flutter_riverpod + service_providers). setState/검색 필터/컨트롤러는 View 유지.

- [ ] **Step 2: 검증**

Run: `flutter analyze lib/src/widgets/breed_selector.dart` → No issues. `grep -n "BreedService.instance" lib/src/widgets/breed_selector.dart` → 0.
Run: `flutter test` → 통과. (호출처 `pet_add_screen.dart:408`는 위젯 사용만 — 시그니처 불변 확인.)

- [ ] **Step 3: Commit**
```bash
git add lib/src/widgets/breed_selector.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| breed_selector 검색 다이얼로그 — breedServiceProvider 경유(Consumer 전환)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 4: NotificationRepository 신설

**Files:**
- Create: `lib/src/repositories/notification_repository.dart`
- Create: `test/repositories/notification_repository_test.dart`
- Modify: `lib/src/providers/repository_providers.dart`

**주의(unreachable 화면):** NotificationScreen 라우트('/home/notification')로 네비게이트하는 코드가 앱에 없다(현재 도달 불가). 그럼에도 MVVM 완성 + clear-on-error 버그 수정을 위해 전환한다. 최종 보고에 도달 불가 사실 플래그.

**Interfaces:**
- Consumes: `NotificationService`(fetchNotifications/markAsRead/markAllAsRead/deleteNotification/getUnreadCount/subscribeToNotifications), `AppNotification` 모델.
- Produces:
  - `abstract class NotificationRepository { Future<List<AppNotification>> fetch({int? limit, bool unreadOnly}); Future<void> markAsRead(String id); Future<void> markAllAsRead(); Future<void> delete(String id); Stream<List<AppNotification>> subscribe(); }`
  - `class NotificationRepositoryImpl implements NotificationRepository { NotificationRepositoryImpl({NotificationService? service}); }`
  - `final notificationRepositoryProvider = Provider<NotificationRepository>((ref) => NotificationRepositoryImpl());`

- [ ] **Step 1:** `lib/src/services/notification/notification_service.dart` 읽어 정확한 시그니처 확인(fetchNotifications 파라미터, subscribeToNotifications 반환 타입).

- [ ] **Step 2: 실패 테스트 작성** `test/repositories/notification_repository_test.dart` — mocktail MockNotificationService로 fetch/markAsRead/markAllAsRead/delete 위임 검증 (schedule_repository_test.dart 패턴). subscribe는 서비스 stream 위임 확인.

- [ ] **Step 3: 구현** — abstract + Impl(서비스 위임). `repository_providers.dart`에 import + provider 추가.

- [ ] **Step 4: 검증** `flutter test test/repositories/notification_repository_test.dart` PASS + `flutter analyze` clean.

- [ ] **Step 5: Commit**
```bash
git add lib/src/repositories/notification_repository.dart test/repositories/notification_repository_test.dart lib/src/providers/repository_providers.dart
git commit -m "$(cat <<'EOF'
|FEAT| NotificationRepository 신설 — NotificationService 래핑(fetch/markAsRead/markAllAsRead/delete/subscribe)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 5: NotificationViewModel + notification_screen 전환

**Files:**
- Create: `lib/src/view_models/notification/notification_view_model.dart`
- Create: `test/view_models/notification/notification_view_model_test.dart`
- Modify: `lib/src/screens/notification/notification_screen.dart`

**Interfaces:**
- Consumes: `notificationRepositoryProvider`.
- Produces: `class NotificationViewModel extends AsyncNotifier<List<AppNotification>>` — `build()`(초기 fetch + subscribe 구독, `ref.onDispose`로 정리), `markAsRead(id)`(낙관적), `markAllAsRead()`, `delete(id)`. `final notificationViewModelProvider = AsyncNotifierProvider<NotificationViewModel, List<AppNotification>>(NotificationViewModel.new);`

**버그 수정(명시):** 기존 화면은 subscribe 스트림이 에러 시 빈 리스트를 yield하면 목록을 통째로 비운다. VM은 스트림 수신값을 state에 반영하되 **빈 리스트 수신이 에러 유발이면 이전 값 유지**(스트림 값을 그대로 신뢰하지 말고, 서비스가 이미 빈 리스트를 정상값으로 주는지 확인 후 결정). 최소 변경 원칙: 스트림 값이 오면 `AsyncData(list)`로 반영하되, `copyWithPrevious` 사용은 로딩 표시에만. 스트림 자체가 에러-시-빈리스트 계약이면 VM에서 "빈 리스트로의 급변"을 무시하는 대신 **서비스 계약을 그대로 반영(behavior-preserving)하고 최종 보고에 잠재 UX 버그로 플래그**. — 즉 이 태스크는 구조 전환에 집중, 스트림 병합 시맨틱 변경은 하지 않는다.

- [ ] **Step 1:** `notification_screen.dart`(333줄) + NotificationService.subscribeToNotifications 계약 읽기.

- [ ] **Step 2: 실패 테스트** — build 시 fetch 호출/초기 목록, markAsRead 낙관적 갱신, delete removeWhere를 mock repository로 검증. (stream은 test에서 `Stream.value([...])` mock.)

- [ ] **Step 3: VM 구현** — `build()`에서 `repo.fetch()` 후 `repo.subscribe().listen(...)` 구독, `ref.onDispose(sub.cancel)`. markAsRead/markAllAsRead/delete는 낙관적 state 갱신 후 repo 호출, 실패 시 재fetch. **subscribe 수신 값은 state로 반영(기존 동작 보존)**.

- [ ] **Step 4: 화면 전환** — `NotificationService.instance` 필드/직접 호출 제거, `ConsumerState`에서 `ref.watch(notificationViewModelProvider)` 구독, 버튼 핸들러는 `ref.read(...notifier)` 메서드 호출. 로컬 `_notifications`/`_subscription`/`_isLoading` 상태 제거(VM/AsyncValue가 대체). setState 제거.

- [ ] **Step 5: 검증** `flutter test` 전체 통과 + `flutter analyze` clean + `grep NotificationService.instance lib/src/screens/notification/` → 0.

- [ ] **Step 6: Commit**
```bash
git add lib/src/view_models/notification/ test/view_models/notification/ lib/src/screens/notification/notification_screen.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| notification_screen MVVM 전환 — NotificationViewModel(AsyncNotifier) 경유, setState/직접 구독 제거

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 6: locale 역참조 제거 (resolver 주입)

**근거:** `api_client.dart:37-42` `_acceptLanguage`와 `push_notification_service.dart:74` `_registerToken`이 `LocaleProvider.instance.currentLanguageCode`를 직접 읽는다(서비스→provider 역참조 = MVVM 위반). 이를 composition root에서 배선하는 resolver 함수 주입으로 대체한다. LocaleProvider 싱글턴 자체(및 prefs·초기화)는 유지(초기화 순서 회귀 방지).

**Files:**
- Modify: `lib/src/services/api/api_client.dart`
- Modify: `lib/src/services/push/push_notification_service.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Produces: `ApiClient.languageCodeResolver` (static `String? Function()?`), `PushNotificationService.languageCodeResolver` (동일).

- [ ] **Step 1: ApiClient** — 클래스에 `static String? Function()? languageCodeResolver;` 추가. `_acceptLanguage`(L37-42) 수정:
```dart
String get _acceptLanguage {
  final appLang = languageCodeResolver?.call();
  if (appLang != null) return appLang;
  final locale = ui.PlatformDispatcher.instance.locale;
  return locale.toLanguageTag();
}
```
`import '../../providers/locale_provider.dart';`(L8) 제거(더 이상 참조 안 함).

- [ ] **Step 2: PushNotificationService** — `push_notification_service.dart` 읽기. `LocaleProvider.instance.currentLanguageCode`(L74) 직접 읽기를 `static String? Function()? languageCodeResolver;` + `languageCodeResolver?.call()`로 교체. 폴백(WidgetsBinding platformDispatcher locale + ko/en/zh 정규화, L77)은 보존. locale_provider import 제거.

- [ ] **Step 3: main.dart 배선** — `LocaleProvider.initialize()` await 직후(runApp 이전)에:
```dart
ApiClient.languageCodeResolver = () => LocaleProvider.instance.currentLanguageCode;
PushNotificationService.languageCodeResolver = () => LocaleProvider.instance.currentLanguageCode;
```
(정확한 삽입 위치는 main.dart 읽고 dotenv∥Firebase∥LocaleProvider.initialize 병렬 await 직후. ApiClient.initialize()가 splash에서 인스턴스를 재생성하지만 languageCodeResolver는 **static**이라 인스턴스 재생성에 영향받지 않음 — 안전.)

- [ ] **Step 4: 검증** `flutter analyze lib/` clean. `grep -rn "LocaleProvider.instance" lib/src/services/` → 0(서비스 레이어에서 역참조 제거 확인). `grep -rn "LocaleProvider" lib/main.dart` → 배선 존재 확인.
Run: `flutter test` → 통과.

- [ ] **Step 5: Commit**
```bash
git add lib/src/services/api/api_client.dart lib/src/services/push/push_notification_service.dart lib/main.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| locale 역참조 제거 — ApiClient/PushNotificationService에 languageCodeResolver 주입, main에서 배선

서비스→LocaleProvider 직접 참조 제거(MVVM 위반 해소). Accept-Language/디바이스 토큰 language 값 동일 보존.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Task 7: profile_screen pet/locale 부분 전환

**범위 경계:** profile_screen(1,501줄)의 **pet 로딩 + locale 읽기**만 전환. **auth 부분(link/unlink/deleteAccount/getProfile via AuthService)은 Stage 4로 보류**(건드리지 않음).

**Files:**
- Modify: `lib/src/screens/profile/profile_screen.dart`

**전환 규칙:**
1. **pet 로딩(`_loadPets`, L257-294)**: `_petService.getMyPets()`(L257)·`_petCache.upsertPet`(L261)·`setActivePetId`(L275)·`getPets`(L278·293)·`getActivePet`(L294) 직접 호출을 제거하고 `ref.watch(petListViewModelProvider)` + `ref.watch(activePetViewModelProvider)` 구독으로 대체. 로컬 `_pets`/`_activePet` 상태 미러링 제거(가능한 범위). **주의:** 이 화면은 pet_profile_detail 저장 후 복귀 시 자체 `_loadPets()` 재호출로 stale를 가렸는데(Stage 2에서 detail이 이제 invalidate함), watch 구독으로 바꾸면 invalidate 시 자동 갱신되어 이 수동 재호출 의존이 사라진다.
2. **활성 펫 변경(L912 `_petCache.setActivePetId(petId)`)**: `ref.read(activePetViewModelProvider.notifier).switchPet(petId)`로 교체(ActivePetViewModel이 SSOT·영속화 담당).
3. **locale 읽기(L486·L555 `LocaleProvider.instance.currentLanguageCode`)**: `ref.watch(localeNotifierProvider)?.languageCode`로 교체(setLocale은 이미 L579-615에서 localeNotifierProvider.notifier.setLocale 사용 중 — 읽기/쓰기 일원화). `LocaleProvider.getDisplayName`(static, L488)은 유지(순수 함수).
4. `_petService`/`_petCache` 필드가 pet 부분에만 쓰이면 제거. **AuthService 필드(L42)와 auth 관련 호출은 유지(Stage 4).**

**주의:** 이 화면은 크고 auth 부분과 얽혀 있다. pet/locale 부분만 정확히 전환하고, 매핑이 깔끔하지 않으면(예: `_pets` 로컬 상태가 auth 흐름과 공유) STOP하고 DONE_WITH_CONCERNS로 보고.

- [ ] **Step 1:** `profile_screen.dart` 전체 읽기(offset 분할). `_loadPets`, L486·555 locale, L912 setActivePetId, 그리고 `_pets`/`_activePet` 로컬 상태의 참조 지점 전수 목록화.
- [ ] **Step 2:** 규칙 1-4 적용. 폼/UI 상태는 View 유지.
- [ ] **Step 3: 검증** `flutter analyze lib/src/screens/profile/profile_screen.dart` clean. `grep -n "_petService\|_petCache\|LocaleProvider.instance" lib/src/screens/profile/profile_screen.dart` → pet/locale 관련 0(AuthService는 잔존 OK). `flutter test` 통과.
- [ ] **Step 4: Commit**
```bash
git add lib/src/screens/profile/profile_screen.dart
git commit -m "$(cat <<'EOF'
|REFACTOR| profile_screen pet/locale 부분 MVVM 전환 — petList/activePet ViewModel·localeNotifier 구독(auth 부분은 Stage 4 보류)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
EOF
)"
```

---

## Self-Review (스펙 대비)

- **notification (S)** (스펙 #1): Task 4(Repo) + Task 5(VM+화면) ✅. 스트림 병합 시맨틱은 behavior-preserving 유지, 잠재 UX 버그는 플래그(스펙의 "ref.onDispose 정리"는 반영).
- **bhi (S)** (#2): Task 1 — **스펙의 "BhiRepository 신설" 대신 데드코드 삭제**(매핑 근거, 최종 보고에 명시). ✅(개선)
- **locale (S~M)** (#3): Task 6(resolver 주입) + Task 7(profile 읽기). 스펙의 "LocaleProvider→Riverpod Notifier 전면 전환"은 초기화 순서 회귀 리스크로 **부분 전환**(역참조 제거 + 읽기 일원화)에 그침 — 최종 보고에 명시. ⚠️
- **profile (M~L)** (#4): Task 7 — pet/locale만, auth는 Stage 4 ✅(스펙대로).
- **splash (M)** (#5): **이 Stage에서 제외** — app-launch critical·단위테스트 불가·device 검증 필요. 최종 보고 플래그. ⚠️
- **breed_selector / local_image_avatar** (#6): Task 3 / Task 2 ✅. + localImageStorageServiceProvider 신설로 pet_add_view_model 등 후속 이관 기반 마련.

**Placeholder scan:** 없음(Task 4/5 테스트는 "해당 서비스 시그니처 읽고 작성" 지시 — 실코드 기준).
**Type consistency:** notificationRepositoryProvider/notificationViewModelProvider, localImageStorageServiceProvider, languageCodeResolver 시그니처 Task 간 일관.
**보류/후속(최종 보고):** splash appStartupProvider(device 검증), LocaleProvider 싱글턴 전면 제거, notification 화면 도달 불가·스트림 UX 버그, pet_add_view_model의 BreedService/LocalImageStorage 직접 호출(신설 provider로 후속 이관 가능).
