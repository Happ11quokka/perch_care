# Stage 4C — ai_encyclopedia 도메인 MVVM Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** `ai_encyclopedia_screen.dart`(1,169줄)이 직접 든 4개 서비스 싱글턴(AiEncyclopediaService/AiStreamService/ChatStorageService/ChatApiService)과 서버/로컬 병합 정책을 `ChatRepository`로 이동한다. SSE 스트리밍 상태머신·429 처리·l10n 의존은 View에 유지(생명주기·컨텍스트 결합).

**Architecture:** `ChatRepository`가 4개 서비스를 래핑하고 병합/우선순위/무음실패 정책을 소유. 화면은 데이터 조작을 Repository 경유로 하되, **SSE 스트림 소비(placeholder 인덱스·StringBuffer·50ms 쓰로틀 Timer·StreamSubscription)와 429 안내, petProfileContext(l10n) 생성은 View에 유지**. Repository는 `Stream<String>`을 그대로 통과시키고 `ApiException`(429)을 rethrow.

**의도적 범위 축소 (스펙 대비):** 스펙은 "SSE Notifier로 전환 + setState 제거 + 위젯 분할"을 제안했으나, 실측 결과 스트리밍 상태머신이 View 생명주기(Timer/구독/스크롤/placeholder)에 강결합돼 있고 429/에러 문구·프롬프트 컨텍스트가 l10n(BuildContext)에 의존하며 위젯 테스트가 0건이라 **전면 AsyncNotifier 재작성은 고위험·device 검증 불가**. → 서비스 싱글턴 제거 + 병합정책 Repository화까지만 수행하고 스트리밍 상태머신은 View 유지. 위젯 분할·펫전환 반응성 변경은 보류(최종 보고 명시).

**Tech Stack:** Flutter, flutter_riverpod, http(SSE), mocktail.

## Global Constraints

- **behavior-preserving**: UI·SSE 스트리밍·429 안내·무음 실패·펫전환 무반응(현행)·저장 순서 의존성 전부 보존.
- **429 중립 처리 2곳 보존**: 스트림 경로(_handleSend catch, ApiException 429 → quota_limitReachedMessage placeholder 교체 + isSending 해제)와 fallback 경로(_handleFallbackResponse catch, 429 → 동일 처리 후 return, 스낵바 없음). Repository의 streamAnswer/askAnswer는 ApiException을 **rethrow**해 View가 처리.
- **무음 실패 계약**: 세션 생성/메시지 서버저장/로컬저장 실패는 debugPrint 후 무시(대화 계속) — Repository가 이 fire-and-forget을 흡수(예외를 밖으로 던지지 않음). loadConversation만 로컬 폴백 후 결과 반환.
- **저장 순서 의존성 보존**: assistant 메시지 서버 저장이 placeholder 인덱스 초기화 전에 일어나야 함(현행 순서) — View가 순서를 유지하고 Repository는 saveMessageToServer 단순 위임.
- **l10n 의존은 View 유지**: 429/에러 문구, petProfileContext(프롬프트) 생성은 View. Repository는 문자열/에러코드만.
- **펫전환 무반응 보존**: 현재 activePetProvider는 initState에서 ref.read 1회만 — watch/family로 바꾸지 않는다(기존 UX 유지).
- **AsyncViewModel base에는 runLoad만**(runAction 없음).
- **완료 게이트**: `flutter analyze` 신규 0 + `flutter test` 통과. ai_encyclopedia 테스트 0건 → 신설 ChatRepository 단위 테스트가 유일 회귀망.
- 커밋 푸터:
  ```
  Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_0158Ap8HMLzWLTdwufDdJwjA
  ```

## 대상 서비스 시그니처 (실코드 확인)

- `AiStreamService.streamEncyclopedia({required String query, List<Map<String,String>> history, String? petId, double temperature, int maxTokens, String? petProfileContext})→Stream<String>` (401→refresh 1회 재시도, 비200→ApiException throw).
- `AiEncyclopediaService.ask({required String query, List<Map<String,String>> history, String? petId, ..., String? petProfileContext})→Future<String>` (동기 fallback).
- `ChatStorageService.loadMessages(String? petId)→Future<List<ChatMessage>>` / `saveMessages(String? petId, List<ChatMessage>)` / `clearMessages(String? petId)`.
- `ChatApiService.createSession({String? petId, required String firstMessage})→Future<ChatSession>` / `getUserSessions()→Future<List<ChatSession>>` / `getSessionMessages(String sessionId)→Future<List<ChatMessage>>` / `addMessage({required String sessionId, required String role, required String content})→Future<void>` / `deleteSession(String sessionId)→Future<void>`.
- 모델: `ChatMessage(role, text, timestamp, id?, sessionId?)`, `ChatSession(id, petId?, ...)`.

