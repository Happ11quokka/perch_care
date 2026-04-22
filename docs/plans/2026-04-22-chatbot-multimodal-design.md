# 기획서 — 챗봇 멀티모달 입력 전환 (Vision + Chatbot 통합 UX)

> **작성일**: 2026-04-22
> **작업 브랜치**: `feat/chatbot-multimodal`
> **상태**: Draft (승인 대기)

> **목적**: 기존의 "이미지 → 분석 결과"의 선형 Vision 플로우를 **제거**하고, AI 백과사전(챗봇)을 멀티모달 대화창으로 확장해 **단일 진입점**으로 통합한다. 사용자는 채팅 입력창에서 텍스트와 이미지(카메라/갤러리)를 함께 첨부해 AI와 자연스럽게 대화한다.
>
> 기존 `health_check` 화면 5종과 관련 라우트 · i18n 키는 **전부 제거**한다. `ai_encyclopedia` 화면이 유일한 AI 진입점이 된다. 홈 화면의 "AI 카메라 배너"도 새 챗봇 화면으로 리라우팅한다.

---

## 1. 맥락 (Context)

### 현재 문제점
1. AI 비전(Health Check)은 `main → capture → analyzing → result` 4-스텝 선형 플로우. 한 번 분석하고 나면 후속 질문을 하려면 챗봇(AI 백과사전) 화면으로 이동해야 한다 → 문맥이 끊긴다.
2. 챗봇은 텍스트만 지원 → "우리 앵무새 똥 좀 봐줘" 같은 자연스러운 요청에 이미지를 붙일 방법이 없다.
3. 두 기능이 중복된 정보(펫 프로필, 증상 노트, 건강 상태)를 따로 받는다 → UX가 파편화된다.

### 기대 효과 (가설)
- 멀티모달 채팅이 선형 Vision 플로우보다 **재방문·연속질문 비율**이 높을 것.
- "+" 버튼(attachment) 패턴은 ChatGPT / Gemini / Claude.ai 등 업계 표준 → 학습 비용이 낮다.
- 하나의 대화창에 이미지 + 텍스트 + AI 답변이 함께 남으므로 **히스토리의 맥락 보존**이 좋아진다.
- 진입점이 하나로 줄어 홈 화면의 정보 밀도가 낮아지고 사용자 혼란이 감소한다.

### 전환 전략
- **구**: 홈 배너 → Health Check (main → capture → analyzing → result → history)
- **신**: 홈 배너 → AI 챗봇(`ai_encyclopedia`) — 입력창에서 바로 사진 첨부
- 기존 Health Check 이력 화면은 챗봇 세션 히스토리가 대체한다 (`ChatStorageService` 기반 펫별 대화 이력).
- 기존 화면은 같은 PR에서 제거 → 리뷰어가 "무엇이 없어졌는지" 한눈에 확인 가능.

---

## 2. 범위 (Scope)

### In-scope
**신규 멀티모달 입력**
- `ai_encyclopedia_screen.dart` 의 입력창에 **첨부 버튼("+")** 추가
- 카메라 / 갤러리 선택용 **바텀 시트**
- 선택된 이미지 **썸네일 미리보기** (입력창 위, X 버튼으로 제거 가능)
- 이미지 + 텍스트를 **하나의 사용자 메시지**로 전송 → AI 응답 표시
- `ChatMessage` 모델에 `imagePath` 필드 추가 (로컬 파일 경로)
- 이미지 첨부 시 **Vision 쿼터** 차감, 텍스트 전용은 Encyclopedia 쿼터 차감
- 입력 제약: 메시지당 이미지 **1장**, 기존 Health Check와 동일 (최대 1920px, 85% 품질, 10MB, HEIC→JPEG)

