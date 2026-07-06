# Stage 4B — health_check 도메인 MVVM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** health_check 6화면의 서비스 직접 호출·raw ApiClient 호출·이중 동기화 오케스트레이션을 `ReportShareService`/`HealthCheckRepository`/`HealthCheckHistoryViewModel` 경유로 전환한다. main/capture는 서버 의존이 없어 전환 대상 아님.

**Architecture:** `ReportShareService`(공유 링크 2종 — raw ApiClient 제거) + `HealthCheckRepository`(analyze/analyzeFood/loadHistory(서버우선+캐시 1회)/delete(로컬+이미지+서버)/saveLocalMirror)가 HealthCheckService+HealthCheckStorageService+LocalImageStorageService를 래핑. history는 `HealthCheckHistoryViewModel`로 전환, analyzing은 **View 생명주기 취소 로직(_cancelled/PopScope/mounted)을 유지**하고 analyze 호출만 Repository 경유(AsyncNotifier 생명주기 불일치 회피). result는 VM 없이 `Repository.saveLocalMirror` fire-and-forget. 화면 간 상태 전달은 현행 go_router extra 유지(라우터 폴백 가드가 이미 안전).

**Tech Stack:** Flutter, flutter_riverpod, share_plus, mocktail.

## Global Constraints

- **behavior-preserving**: UI·네트워크·에러·403 중립 처리·extra 라우팅 계약 불변.
- **403 쿼터 중립 처리 보존**: analyzing 화면의 ApiException 403 → `_isQuotaExhausted` + `quota_limitReachedMessage`/`quota_limitReachedTitle` + 재시도 버튼 숨김. 그대로 유지.
- **화면 간 상태 전달은 go_router extra Map 유지** — 세션 싱글턴/전역 상태로 바꾸지 않는다(딥링크·복원 시 고아 방지, 라우터 타입가드 폴백 유지).
- **analyzing 취소 시맨틱 보존**: `_cancelled` 플래그·`mounted` 체크·PopScope 취소 다이얼로그는 View에 유지. analyze 호출만 Repository 경유.
- **result._saveResult fire-and-forget 보존**: 실패 무음(initState 부수효과) 유지 — await로 바꿔 진입 지연시키지 않는다.
- **HealthCheckStorageService의 _writeLock·max50 FIFO는 서비스 내부 유지** — Repository는 위임만.
- **share_plus sharePositionOrigin(iPad 앵커)은 View 유지** — Repository는 공유 URL 반환까지만.
- **CoachMarkService는 View 직접 호출 허용**(cross-cutting).
- **완료 게이트**: `flutter analyze` 신규 0 + `flutter test` 통과. 도메인 테스트 0건이므로 신설 Repository/VM 단위 테스트가 유일 회귀망 — 충실히 작성.
- 커밋 푸터:
  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  ```

## 대상 서비스 시그니처 (실코드 확인 후)

- `HealthCheckService.analyzeImage({required String petId, required String mode, String? part, String? notes, String? language, required Uint8List imageBytes, required String fileName})→Future<Map<String,dynamic>>`; `analyzeFood({String? notes, String? language, required Uint8List imageBytes, required String fileName})→Future<Map<String,dynamic>>`; `deleteHealthCheck(String checkId, {required String petId})→Future<void>`.
- `HealthCheckStorageService.saveRecord(HealthCheckRecord)`, `getRecords(String? petId)→Future<List<HealthCheckRecord>>`, `deleteRecord(String? petId, String recordId)`, `fetchFromServer(String petId)→Future<List<HealthCheckRecord>>`(내부 ApiClient), `syncWithServer(String petId)`. `HealthCheckRecord` 모델은 이 파일에 정의.
- `LocalImageStorageService.saveImage/deleteImage({required String ownerType, required String ownerId, ...})`, `ImageOwnerType.healthCheck`.
- raw ApiClient (제거 대상): history:166 `delete('/pets/{petId}/health-checks/{id}')`, history:200 `post('/reports/share/health/{petId}?date_from=..&date_to=..')`, vet_summary:35 `post('/reports/share/vet-summary/{petId}')` → 응답 `result['share_url'] as String`.

---

## File Structure

**신규:** `lib/src/services/report_share/report_share_service.dart`(또는 repositories/report_share_repository.dart), `lib/src/repositories/health_check_repository.dart`, `lib/src/view_models/health_check/health_check_history_view_model.dart`, 각 테스트.
**수정:** `repository_providers.dart`/`service_providers.dart`(provider 등록), `health_check_analyzing_screen.dart`, `health_check_result_screen.dart`, `health_check_history_screen.dart`, `vet_summary_screen.dart`.

---

## Task 1: ReportShareService 신설 (raw ApiClient 공유 호출 제거 원료)

**Files:** Create `lib/src/services/report_share/report_share_service.dart` + `lib/src/repositories/report_share_repository.dart` (또는 단일 Repository), `test/...`; Modify provider 등록 파일.

**설계:** 공유는 로컬 캐시가 없으므로 Repository 한 겹이면 충분. `ReportShareRepository`가 `ApiClient`를 주입받아 두 엔드포인트를 호출하고 `share_url`을 반환.

**Interfaces (Produces):**
```dart
abstract class ReportShareRepository {
  Future<String> shareHealthReport({required String petId, required DateTime from, required DateTime to});
  Future<String> shareVetSummary({required String petId});
}
class ReportShareRepositoryImpl implements ReportShareRepository { ReportShareRepositoryImpl({ApiClient? api}); }
final reportShareRepositoryProvider = Provider<ReportShareRepository>((ref) => ReportShareRepositoryImpl());
```
- `shareHealthReport`: `api.post('/reports/share/health/$petId?date_from=${fmt(from)}&date_to=${fmt(to)}')` → `result['share_url'] as String`. 날짜 포맷 `YYYY-MM-DD`(history:200과 동일 — 실코드 확인).
- `shareVetSummary`: `api.post('/reports/share/vet-summary/$petId')` → `result['share_url'] as String`.
- ApiClient는 mock 가능(생성자 주입) — 위임 + share_url 추출 테스트.

- [ ] **Step 1:** history:184-217·vet_summary:22-54 정독 — 정확한 엔드포인트·날짜포맷·응답키 확인.
- [ ] **Step 2: 실패 테스트** — MockApiClient로 두 메서드가 올바른 path·share_url 반환 검증 (registerFallbackValue 불필요, path는 String). 30일 계산은 View 책임이므로 Repository는 from/to를 받는다.
- [ ] **Step 3: 구현 + provider 등록. Step 4: 테스트 PASS + analyze clean + full test. Step 5: Commit** `|FEAT| ReportShareRepository 신설 — 건강리포트·수의사요약 공유링크(raw ApiClient 제거 준비)`

---

## Task 2: HealthCheckRepository 신설

**Files:** Create `lib/src/repositories/health_check_repository.dart` + test; Modify `repository_providers.dart`.

**Interfaces (Produces):**
```dart
abstract class HealthCheckRepository {
  Future<Map<String,dynamic>> analyze({required String petId, required String mode, String? part, String? notes, String? language, required Uint8List imageBytes, required String fileName});
  Future<Map<String,dynamic>> analyzeFood({String? notes, String? language, required Uint8List imageBytes, required String fileName});
  Future<List<HealthCheckRecord>> loadHistory(String petId);   // 서버우선 1회 fetch + 로컬 캐시 갱신, 실패 시 로컬 폴백
  Future<void> delete(HealthCheckRecord record);               // 로컬 레코드+이미지 삭제 + 서버 삭제(best-effort)
  Future<void> saveLocalMirror(HealthCheckRecord record, Uint8List? imageBytes);  // saveRecord + saveImage
}
class HealthCheckRepositoryImpl implements HealthCheckRepository { HealthCheckRepositoryImpl({HealthCheckService? service, HealthCheckStorageService? storage, LocalImageStorageService? imageStorage}); }
final healthCheckRepositoryProvider = Provider<HealthCheckRepository>((ref) => HealthCheckRepositoryImpl());
```
- `analyze`/`analyzeFood`: 서비스 위임(그대로).
- `loadHistory`: **서버우선 1회** — `storage.fetchFromServer(petId)` 성공 시 그 결과 반환 + `storage.syncWithServer` 대신 fetch 결과로 캐시 갱신(기존 화면은 fetchFromServer+syncWithServer 2회 GET → Repository에서 1회로 합침. 단 syncWithServer가 로컬 덮어쓰기까지 하므로, 1회 fetch 후 로컬 반영 로직을 Repository가 담당하거나 storage에 `loadServerFirst` 헬퍼 추가). **실패 시 `storage.getRecords(petId)` 폴백.** — 실코드의 fetchFromServer/syncWithServer 관계 확인 후 2회→1회 최적화가 리스크면 기존 2회 호출을 Repository로 옮기기만 하고 최적화는 보고에 후속으로 남긴다.
- `delete`: `storage.deleteRecord(record.petId, record.id)` + `imageStorage.deleteImage(ownerType: healthCheck, ownerId: record.id)` + `service.deleteHealthCheck(record.id, petId: record.petId!)`(best-effort catch — 기존 raw delete를 서비스 메서드로 대체). record.petId nullable 처리(food 모드 global).
- `saveLocalMirror`: `storage.saveRecord(record)` + imageBytes 있으면 `imageStorage.saveImage(...)`.

- [ ] **Step 1:** history._loadRecords(47-89)·_performDelete(156-182)·result._saveResult(108-161)·HealthCheckStorageService(fetchFromServer/syncWithServer 관계) 정독.
- [ ] **Step 2: 실패 테스트** — Mock 3서비스로 loadHistory(서버성공/서버실패→로컬폴백), delete(3호출), saveLocalMirror(imageBytes 유/무), analyze 위임 검증.
- [ ] **Step 3: 구현 + provider. Step 4: 테스트 PASS + analyze + full test. Step 5: Commit** `|FEAT| HealthCheckRepository 신설 — analyze/loadHistory(서버우선+폴백)/delete(로컬+이미지+서버)/saveLocalMirror`

---

## Task 3: vet_summary_screen 전환 (thin)

**Files:** Modify `lib/src/screens/health_check/vet_summary_screen.dart`.
- `_shareVetSummary`(22-54): raw `ApiClient.instance.post('/reports/share/vet-summary/$petId')` → `ref.read(reportShareRepositoryProvider).shareVetSummary(petId: petId)`. 반환 URL로 `Share.share(...)` (sharePositionOrigin·iPad 앵커 View 유지). `_isSharing` 로컬 상태 유지. ApiClient import 제거.
- [ ] Step 1: 정독. Step 2: 적용. Step 3: analyze clean + `grep ApiClient vet_summary_screen.dart`→0 + full test. Step 4: Commit `|REFACTOR| vet_summary_screen — ReportShareRepository 경유(raw ApiClient 제거)`

---

## Task 4: health_check_result_screen 전환 (saveLocalMirror)

**Files:** Modify `lib/src/screens/health_check/health_check_result_screen.dart`.
- `_saveResult`(108-161): `HealthCheckStorageService.instance.saveRecord(record)` + `LocalImageStorageService.instance.saveImage(...)` → `ref.read(healthCheckRepositoryProvider).saveLocalMirror(record, imageBytes)`. **fire-and-forget + 실패 무음 유지**(initState에서 unawaited 또는 기존 패턴). HealthCheckRecord 조립 로직은 View 유지(서버 메타 → record 매핑). 서비스 직접 import 제거(HealthCheckRecord 타입 import는 유지).
- CoachMarkService(70)는 유지. 나머지 800줄 렌더링 불변.
- [ ] Step 1: _saveResult 정독. Step 2: 적용. Step 3: analyze clean + `grep -n "HealthCheckStorageService.instance\|LocalImageStorageService.instance" result_screen`→0 + full test. Step 4: Commit `|REFACTOR| health_check_result_screen — saveLocalMirror 경유(로컬 미러저장 Repository화)`

---

## Task 5: health_check_analyzing_screen 전환 (analyze만, 취소/403 View 유지)

**Files:** Modify `lib/src/screens/health_check/health_check_analyzing_screen.dart`.
- `_startAnalysis`(71-174): `HealthCheckService.instance.analyzeImage/analyzeFood(...)` → `ref.read(healthCheckRepositoryProvider).analyze(...)/analyzeFood(...)`. 
- **보존(중요):** `_cancelled` 플래그·`mounted` 체크·PopScope 취소 다이얼로그·pushReplacementNamed(extra 서버메타)·403 중립 처리(145-155)·timeout/500 에러 분기 전부 View 유지. Repository는 analyze 호출만 대체(생명주기·에러 UI는 화면 소관).
- food 모드 petId==null 분기 유지(analyzeFood).
- HealthCheckService import 제거.
- [ ] Step 1: _startAnalysis 전체(71-174) 정독. Step 2: analyze 호출부만 Repository 경유로 교체, 나머지 불변. Step 3: analyze clean + `grep "HealthCheckService.instance" analyzing_screen`→0 + full test. Step 4: Commit `|REFACTOR| health_check_analyzing_screen — analyze 호출 HealthCheckRepository 경유(취소/403/에러 View 유지)`

---

## Task 6: health_check_history_screen 전환 (HealthCheckHistoryViewModel)

**Files:** Create `lib/src/view_models/health_check/health_check_history_view_model.dart` + test; Modify `health_check_history_screen.dart`.

**Interfaces (Produces):**
```dart
class HealthCheckHistoryViewModel extends AsyncNotifier<List<HealthCheckRecord>> {
  @override Future<List<HealthCheckRecord>> build();   // ref.watch(activePetViewModelProvider) → repo.loadHistory(petId) (펫 없으면 [])
  Future<void> delete(HealthCheckRecord record);       // repo.delete + state에서 제거(낙관적) 또는 재로드
}
final healthCheckHistoryViewModelProvider = AsyncNotifierProvider<HealthCheckHistoryViewModel, List<HealthCheckRecord>>(HealthCheckHistoryViewModel.new);
```
- `build()`: `ref.watch(activePetViewModelProvider).valueOrNull` → 펫 있으면 `repo.loadHistory(pet.id)`, 없으면 `[]`. **펫 변경 시 watch로 자동 재로드 → 기존 ref.listen(223) 제거.**
- `delete(record)`: `repo.delete(record)` 후 state에서 해당 record 제거(낙관적) — 기존 스와이프 삭제 동작 보존.
- 날짜 그루핑(_groupByDate)은 **View의 파생 표시 로직으로 유지**(state는 flat list, build에서 그룹핑).
- 화면: `_records`/`_isLoading`/`_loadRecords`/`ref.listen` 제거, `ref.watch(healthCheckHistoryViewModelProvider)` 구독. `_shareHealthReport`(184-217)의 raw ApiClient → `ref.read(reportShareRepositoryProvider).shareHealthReport(petId:, from: now-30d, to: now)` (30일 계산은 View). `_performDelete` → `notifier.delete(record)`.
- [ ] Step 1: history_screen 전체 정독(특히 47-89·156-217·223). Step 2: 실패 테스트(Mock HealthCheckRepository + Fake ActivePetVM): build 로드, 펫 변경 재로드, delete. Step 3: VM 구현 + 화면 전환. Step 4: analyze clean + `grep -nE "ApiClient|HealthCheckStorageService.instance|LocalImageStorageService.instance|ref.listen" history_screen`→0(share/delete/load 전부 VM·Repository 경유) + full test. Step 5: Commit `|REFACTOR| health_check_history_screen MVVM 전환 — HealthCheckHistoryViewModel(펫 watch 자동재로드)·ReportShareRepository 경유`

---

## Self-Review (스펙 대비)

- **ReportShareService** (스펙 Stage 4 health_check #1): Task 1 ✅ (raw ApiClient 3곳 중 공유 2곳 제거; delete raw는 T2 Repository가 서비스 메서드로 대체).
- **HealthCheckRepository** (#2): Task 2 ✅
- **캡처→분석→결과→저장 플로우 VM (5화면 상태 공유)**: 스펙은 "플로우용 ViewModel 5화면 상태 공유"를 제안했으나, **매핑 결과 화면 간 상태는 go_router extra로 이미 안전 전달되고 세션 싱글턴 VM은 딥링크/복원 시 고아 위험** → analyze(T5)·history(T6)만 VM/Repository화하고 result는 saveLocalMirror(T4), main/capture는 순수(전환 없음)로 결정. **스펙의 "5화면 공유 VM"에서 의도적으로 벗어남 — 최종 보고 명시.** ⚠️
- **403 중립 보존**: T5 ✅
- main/capture: 서버 의존 없음 → 미전환(정당).

**Placeholder scan:** T2 loadHistory의 "2회→1회 최적화가 리스크면 2회 유지" 는 실코드 판단 지시(플레이스홀더 아님).
**Type consistency:** reportShareRepositoryProvider/healthCheckRepositoryProvider/healthCheckHistoryViewModelProvider, HealthCheckRecord 일관.
**보류/후속:** HealthCheckRecord↔AiHealthCheck 모델 이원화(models/ 승격 보류), loadHistory 2회GET 최적화(리스크 시 후속), HealthCheckStorageService의 API 겸업(fetchFromServer 내부 ApiClient — 경계위반이나 이번 범위는 Repository로 감싸는 데 그침).
