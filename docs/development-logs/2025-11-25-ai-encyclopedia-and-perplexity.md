# AI 백과사전 화면 및 Perplexity 연동

**날짜**: 2025-11-25  
**파일**:
- [lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart](../../lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart)
- [lib/src/services/ai/ai_encyclopedia_service.dart](../../lib/src/services/ai/ai_encyclopedia_service.dart)
- [lib/src/router/app_router.dart](../../lib/src/router/app_router.dart)
- [lib/src/router/route_names.dart](../../lib/src/router/route_names.dart)
- [lib/src/router/route_paths.dart](../../lib/src/router/route_paths.dart)
- [lib/src/screens/home/home_screen.dart](../../lib/src/screens/home/home_screen.dart)
- [pubspec.yaml](../../pubspec.yaml)

## 구현 목표
- 홈의 AI 백과사전 카드를 탭하면 대화형 화면으로 이동하도록 라우팅 연결.
- Perplexity 호스티드 API를 이용해 챗봇 답변을 받아오는 MVP 구성.
- 메시지 전송 UX(로딩, 에러, 자동 스크롤)와 히스토리 포맷을 Perplexity 규격에 맞춤.

## 주요 변경 사항
1. **AI 백과사전 화면 추가**
   - 추천 질문 탭 → 자동 전송, 채팅 버블 UI, 전송 중 로딩, 에러 스낵바, 자동 스크롤을 구현.
   - 처음 안내 assistant 메시지는 히스토리에서 제외하고, user/assistant 번갈아 나오도록 정제 후 API에 전달.

2. **라우팅 및 홈 연결**
   - `ai-encyclopedia` 라우트(이름/경로) 추가 후 홈 하단 카드 탭 시 새 화면으로 이동하도록 연결.

3. **Perplexity 서비스 연동**
   - `AiEncyclopediaService`에서 `POST /chat/completions` 호출, 기본 모델을 `sonar-pro`로 설정하고 `.env`의 `PERPLEXITY_MODEL`로 오버라이드 지원.
   - 시스템 프롬프트로 “앵무새 케어 전문가, 근거 불확실 시 수의사 권장, 5줄 이내” 지침 적용.
   - API 키/베이스 URL은 `.env`에서 읽도록 구성(`PERPLEXITY_API_KEY`, `PERPLEXITY_API_BASE`).

4. **의존성**
   - 외부 호출을 위해 `http: ^1.2.2` 추가.

## 테스트 메모
- `flutter pub get` 실행 완료. Perplexity 호출 시 메시지 교차 규칙 오류를 히스토리 정제 로직으로 해결했음.