**기존 Health Check 제거**
- `lib/src/screens/health_check/` 하위 화면 5종 + `vet_summary_screen.dart` 삭제
- `RouteNames.healthCheck*` 5개 라우트 + `RoutePaths.healthCheck*` 제거
- `app_router.dart` 에서 `healthCheck` 서브트리 제거
- 홈 화면 AI 카메라 배너 `onTap` → `RouteNames.aiEncyclopedia` 로 리라우팅
- `hc_*` i18n 키 (ko/en/zh 3개 arb 각 약 113개) 제거 + 재생성
- `CoachMarkService` 의 `screenHealthCheckMain/History/Result` 상수 제거 (해당 화면 코치마크 단계도)
- `health_check_storage_service.dart` — 챗봇이 재사용하지 않으면 삭제

### Out-of-scope (후속 과제)
- 메시지당 이미지 **여러 장** 첨부
- 영상 · 파일(PDF) 첨부
- 서버 측 채팅 API에 네이티브 멀티파트 필드 추가 (MVP는 클라이언트 브릿지 방식)
- Assistant 말풍선에 이미지 표시 (assistant 역할은 텍스트만)
- 기존 Health Check 히스토리 **마이그레이션** (사용자가 기존에 분석한 레코드 → 챗봇 세션으로 이관) — 별개 과제

---

## 3. 현재 상태 요약

### 챗봇 (AI Encyclopedia)
| 항목 | 경로 |
|------|------|
| 화면 | `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` (1373 lines, `ConsumerStatefulWidget`) |
| 메시지 모델 | `lib/src/models/chat_message.dart` — `id, sessionId, role, text, timestamp` (이미지 필드 없음) |
| API 서비스 | `lib/src/services/chat/chat_api_service.dart` — `POST /chat/sessions/{id}/messages` {role, content} |
| 스트리밍 | `AiStreamService` (SSE, 50ms throttle) |
| 저장소 | `ChatStorageService` (SharedPreferences, 펫별 분리) |
| 입력 UI | `_buildInputArea()` @ line 1188 — Row(TextField + 원형 Send 버튼) |
| 쿼터 | `EncyclopediaQuota` — 월간 텍스트 질의 한도 |

### 비전 (Health Check) — 삭제 대상 인벤토리
| 항목 | 경로 | 처리 |
|------|------|------|
| 메인 | `lib/src/screens/health_check/health_check_main_screen.dart` | **삭제** |
| 캡처 | `lib/src/screens/health_check/health_check_capture_screen.dart` — `image_picker` 사용, 1920px/85%/10MB/HEIC→JPG | **삭제** (로직은 새 위젯에 이식) |
| 분석 | `lib/src/screens/health_check/health_check_analyzing_screen.dart` | **삭제** |
| 결과 | `lib/src/screens/health_check/health_check_result_screen.dart` | **삭제** |
| 이력 | `lib/src/screens/health_check/health_check_history_screen.dart` | **삭제** (챗 세션 히스토리가 대체) |
| 수의사 요약 | `vet_summary_screen.dart` | **삭제** |
| 결과 모델 | `lib/src/models/ai_health_check.dart` — `result: Map`, `confidence_score`, `status` | **유지** — `VisionBridgeService`가 재사용 |
| 서비스 | `lib/src/services/health_check/health_check_service.dart` — `/ai/vision/analyze` 호출 | **유지 + 리팩터** (챗 전용 메서드만 남김) 또는 bridge에 인라인 |
| 이미지 저장 | `services/storage/health_check_storage_service.dart`, `local_image_storage_service.dart` | **검토 후 정리** (챗봇이 안 쓰면 삭제) |
| 쿼터 | `VisionQuota` | **유지** — 이미지 첨부 메시지에 그대로 적용 |
| 쿼터 배지 | `VisionQuotaBadge` 위젯 | **유지** (챗 상단에 필요 시 재사용) |

### 공통 인프라 (재사용)
- `image_picker: ^1.2.1` — pubspec에 이미 설치됨
- `ApiClient.uploadMultipart()` — 멀티파트 업로드 헬퍼 (60s timeout)

---

## 4. 제안 설계 (Proposed Design)

### 4.1 UX 디자인 — 입력창 구조

