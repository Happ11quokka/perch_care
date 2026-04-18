# 출시 전 사전 점검 — 빌드/데이터/인앱 리뷰 하드닝

**날짜**: 2026-04-18
**배경**: App Store / Play Store 제출 직전 전체 앱 리뷰(Frontend / Backend / Store Readiness)에서 발견한 ship-blocker 및 위험 요소를 코드로 해결 가능한 범위 내에서 모두 반영.
**선행 커밋**: `b271f8a |FIX| App Store 3.1.1 2차 대응 — 프리미엄 흔적 제거 + 월간 한도 UX 전환`
**검증**: `flutter analyze` clean · `flutter test` 169/169 pass.

---

## 변경 파일 (18개)

| 카테고리 | 파일 | 수정 요지 |
|----------|------|----------|
| **빌드/스토어** | `pubspec.yaml` | `version: 2.0.1+1` → `2.0.1+2` (Play Store versionCode 충돌 방지) |
| **빌드/스토어** | `android/app/build.gradle.kts` | 기본 Flutter 템플릿 TODO 주석 블록 제거 (release 가독성) |
| **i18n** | `lib/l10n/app_{ko,en,zh}.arb` | `bottomNav_home/records/chat`, `hc_analysisTimeout` 4개 신규 키 × 3개 언어 |
| **i18n (생성물)** | `lib/l10n/app_localizations{,_ko,_en,_zh}.dart` | `flutter gen-l10n` 재실행 결과 |
| **Review UX** | `lib/src/widgets/bottom_nav_bar.dart` | 하드코딩 `['Home','Records','Chat']` → `AppLocalizations` 키 기반 전환 |
| **Review UX** | `lib/src/screens/weight/weight_add_screen.dart` | 체중 저장 성공 스낵바와 `in_app_review` 팝업이 겹치지 않도록 `logWeightRecorded()` 호출을 800ms 지연 |
| **Review UX** | `lib/src/screens/weight/weight_record_screen.dart` | 동일 패턴의 800ms 지연 |
| **데이터 안전성** | `lib/src/services/weight/weight_service.dart` | `deleteWeightRecord()` 서버 호출 실패 시 로컬 캐시 보존. 404는 idempotent 성공으로 처리해 캐시도 정리 |
| **데이터 안전성** | `lib/src/services/sync/sync_service.dart` | 누적 20회 재시도 도달 시 **silent drop → dead-letter 큐로 이동**. `sync_dead_letter` SharedPreferences 키 신설, `deadLetterItems` 진단 getter 추가 |
| **인증 안전성** | `lib/src/services/api/api_client.dart` | `_refreshToken()` 예외 경로에서도 항상 `Completer.complete` 보장 + `_refreshCompleter = null` 복구. `clearTokens()` 실패 시에도 요청 대기자들이 deadlock되지 않도록 이중 safety |
| **UX 복원력** | `lib/src/screens/health_check/health_check_analyzing_screen.dart` | `TimeoutException` 전용 catch 분기 추가 + 다국어 `hc_analysisTimeout` 메시지 노출. 기존 무한 스피너 대신 구체적 타임아웃 안내 |
| **관찰성** | `lib/src/screens/health_check/health_check_capture_screen.dart` | `_checkPremium()` silent catch에 debugPrint 로깅. 의도된 fail-open 동작은 유지 (쿼터 조회 실패 시 서버 403에 위임) |
| **모델 일관성** | `lib/src/services/premium/premium_service.dart` | `EncyclopediaQuota` / `VisionQuota` `fromJson`에서 `monthlyLimit == -1`(unlimited)일 때 `remaining`이 null이면 `-1`로 fallback해 상태 모순 방지 |

---

## 주요 수정 상세

### 1. SyncService ─ 누적 재시도 초과 시 dead-letter 보관
**이전**: `item.totalRetryCount >= 20` 도달 시 `succeeded.add(item)`만 호출해 큐에서 영구 제거 → 사용자가 오프라인에서 입력한 food / water / weight 레코드가 로그 외 흔적 없이 사라질 수 있음.

**현재**:
- `_deadLetterKey = 'sync_dead_letter'` 상수 신설
- `processQueue()`에서 `totalRetryCount >= _maxTotalRetries` 도달 아이템을 `_deadLetter` 리스트로 이동 후 `_persistDeadLetter()`
- 진단용 `SyncService.instance.deadLetterItems` 제공 → 향후 관리자 화면 / 로그 전송으로 복구 가능

### 2. ApiClient ─ `_refreshToken()` deadlock 하드닝
**이전**: catch 블록 안에서 `_tokenService.clearTokens()`가 먼저 await되고, 그 사이 예외 발생 시 `_refreshCompleter!.complete(false)` 미호출 → 동시에 refresh를 기다리던 다른 요청이 영구 pending.

**현재**:
- 로컬 변수 `completer`로 참조 분리
- `clearTokens()` 호출 자체도 `try/catch (_) {}`로 방어
- `finally` 블록에서 `!completer.isCompleted` 가드로 **어떤 경로로도 대기자 deadlock 없음** 보장

### 3. WeightService.deleteWeightRecord — 404 idempotency
기존 구현은 서버 실패 시 로컬 캐시를 건드리지 않아 데이터는 안전하나, 이미 서버에서 삭제된 레코드(404)를 로컬에서만 갖고 있을 경우 재시도가 영구 차단됐다. `ApiException` statusCode 404는 성공으로 분류해 로컬 캐시를 정리하고 다른 에러 코드는 그대로 rethrow.

### 4. 인앱 리뷰 팝업 UX 분리
`in_app_review`의 `requestReview()`는 iOS `SKStoreReviewController`로 시스템 모달을 띄우는데, 스낵바(`AppSnackBar.success`)와 거의 동시에 호출되면 두 UI가 시각적으로 충돌. 체중 저장 성공 피드백이 먼저 안정화되도록 analytics 호출을 `Future.delayed(Duration(milliseconds: 800))`로 감쌌다. 5회차 체중 저장 시에도 스낵바가 사라진 뒤 리뷰 팝업이 노출된다.

---

## 검증 방법

```bash
flutter analyze               # → No issues found
flutter test                  # → All 169 tests passed
```

오프라인 케이스는 수동 QA 필요:
1. 네트워크 차단 상태에서 체중 삭제 시도 → UI에서 사라지지 않고 에러 전파되는지
2. Sync 큐에 일부러 손상된 item 주입 후 21회째 세션에서 `deadLetterItems`에 쌓이는지
3. 5회차 체중 저장 시 스낵바가 먼저 사라진 뒤 리뷰 팝업이 뜨는지 (배포 빌드에서만 팝업 노출, TestFlight 불가능)

---

## 출시 전 남은 외부 작업 (코드 영역 아님)

1. **App Store ID `6758549078` 일치 확인** — `analytics_service.dart:124` 하드코딩 값과 App Store Connect "Apple ID" 비교
2. **Firebase API 키 회전** — 과거 커밋 히스토리에 `google-services.json` / `GoogleService-Info.plist`가 남아 있으므로 Firebase Console에서 재발급 권장
3. **키스토어 경로 상대경로화 (선택)** — 현재 `key.properties`의 `storeFile`이 iCloud Drive 절대경로. CI/CD 도입 시 `android/keys/upload.jks` 등으로 이관 필요