---

## File Structure

**신규:** `lib/src/repositories/chat_repository.dart`, `test/repositories/chat_repository_test.dart`.
**수정:** `lib/src/providers/repository_providers.dart`, `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart`.

---

## Task 1: ChatRepository 신설 (병합 정책 + 데이터 ops + SSE/fallback 통과)

**Files:** Create `lib/src/repositories/chat_repository.dart`, `test/repositories/chat_repository_test.dart`; Modify `repository_providers.dart`.

**Interfaces (Produces):**
```dart
/// loadConversation 결과 — 메시지 + 채택된 서버 세션 id(없으면 null).
class ConversationLoad {
  const ConversationLoad({required this.messages, this.sessionId});
  final List<ChatMessage> messages;
  final String? sessionId;
}

abstract class ChatRepository {
  /// 서버 우선(getUserSessions→petId 매칭 첫 세션→getSessionMessages)+로컬 미러, 실패 시 로컬 폴백.
  Future<ConversationLoad> loadConversation(String? petId);
  Future<void> saveLocal(String? petId, List<ChatMessage> messages);
  /// 서버 세션 생성 — 실패 시 null(무음, 대화 계속).
  Future<ChatSession?> createSession({String? petId, required String firstMessage});
  /// 메시지 서버 저장 — fire-and-forget(실패 삼킴).
  Future<void> saveMessageToServer({required String sessionId, required String role, required String content});
  /// 대화 삭제 — 로컬 clear + (sessionId 있으면) 서버 세션 삭제(무음).
  Future<void> clearConversation({String? petId, String? sessionId});
  /// SSE 토큰 스트림 통과 — ApiException(429 등)은 그대로 전파(View가 처리).
  Stream<String> streamAnswer({required String query, List<Map<String,String>> history, String? petId, String? petProfileContext});
  /// 동기 fallback — 문자열 반환, ApiException 전파.
  Future<String> askAnswer({required String query, List<Map<String,String>> history, String? petId, String? petProfileContext});
}
class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({AiStreamService? stream, AiEncyclopediaService? ai, ChatStorageService? storage, ChatApiService? chatApi});
}
final chatRepositoryProvider = Provider<ChatRepository>((ref) => ChatRepositoryImpl());
```

**구현 규칙 (실코드 정독 후 정확히 복제):**
- `loadConversation(petId)`: try { `sessions = chatApi.getUserSessions()`; `session = sessions.firstWhereOrNull((s) => s.petId == petId)` (실코드의 매칭 로직 — 화면 481-490행 확인); if session != null { `messages = chatApi.getSessionMessages(session.id)`; `storage.saveMessages(petId, messages)`(로컬 미러); return ConversationLoad(messages, sessionId: session.id) } else { fall to local } } catch { } — 서버 실패/세션 없음 → `messages = storage.loadMessages(petId)`; return ConversationLoad(messages, sessionId: null). **화면 _loadMessages(474-520행)의 정확한 우선순위/매칭/미러 로직을 복제.**
- `createSession`: try return `chatApi.createSession(...)`; catch { debugPrint; return null }.
- `saveMessageToServer`: try `chatApi.addMessage(...)`; catch { debugPrint(무음) }.
- `clearConversation`: `storage.clearMessages(petId)`; if sessionId != null { try `chatApi.deleteSession(sessionId)`; catch {} }.
- `saveLocal`: `storage.saveMessages(petId, messages)`.
- `streamAnswer`: `return stream.streamEncyclopedia(...)` (통과 — ApiException은 스트림 에러로 전파).
- `askAnswer`: `return ai.ask(...)` (통과).

- [ ] **Step 1:** ai_encyclopedia_screen의 _loadMessages(474-520)·_handleSend(206-226)·_finishStreaming(283-295)·_clearMessages(528-568) 정독 + 4개 서비스 시그니처 확인.
- [ ] **Step 2: 실패 테스트** `test/repositories/chat_repository_test.dart` (Mock 4서비스): loadConversation(서버성공→미러+sessionId, 서버실패→로컬폴백+null, 세션없음→로컬), createSession(성공/실패→null), saveMessageToServer(실패 삼킴 — throw 안 함), clearConversation(sessionId 유/무), streamAnswer 통과(Stream.value mock), askAnswer 통과. registerFallbackValue 필요 시.
- [ ] **Step 3:** RED → 구현 + provider 등록 → GREEN. **Step 4:** analyze clean + full test. **Step 5: Commit** `|FEAT| ChatRepository 신설 — 서버/로컬 병합정책·세션 CRUD·SSE/fallback 통과(무음실패 흡수)`

---

## Task 2: ai_encyclopedia_screen 전환

**Files:** Modify `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart`.