```
─────────────────────────────────────────────
│  [ 썸네일 64×64  ✕ ]    ← 이미지 첨부 시에만 표시
─────────────────────────────────────────────
│  [ + ]  │  입력하세요…             │  [ ↑ ]
─────────────────────────────────────────────
   └ 첨부     └ TextField              └ Send
```

- **"+" 버튼**: 입력창 **왼쪽**에 44×44 원형, `AppColors.gray100` 배경, `Icons.add` 아이콘
  - 탭 → 바텀 시트: "사진 촬영" / "사진 선택" (Material `showModalBottomSheet`)
  - 이미지 선택 후 `setState(() => _attachedImage = bytes)` + 썸네일 노출
- **썸네일 미리보기**: 입력창 **바로 위** 64×64 `Container` (rounded 12), 오른쪽 위에 X 버튼 (이미지 제거)
- **TextField**: 기존 그대로, `hintText`는 첨부 여부에 따라 분기
  - 이미지 없음: `chatbot_inputHint` ("무엇이든 물어보세요…")
  - 이미지 있음: 신규 키 `chatbot_multimodalHint` ("사진에 대해 질문하거나 그냥 보내세요")
- **Send 버튼**: 기존 그대로. 단 `(_inputController.text.isEmpty && _attachedImage == null)` 이면 비활성화.

### 4.2 데이터 모델 변경

`lib/src/models/chat_message.dart` — `imagePath` 필드 추가:

```dart
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
    this.id,
    this.sessionId,
    this.imagePath,       // ⇐ NEW (로컬 경로 또는 원격 URL)
  });

  final String? imagePath;  // ⇐ NEW

  // fromJson / toJson / copyWith 에도 반영
}
```

- **로컬 경로 기반 (MVP)**: `ImagePicker` 가 반환하는 `XFile.path` 그대로 사용. 세션 동안만 유효.
- **영속화 (옵션)**: 바이트를 base64로 저장하지 않는다. 앱 종료 후 썸네일이 깨져도 OK — 텍스트만 남으면 된다.

### 4.3 전송 플로우 — 클라이언트 브릿지 방식 (MVP)

백엔드 `POST /chat/sessions/{id}/messages` 는 `{role, content}` 만 받는다. 서버 수정 없이 UI 테스트가 가능하도록 **클라이언트에서 Vision API를 먼저 호출**한 뒤, 결과를 챗 프롬프트에 병합하는 방식으로 MVP 를 구현한다.

```
User 입력(text + image)
    │
    ▼
[Quota Pre-Check]  ─ image 있으면 VisionQuota, 없으면 EncyclopediaQuota
    │
    ▼
if (image != null):
    POST /ai/vision/analyze  (범용 엔드포인트: pet-히스토리에 기록 남기지 않음)
      ├ fields: image 파일 + mode=conversational + notes=사용자 텍스트
      └ returns: { result: { summary, ... }, confidence_score, status }
    │
    ▼
Augmented prompt 조립:
    """
    [첨부 이미지 분석]
    {vision summary}
    (confidence: 0.87, status: warning)

    [사용자 질문]
    {user text}
    """
    │
    ▼
POST /chat/sessions/{id}/messages  (기존 API 그대로)
    └ content = augmented prompt
    │
    ▼
Assistant 스트리밍 응답 (기존 SSE 경로)
    │
    ▼
UI:
  • User 말풍선 = 원본 텍스트 + 썸네일 (augmented prompt 가 아니라 원본 text만 노출)
  • Assistant 말풍선 = 스트리밍 텍스트
```

**핵심 결정**

- UI에는 **원본 사용자 입력**만 보이게 한다. Augmented prompt (vision 결과가 합쳐진 긴 텍스트)는 `ChatMessage.text` 에 저장하지 **않고**, 서버 전송 시에만 조합한다.
  - 구현: `ChatMessage.text` = 사용자 원본. 서버 전송용 문자열은 `_composeServerPrompt(original, visionResult)` 로컬 함수에서 합성.
- Vision 실패 시 (네트워크 / 쿼터): 이미지 없이 텍스트만 전송하고, 말풍선에 인라인 경고 표시 ("사진 분석 실패 — 텍스트만 전송됐어요").

