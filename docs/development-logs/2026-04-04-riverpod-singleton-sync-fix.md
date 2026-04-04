# Riverpod ↔ Singleton 상태 동기화 버그 ���정 (2026-04-04)

**날짜**: 2026-04-04
**작성자**: Claude Code
**브랜치**: `release/v2.0`
**상태**: 수정 완료 — flutter analyze 통과

---

## 개요

Riverpod 마이그레이션 과정에서 **Provider는 생성했지만 화면에서 Singleton을 직접 호출**하는 패턴이 남아 있어, Riverpod state와 실제 서비스 상태가 동기화되지 않는 버그를 수정.

### 근본 원인

```
[화면] → Singleton.instance.method()  →  Singleton 내부 상태 변경 ✓
[main.dart / 위젯] → ref.watch(provider)  →  Riverpod state 미갱신 ✗  →  UI 리빌드 안 됨 ✗
```

Provider의 Notifier를 통해야 Singleton + Riverpod state가 **동시에** 갱신되는데, 화면이 Singleton을 직접 호출하면 Riverpod 쪽은 갱신되지 않음.

---

## 수정 1: Locale — 언어 변경이 즉시 반영되지 않는 버그

### 증상

프로필 화면에서 언어를 변경해도 앱 전체 UI가 바뀌지 않음. 앱을 재시작해야 변경 사항 적용.

### 원인

- `main.dart`의 `MaterialApp.router`가 `ref.watch(localeNotifierProvider)`로 locale을 감시
- `profile_screen.dart`의 언어 선택 다이얼로그에서 `LocaleProvider.instance.setLocale()`을 직접 호출
- Singleton만 업데이트되고 Riverpod state는 미갱신 → MaterialApp 리빌드 안 됨

### 수정 내용

| 파일 | 변경 |
|------|------|
| `profile_screen.dart` | `LocaleProvider.instance.setLocale(locale)` → `ref.read(localeNotifierProvider.notifier).setLocale(locale)` (4곳) |

---

## 수정 2: Premium — 전체 화면 PremiumService Singleton 직접 호출 제거

### 증상

`premiumStatusProvider`가 SSOT로 정의되었으나, 모든 화면(10개)이 `PremiumService.instance`를 직접 호출. 현재 어떤 화면도 provider를 watch하지 않아 눈에 보이는 버그는 없었지만, provider를 watch하는 코드가 추가되는 순간 locale과 동일한 동기화 버그 발생.

### 수정 내용

#### Provider 확장

`PremiumStatusNotifier`에 `refreshAndGet()` 편의 메서드 추가:

```dart
// lib/src/providers/premium_provider.dart
Future<PremiumStatus> refreshAndGet() async {
  await refresh();
  return state.requireValue;
}
```

#### 마이그레이션 패턴 (3종)

**패턴 A — Simple READ:**
```dart
// Before
final status = await PremiumService.instance.getTier();
// After
final status = await ref.read(premiumStatusProvider.future);
```

**패턴 B — forceRefresh READ:**
```dart
// Before
final status = await PremiumService.instance.getTier(forceRefresh: true);
// After
final status = await ref.read(premiumStatusProvider.notifier).refreshAndGet();
```

**패턴 C — Mutation (activateCode):**
```dart
// Before
final result = await PremiumService.instance.activateCode(code);
// After
final result = await ref.read(premiumStatusProvider.notifier).activateCode(code);
```

#### 파일별 변경 사항

| 파일 | 패턴 | 호출 수 | 비고 |
|------|------|---------|------|
| `premium_provider.dart` | — | — | `refreshAndGet()` 추가 |
| `promo_code_bottom_sheet.dart` | C | 1 | `_premiumService` 필드 제거 |
| `premium_screen.dart` | A | 1 | `_premiumService` 필드 제�� |
| `profile_screen.dart` | A | 1 | |
| `home_screen.dart` | A | 1 | `PremiumStatus` 타입 캐스트로 import 유지 |
| `health_check_main_screen.dart` | A+B | 1 | 조건부 `forceRefresh` → `if` 분기 |
| `health_check_analyzing_screen.dart` | A+B | 3 | 1 read + 2 refreshAndGet |
| `health_check_capture_screen.dart` | A | 1 | |
| `health_check_history_screen.dart` | A | 1 | |
| `vet_summary_screen.dart` | A | 1 | |
| `ai_encyclopedia_screen.dart` | A+B | 3 | `PremiumStatus?` 필드로 import 유지 |

#### Import 정리

- **8개 파일**: `premium_service.dart` → `premium_provider.dart` 교체
- **2개 파일** (`home_screen.dart`, `ai_encyclopedia_screen.dart`): `PremiumStatus` 타입을 직접 참조하므로 `premium_service.dart` 유지 + `premium_provider.dart` 추가

---

## 변경 규모

| 항목 | 수치 |
|------|------|
| 변경 파일 | 12개 |
| Singleton 직접 호출 제거 | 18곳 (locale 4 + premium 14) |
| 신규 파일 | 0개 |
| 신규 메서드 | 1개 (`refreshAndGet`) |

---

## 검증

- `flutter analyze` — No issues found
- 화면 코드에서 `PremiumService.instance` 직접 호출 잔여 0건 확인 (`grep` 검증)
- 화면 코드에서 `LocaleProvider.instance.setLocale` 직접 호출 잔여 0건 확인

### 수동 테스트 시나리오

| 시나리오 | 확인 사항 |
|----------|----------|
| 프로필 > 언어 변경 | 다이얼로그 닫힌 직후 전체 UI 언어 전환 |
| 프로모 코드 활성화 | 활성화 후 프리미엄 상태 즉시 반영 |
| 앱 resume (백그라운드 → 포그라운드) | 건강체크 화면에서 premium 상태 forceRefresh |
| Paywall에서 돌아온 후 | 구매/복원 후 premium 기능 즉시 잠금 해제 |
| 로그아웃 | `ref.invalidate(premiumStatusProvider)` 정상 동작 |