**전환 규칙:**
1. **서비스 필드 4개 제거**(45-48: _aiService/_streamService/_chatStorage/_chatApi) + import. `chatRepositoryProvider` 사용.
2. **_loadMessages(474-520)** → `final load = await ref.read(chatRepositoryProvider).loadConversation(_activePet?.id); setState { _messages = load.messages; _currentSessionId = load.sessionId; }` (로딩/에러 setState 시맨틱 유지 — 서버우선/로컬폴백 분기가 Repository로 이동했으므로 View는 결과만 반영).
3. **_handleSend 세션/메시지(206-226)**: `_chatApi.createSession` → `ref.read(chatRepositoryProvider).createSession(...)`(null이면 _currentSessionId 유지 null, 기존 무음 동작). `_chatApi.addMessage(user)` → `repo.saveMessageToServer(...)`.
4. **_saveAssistantMessageToServer(305)** → `repo.saveMessageToServer(sessionId:, role:'assistant', content:)`. **placeholder 인덱스 초기화 전 호출 순서 유지**(291행 주석).
5. **_saveMessages(524)** → `repo.saveLocal(_activePet?.id, _messages)`.
6. **_clearMessages(528-568)**: `_chatStorage.clearMessages` + `_chatApi.deleteSession` → `repo.clearConversation(petId: _activePet?.id, sessionId: _currentSessionId)`. 이후 `_currentSessionId=null` 리셋·UI 갱신 유지.
7. **스트리밍(327 streamEncyclopedia)** → `ref.read(chatRepositoryProvider).streamAnswer(query:, history:, petId:, petProfileContext:)`. **listen 로직(316-394: StringBuffer·50ms 쓰로틀 Timer·placeholder append·onDone/onError 플러시·Completer)은 그대로 View 유지.**
8. **fallback(412 ask)** → `repo.askAnswer(...)`.
9. **429 처리 2곳(239-250, 429-438)·에러 문구·petProfileContext(l10n) 전부 View 유지.** streamAnswer/askAnswer가 ApiException을 전파하므로 기존 catch 그대로 동작.
10. **_buildCleanHistory(1141-1168, 순수 로직)**: View 유지 또는 Repository로 이동 선택 — **최소 변경 위해 View 유지**(순수 헬퍼, 서비스 의존 없음).
11. CoachMarkService·AnalyticsService(171 logAiChatSent)·애니메이션 컨트롤러·모든 UI/위젯 헬퍼는 불변.
12. `ref.read(activePetProvider).valueOrNull`(463)은 그대로(펫전환 무반응 보존).

- [ ] **Step 1:** 화면 전체(1,169줄) 정독 — 4서비스 호출 15지점(45-48 필드 + 208/218/305/327/412/481/487/495/505/524/551/555) 목록화.
- [ ] **Step 2:** 규칙 1-12 적용. 스트리밍 상태머신·429·l10n·순서의존성 보존.
- [ ] **Step 3:** `flutter analyze` clean. `grep -nE "AiEncyclopediaService.instance|AiStreamService.instance|ChatStorageService.instance|ChatApiService.instance" ai_encyclopedia_screen.dart` → 0. `grep -nE "_isQuotaExhausted|quota_limitReached|429" ai_encyclopedia_screen.dart` → 429 처리 잔존 확인. `flutter test` 통과.
- [ ] **Step 4: Commit** `|REFACTOR| ai_encyclopedia_screen MVVM 전환 — ChatRepository 경유(병합정책 이동), 스트리밍 상태머신·429·l10n View 유지`

---

## Self-Review (스펙 대비)

- **ChatRepository** (스펙 Stage 4 ai_encyclopedia #1): Task 1 ✅ (4서비스 래핑, 서버·로컬 병합 캡슐화).
- **SSE 스트리밍 Notifier + setState 제거 + 위젯 분할** (#1 후반): **의도적 미채택** — 스트리밍 상태머신의 View 생명주기 강결합 + l10n(BuildContext) 비즈니스 로직 침투 + 위젯 테스트 0건 → 전면 AsyncNotifier 재작성 고위험·device 검증 불가. 서비스 싱글턴 제거 + 병합정책 Repository화까지 수행. 최종 보고에 명시. ⚠️
- **429 중립 2곳 보존** (#3): Task 2 규칙 9 ✅
- **위젯 분할**: 보류(애니메이션 컨트롤러 공유·churn 대비 이득 낮음) — 플래그.

**Placeholder scan:** 없음(구현은 실코드 복제 지시).
**Type consistency:** ChatRepository/ConversationLoad/chatRepositoryProvider, ChatMessage/ChatSession 일관.
**보류/후속:** 스트리밍 AsyncNotifier 전면 전환(device 검증 필요), 위젯 분할, 펫전환 반응성(현행 무반응 보존), _buildPetProfileContext의 l10n→서버 프롬프트 결합(별도 설계).