### 4.4 쿼터 통합

| 메시지 종류 | 차감 |
|---|---|
| 텍스트만 | `EncyclopediaQuota -1` (기존 그대로) |
| 이미지 + 텍스트 | `VisionQuota -1` + `EncyclopediaQuota -1` |
| 이미지만 (텍스트 공백) | `VisionQuota -1` + `EncyclopediaQuota -1` (AI 에는 "이 사진을 설명해주세요" 기본 프롬프트로 처리) |

- **Pre-check**: Send 탭 직전에 `premiumStatus` 를 읽어 **부족한 쪽 쿼터가 있으면 전송 차단**, 스낵바로 안내.
- **UI 쿼터 배지**: 입력창 위 작은 영역에 `[텍스트 12/30 · 이미지 2/5]` 형태로 병기 (선택 과제, MVP 선택).

### 4.5 홈 화면 AI 카메라 배너 리라우팅

현재 `home_screen.dart:934` 의 배너 `onTap` 은 `RouteNames.healthCheck` 로 이동한다. 이 경로를 **삭제**하므로 배너는 새 챗봇 화면을 연다.

| 구 (Before) | 신 (After) |
|---|---|
| `context.pushNamed(RouteNames.healthCheck)` | `context.pushNamed(RouteNames.aiEncyclopedia)` |
| "AI 건강체크" 라벨 | "AI 챗봇 · 사진 분석" 라벨 (i18n 키 `hc_title` → `chatbot_bannerTitle` 로 교체) |
| 아이콘: 카메라만 | 아이콘: 카메라 + 말풍선 (간단한 조합 or 기존 유지) |

**선택 과제**: 배너에서 진입 시 "+" 바텀 시트를 자동 오픈하는 플래그(`?autoAttach=true`) 지원. MVP 에서는 생략하고 사용자가 직접 첨부 버튼을 누르게 한다.

### 4.6 에러 / 엣지 케이스

| 케이스 | 처리 |
|---|---|
| HEIC 파일 | 캡처 스크린 로직 그대로 복제: 파일명 확장자를 `.jpg` 로 교체 (실제 변환은 서버가) |
| 10MB 초과 | 스낵바 안내, 첨부 거부 |
| Vision API 502 / 타임아웃 | 이미지 없이 텍스트만 전송 + 인라인 경고 |
| 네트워크 오프라인 | 기존 `SyncService` 패턴은 이미지 큐잉까지 커버 안 함 — MVP 는 오프라인 시 "이미지 전송은 온라인 전용" 스낵바 |
| 텍스트 · 이미지 둘 다 공백 | Send 비활성화 |
| 이미지 로드 중 화면 이탈 | `dispose()` 에서 파일 핸들 정리 |

---

## 5. 변경 파일 목록

### 신규
| 파일 | 역할 |
|---|---|
| `lib/src/screens/ai_encyclopedia/widgets/chat_input_multimodal.dart` | 멀티모달 입력 바 위젯 (입력창 + 썸네일 + 첨부 버튼) |
| `lib/src/screens/ai_encyclopedia/widgets/attachment_bottom_sheet.dart` | "사진 촬영 / 사진 선택" 바텀 시트 |
| `lib/src/services/chat/vision_bridge_service.dart` | `/ai/vision/analyze` 호출 + augmented prompt 조립 헬퍼 |
| `test/screens/ai_encyclopedia/chat_input_multimodal_test.dart` | 위젯 테스트 (첨부 / 제거 / 전송 비활성) |
| `test/services/chat/vision_bridge_service_test.dart` | Vision 실패 시 fallback 단위 테스트 |

