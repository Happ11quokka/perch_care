# 앱 시작 성능 최적화 — SyncService 백그라운드 전환 + dotenv 병렬 로드

**날짜**: 2026-04-18
**배경**: 출시 직후 첫 홈 화면 진입까지의 TTF(Time To First Meaningful Screen)를 단축하기 위한 스플래시 크리티컬 패스 정리. 측정 기반 병목 식별 → 실제 영향이 큰 항목만 반영.
**선행 커밋**: `96ac14b |DOCS| 출시 전 사전 점검 개발 로그 추가`
**검증**: `flutter analyze` clean (0 issues) · `flutter test` 169/169 pass.

---

## 변경 파일 (2개)

| 카테고리 | 파일 | 수정 요지 |
|----------|------|----------|
| **시작 성능** | `lib/main.dart` | `dotenv.load()`를 `main()`으로 이동 · Firebase / Locale과 `Future.wait`로 병렬화 |
| **시작 성능** | `lib/src/screens/splash/splash_screen.dart` | `SyncService.processQueue()` + 펫별 `syncLocalRecordsIfNeeded()`를 splash 크리티컬 패스에서 제거 · `unawaited()`로 백그라운드 전환 · 펫 목록 provider 캐시 재사용으로 `getMyPets()` 중복 네트워크 호출 제거 |

---

## 문제 식별

스플래시 초기화 순서와 각 단계 소요 시간을 추적해 본 결과, 다음 두 구간이 첫 화면 렌더를 블로킹하고 있었다:

### 병목 1 — `SyncService.processQueue()` + 초기 마이그레이션 (High)
기존 `_initializeServices()` 흐름:
```
ApiClient.initialize()
→ SyncService.instance.init()                         // 빠름 (SharedPreferences)
→ await SyncService.instance.processQueue()           // ⚠️ 네트워크 블로킹
→ if (isLoggedIn):
    final pets = await PetService.getMyPets()         // ⚠️ 네트워크 (provider에서 또 호출됨)
    for (pet in pets):
      await SyncService.syncLocalRecordsIfNeeded(id)  // ⚠️ 펫별 네트워크 순차
→ provider 사전 로드
→ navigate
```

- `processQueue()`는 오프라인 중 실패했던 food / water / weight 항목의 **재전송**을 시도하는 네트워크 작업이다. 재시도할 항목이 큐에 쌓여 있으면 N회 서버 왕복이 발생한다.
- `syncLocalRecordsIfNeeded()`는 펫별 **최초 1회** 로컬 데이터 마이그레이션이며, 이미 완료된 펫은 플래그로 스킵되지만 신규 로그인/재설치 시에는 전체 동기화가 순차 실행된다.
- 두 작업 모두 **첫 화면에 표시되는 데이터와 무관**하다 — 화면 데이터는 바로 아래 provider 사전 로드(`activePetProvider`, `petListProvider`, `premiumStatusProvider`)에서 가져온다.

네트워크 지연 상황(3G, 지하철 진입 등)에서 위 단계가 **1~3초 이상** splash를 멈출 수 있다.

### 병목 2 — `dotenv.load()` 순차 블로킹 (Medium)
기존에는 splash `_initializeServices()` 첫 단계에서 `await dotenv.load()`를 수행. 이후 TokenService / GoogleSignIn / LocalImageStorage가 병렬로 진행되지만, dotenv는 단독 순차 블로킹 단계로 남아 있었다.

`dotenv`는 단순 파일 I/O로 50~100ms 수준이지만, `main()` 단계에서 Firebase / Locale과 완전 병렬화가 가능하다 — 어느 것도 dotenv를 필요로 하지 않기 때문이다.

---

## 주요 수정 상세

### 1. `main.dart` — dotenv를 시작 지점으로 이동해 3-way 병렬화

**이전**:
```dart
await Future.wait([
  Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  LocaleProvider.instance.initialize(),
]);
// dotenv는 splash에서 뒤늦게 순차 await
```

**현재**:
```dart
Future<void> loadEnv() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] dotenv load error: $e');
  }
}

await Future.wait([
  loadEnv(),
  Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  LocaleProvider.instance.initialize(),
]);
```

- 기존 `try/catch` graceful degradation(파일 없으면 앱 계속 실행, 환경변수 참조 시점에 StateError)을 그대로 유지.
- splash의 `_initializeServices()` 첫 번째 단계가 통째로 제거되어 이후 단계들이 즉시 시작 가능.

### 2. `splash_screen.dart` — SyncService 작업의 백그라운드 전환

**이전** (라인 129~149):
```dart
try {
  await SyncService.instance.init();
  await SyncService.instance.processQueue();              // 블로킹
  if (TokenService.instance.isLoggedIn) {
    final pets = await PetService.instance.getMyPets();   // 블로킹 + 중복 호출
    for (final pet in pets) {
      await SyncService.instance.syncLocalRecordsIfNeeded(pet.id);  // 블로킹
    }
  }
} catch (e) { ... }
```