### 수정
| 파일 | 변경 |
|---|---|
| `lib/src/models/chat_message.dart` | `imagePath` 필드 + `fromJson/toJson/copyWith` 반영 |
| `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` | `_buildInputArea()` 를 새 위젯으로 교체, `_handleSend()` 에 이미지 분기 추가, `_attachedImage` 상태 추가 |
| `lib/src/screens/home/home_screen.dart` | `_buildAiHealthCheckBanner()` 배너 `onTap` → `RouteNames.aiEncyclopedia`, 라벨 키 교체 |
| `lib/src/router/app_router.dart` | `healthCheck` 서브트리(line 246~330 부근) 전체 제거 |
| `lib/src/router/route_names.dart` | `healthCheck`, `healthCheckCapture`, `healthCheckAnalyzing`, `healthCheckResult`, `healthCheckHistory` 상수 5개 제거 |
| `lib/src/router/route_paths.dart` | 동일 5개 경로 상수 제거 |
| `lib/src/services/coach_mark/coach_mark_service.dart` | `screenHealthCheckMain/History/Result` 상수 + 해당 화면 코치마크 단계 제거 |
| `lib/l10n/app_{en,ko,zh}.arb` | 신규 키 추가: `chatbot_multimodalHint`, `chatbot_attachPhoto`, `chatbot_pickFromCamera`, `chatbot_pickFromGallery`, `chatbot_visionFailed`, `chatbot_imageTooLarge`, `chatbot_bannerTitle`. 기존 `hc_*`, `healthCheck_*`, `vet_*` 키 약 113개 일괄 삭제. `flutter gen-l10n` 재실행 |
| `lib/src/services/chat/chat_api_service.dart` | (검토만) 변경 없음 — 기존 `addMessage()` 재사용 |
| `lib/src/services/premium/premium_service.dart` | (검토만) 기존 두 쿼터 그대로 활용 |

### 삭제 (기존 Health Check 제거)
| 파일 | 비고 |
|---|---|
| `lib/src/screens/health_check/health_check_main_screen.dart` | 진입 화면 |
| `lib/src/screens/health_check/health_check_capture_screen.dart` | 이미지 픽 로직은 `chat_input_multimodal.dart` 로 이식 후 삭제 |
| `lib/src/screens/health_check/health_check_analyzing_screen.dart` | 업로드/스트리밍은 `VisionBridgeService` 로 대체 |
| `lib/src/screens/health_check/health_check_result_screen.dart` | 결과 표시는 챗봇 말풍선이 대체 |
| `lib/src/screens/health_check/health_check_history_screen.dart` | 챗 세션 히스토리가 대체 |
| `lib/src/screens/health_check/vet_summary_screen.dart` | 진입 사라지면 dead code |
| `lib/src/services/storage/health_check_storage_service.dart` | 참조 0 확인 후 삭제 |
| `lib/src/services/storage/local_image_storage_service.dart` | 챗봇이 재사용 안 하면 삭제, 재사용하면 유지 (Phase 4 단계 20 에서 판단) |

**참고** — `health_check_service.dart`, `models/ai_health_check.dart` 는 **유지**. Vision 분석 API 호출을 `VisionBridgeService` 가 재사용한다.

---

## 6. 구현 단계 (Phased)

**Phase 0 — 브랜치 & 스펙 확정**
1. `feat/chatbot-multimodal` 브랜치 생성 (main 에서)
2. 본 기획서를 `docs/plans/2026-04-22-chatbot-multimodal-design.md` 로 커밋

**Phase 1 — 모델 & 저장소 (작은 PR)**
3. `ChatMessage` 에 `imagePath` 추가 + 단위 테스트
4. `ChatStorageService` 직렬화 / 역직렬화 검증 (기존 히스토리 호환 유지)

**Phase 2 — 입력 UI 뼈대**
5. `AttachmentBottomSheet` 위젯 (카메라 / 갤러리 2개 옵션)
6. `ChatInputMultimodal` 위젯 — 기존 `_buildInputArea()` 와 시각적 동일, 왼쪽 "+" 버튼만 추가. 아직 전송은 텍스트만.
7. 썸네일 프리뷰 표시 + 제거 버튼
8. i18n 키 추가

**Phase 3 — 전송 통합**
9. `VisionBridgeService` 작성: multipart 업로드 → `AiHealthCheck.result` 의 `summary` / `details` 문자열 추출 → augmented prompt 조립
10. `_handleSend()` 분기: image 있으면 bridge 호출 → 실패 시 텍스트만 전송
11. User 말풍선에 썸네일 표시 (ChatMessage.imagePath 가 있을 때)
12. 쿼터 pre-check 추가

**Phase 4 — 홈 배너 리라우팅 & 기존 Health Check 제거**
13. 홈 배너 `onTap` → `RouteNames.aiEncyclopedia`, 라벨 i18n 키 교체
14. `app_router.dart` 의 `healthCheck` 서브트리 제거
15. `route_names.dart` / `route_paths.dart` 상수 5개 제거
16. `lib/src/screens/health_check/` 화면 6개 파일 일괄 삭제
17. `CoachMarkService` 관련 상수 + 단계 제거
18. `hc_*` / `healthCheck_*` / `vet_*` arb 키 전부 삭제, `flutter gen-l10n` 실행
19. `flutter analyze` 로 unresolved reference 확인, 고아 import 정리
20. `health_check_storage_service.dart`, `local_image_storage_service.dart` 참조 여부 확인 후 삭제 판단

**Phase 5 — 검증 & 지표**
21. Analytics 이벤트: `chat_multimodal_send` (with_image: bool, vision_success: bool, duration_ms). 삭제된 `health_check_*` 이벤트 키는 대시보드에서도 정리.
22. `flutter analyze` 무경고, 기존 테스트 + 신규 테스트 통과
23. 시뮬레이터 iOS / Android 실기기 전체 플로우 테스트
24. QA 체크리스트 (아래) 통과

---

## 7. 검증 (Verification)

### 정적 검사
- `flutter analyze` — 경고 0
- `dart format lib test` — 포맷 통일

### 테스트
- **단위**: `ChatMessage.imagePath` 직렬화, `VisionBridgeService` 성공 / 실패 경로
- **위젯**: `ChatInputMultimodal` — 첨부 없음일 때 Send 비활성, 첨부 후 썸네일 렌더, X 버튼 클릭 시 상태 복원
- **통합 (수동)**: 아래 시나리오를 실기기에서 `flutter run` 후 체크

### QA 체크리스트 (골든 패스 + 엣지)
1. 텍스트만 전송 — 기존과 동일 응답
2. 이미지만 전송 (텍스트 공백) — Vision 분석 결과 기반 응답
3. 이미지 + 텍스트 — augmented prompt 로 응답
4. 큰 이미지 (10MB 초과) — 에러 스낵바, 첨부 거부
5. HEIC 파일 선택 — 정상 업로드 (확장자 교체)
6. 갤러리 취소 버튼 — 상태 변화 없음
7. Vision 쿼터 0 남음 + 이미지 첨부 시도 — 프리미엄 안내 스낵바
8. 오프라인 + 이미지 첨부 시도 — 안내 스낵바
9. Vision 호출 실패 (네트워크) — 이미지 제외 후 텍스트만 전송 + 경고 뱃지
10. 앱 재시작 후 히스토리 조회 — 기존 텍스트 메시지는 그대로, 이미지는 썸네일 없이 텍스트만 (MVP 는 의도된 동작)

### 삭제 검증 (Health Check 제거 확인)
11. 홈 화면 AI 카메라 배너 탭 → 챗봇 화면이 바로 열림 (이전 Health Check main 이 아님)
12. `grep -r "healthCheck"` 결과 0 (라우트 상수 관점, 코치마크 제외) — 단, `ai_health_check.dart` 모델/서비스는 남아 있어야 정상
13. 구 라우트 URL 딥링크 (`/health-check`) → go_router 의 `errorBuilder` 나 404 처리 확인
14. 코치마크 재시작 후 삭제된 단계가 건너뛰어지는지 확인
15. 3개 언어 (ko/en/zh) 에서 `hc_*` 관련 라벨이 어디에도 표시되지 않음

---

## 8. 오픈 질문 (Open Questions)

아래는 구현 착수 전 확정이 필요한 사항. 기본값(제안)을 기재해 두되, 반대 의견 있으면 조정한다.