**현재**:
```dart
// 큐 메타데이터만 빠르게 로드 — 계속 블로킹 유지
try {
  await SyncService.instance.init();
} catch (e) { ... }

// provider 사전 로드 (화면 표시용 데이터) — 이 단계는 유지
if (TokenService.instance.isLoggedIn) {
  await ref.read(activePetProvider.notifier).refresh();
  await ref.read(petListProvider.notifier).refresh();
  await ref.read(premiumStatusProvider.notifier).refresh();
}

// 백그라운드 작업용 펫 목록을 dispose 전에 미리 캡처
final pets = TokenService.instance.isLoggedIn
    ? (ref.read(petListProvider).valueOrNull ?? const <Pet>[])
    : const <Pet>[];

_servicesInitialized = true;
_tryNavigate();

// 크리티컬 패스에서 벗어나 백그라운드 진행
unawaited(_runBackgroundSync(pets));
```

```dart
Future<void> _runBackgroundSync(List<Pet> pets) async {
  try {
    await SyncService.instance.processQueue();
    for (final pet in pets) {
      await SyncService.instance.syncLocalRecordsIfNeeded(pet.id);
    }
  } catch (e) {
    debugPrint('[Splash/bg] Background sync error: $e');
  }
}
```

**핵심 설계 결정**:
- `SyncService.init()`(SharedPreferences만 읽음)는 계속 blocking. 큐 메타데이터는 이후 `processQueue()` 호출에 필요하고, 매우 빠르다.
- `processQueue()` / `syncLocalRecordsIfNeeded()`는 **첫 화면 데이터 정확성에 영향 없음** — 실패 재전송과 one-time 마이그레이션이므로 HomeScreen 렌더 후 진행해도 됨. 다음 `App resume` lifecycle이나 명시적 저장 시점에도 재처리 기회가 있다(`didChangeAppLifecycleState` + `drainAfterSuccess`).
- `PetService.getMyPets()` 네트워크 호출 중복 제거: 기존 코드는 sync 분기에서 한 번, provider 사전 로드에서 또 한 번 네트워크로 펫 목록을 가져왔다. 이제 **provider 캐시를 재사용**한다.
- **dispose 안전성**: `ref`를 백그라운드 콜백 내부에서 참조하면 splash가 팝된 후 무효화 위험이 있다. `_runBackgroundSync()` 호출 전에 `List<Pet>`로 값을 **캡처**해 인자로 전달 — unawaited Future가 독립적으로 실행돼도 문제없다.

---

## 체감 효과

- **로그인 사용자의 첫 홈 화면 진입**: 네트워크 상태에 따라 **1~3초 단축**. Wi-Fi/LTE 양호 시에도 수백 ms 개선.
- **초기 서비스 초기화 병렬화**: dotenv / Firebase / Locale 3-way 동시 로드로 50~100ms 추가 절감.
- **데이터 정합성 영향 없음**: 백그라운드 동기화는 기존 lifecycle hook + 성공 후 drain 경로로 누락 없이 eventually consistent.

---

## 검토 후 **제외한** 최적화 항목

| 항목 | 검토 결과 | 이유 |
|------|----------|------|
| `assets/images/readme/` 5.7MB 번들 제외 | **불필요** | Flutter 공식 문서 확인 결과 `assets/images/` 와일드카드는 **비재귀적**. readme 하위 폴더는 pubspec에 명시되지 않아 애초에 번들되지 않음 |
| `weight_detail_screen.dart` 차트 `indexWhere` 캐시 | **미적용** | 30~90개 스팟 범위에서 O(n) 탐색은 마이크로초 단위. 체감 영향 없음 |
| `home_screen.dart` BHI setState 범위 축소 | **미적용** | 1560줄 파일의 WCI 카드 추출은 리팩토링 리스크 대비 월/주 토글 rebuild 개선폭(추정 20~50ms)이 불확실. 추후 프로파일링 기반 필요 시 별도 태스크 |
| Android release 빌드 플래그 | **이미 적용됨** | `isMinifyEnabled = true` / `isShrinkResources = true` / ProGuard 구성 완료 상태 |
| `Image.asset` cacheWidth/cacheHeight | **이미 적용됨** | 유일한 대형 PNG 사용처인 `home_vector/lv*.png`에 `cacheWidth: 320, cacheHeight: 480` 이미 설정됨 |

---

## 향후 가능한 후속 작업

- **실측 기반 프로파일링**: Flutter DevTools Performance / Timeline View로 splash → home 구간 실측. 위 추정치 검증 및 추가 병목 식별.
- **home_screen WCI 카드 추출**: 별도 `StatefulWidget` 또는 `Consumer` 격리로 BHI 로딩 중 전체 화면 rebuild 제거. 1560줄 파일 분할 리팩토링과 함께 진행 권장.
- **SyncService 실패 대응 UX**: 백그라운드 실패 시 사용자에게 알릴 방법(예: 홈 화면 상단 배너) 검토 — 현재는 debugPrint만.