| # | 질문 | 기본값(제안) |
|---|------|-------------|
| Q1 | 이미지 첨부 시 **active pet 컨텍스트**를 붙일까? (현 챗봇은 펫 프로필을 system prompt 에 주입) | **예, 기존과 동일** — 펫이 없으면 음식 / 일반 모드로 폴백 |
| Q2 | Vision 호출 엔드포인트: pet-연결 `/pets/{petId}/health-checks/analyze` vs 범용 `/ai/vision/analyze`? | **범용 `/ai/vision/analyze`** — 챗봇이 펫별 히스토리에 분석 레코드를 남기지 않음 (UX 는 "대화"에 가깝게) |
| Q3 | 이미지 메시지가 ChatMessage 에 저장될 때 **썸네일을 영속화**할까? | **No (MVP)** — 로컬 경로만, 세션 종료 후 깨져도 OK |
| Q4 | 이미지 + 텍스트 1건 = **쿼터 2개(Vision+Encyclopedia) 차감** vs 1개(Vision 만)? | **2개 차감** — 실제 두 API 호출이 발생 |
| Q5 | Send 버튼 옆에 **취소(중지)** 버튼을 넣을까? (스트리밍 중단) | **Out of scope** — 별도 과제로 분리 |
| Q6 | 바텀 시트 대신 **ActionSheet(iOS) / 다이얼로그(Android)** 중 택일? | **`showModalBottomSheet` 단일** — 플랫폼 분기 생략 |

---

## 9. 대안 (고려 후 기각)

- **안 A: 기존 Health Check 를 병렬 유지** — 초기 안. 두 진입점으로 UI 를 A/B 테스트하자는 제안. 기각 사유: 사용자가 "전환하자" 로 결정. 코드/i18n 중복, 사용자 혼란, 쿼터 이중 차감 위험이 있음.
- **안 B: 챗 서버에 multipart 필드 네이티브 추가** — 백엔드 팀 일정 필요. UI 실험이 목적이므로 MVP 에 과함. 채택 여부는 출시 후 지표 검증 후 결정.
- **안 C: 챗봇을 Health Check 화면에 흡수 (반대 방향)** — Health Check 는 "1장 분석 → 결과" 의 선명한 UX 강점이 있지만, 대화형 확장이 어렵고 학습 비용 높음.
- **안 D: 새 독립 화면 `multimodal_chat_screen.dart` 생성** — 코드 / i18n / 스토리지 중복. 기존 `ai_encyclopedia_screen` 를 확장이 YAGNI 측면에서 우월.

---

## 10. 참고 — 디자인 토큰 & 기존 패턴 재사용

- "+" 버튼: `AppColors.gray100` 배경 + `AppColors.brandPrimary` 아이콘 44×44 (Send 와 동일 크기)
- 썸네일 corner: `AppRadius.md` (12)
- 스낵바: `widgets/app_snack_bar.dart` — `AppSnackBar.error` / `.info` 재사용
- 이미지 픽커 옵션: `maxWidth: 1920, imageQuality: 85, requestFullMetadata: false` — Health Check 캡처 스크린과 동일 세팅
- HEIC 핸들링: `health_check_capture_screen.dart:86-90` 코드 그대로 이식

---

## 11. 완료 정의 (Definition of Done)

- [ ] `feat/chatbot-multimodal` 브랜치에서 PR 오픈
- [ ] 위 15개 QA 체크리스트 전부 통과 (실기기 iOS + Android)
- [ ] `flutter analyze` 클린, 단위 / 위젯 테스트 통과
- [ ] 스펙 문서를 `docs/plans/` 에 커밋
- [ ] 기존 Health Check 관련 파일 / 라우트 / i18n 키 / 코치마크 잔존 0 (grep 검증)
- [ ] 홈 배너 탭 → 챗봇 화면 정상 진입 확인
- [ ] Analytics: `chat_multimodal_send` 수집 시작, `health_check_*` 레거시 키 정리 이슈 오픈
