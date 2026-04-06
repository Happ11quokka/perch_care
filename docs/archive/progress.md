# Progress Log — perch_care

## Session: 2026-04-04 — AI 에이전트 정확도 평가
- 챗봇 + 비전 에이전트 전체 코드 분석 완료
- ai_service.py (934줄), embedding_service.py, vector_search_service.py, deepseek_service.py 직독
- 챗봇 P0 4건 / P1 4건 / P2 3건 식별
- 비전 P0 5건 / P1 4건 / P2 3건 식별
- findings.md에 상세 평가 결과 + 개선안 기록

---

# Progress Log — perch_care 체계적 코드 리뷰

## Session: 2026-03-20

### Phase 0: 탐색 & 계획 수립 — COMPLETE
- Explore agent 3개 병렬: 구조, 백엔드, 코드 품질
- 핵심 파일 직독: api_client.dart, error_handler.dart, sync_service.dart
- planning-with-files 스킬로 6단계 계획 수립

### Phase 1: Architecture & State Management — COMPLETE
- home_screen.dart (1493줄), active_pet_notifier.dart, app_router.dart 직독
- 서비스 싱글턴 패턴 감사: 19/28 싱글턴, 7/28 비싱글턴
- 스크린 state 변수 Top 10 분석: OnboardingScreen 149+, AIEncyclopedia 64, WeightDetail 59
- 크로스-스크린 데이터 공유: 10개 스크린이 getActivePet() 독립 호출
- Riverpod 마이그레이션 로드맵 설계

### Phase 2: UI & Design System — COMPLETE
- Color(0x...) 하드코딩 600+ 건 발견
- fontFamily: 'Pretendard' 419건 하드코딩
- 한국어 하드코딩 10+ 건 (i18n 위반)

### Phase 3: Data & Network Layer — COMPLETE
- TokenService: 보안 저장소 + Completer 기반 중복 방지 확인
- API Client: 타임아웃 티어링, 에러 처리 구조 우수
- JSON 직렬화: 수동 패턴 일관, code generation 미사용
- SyncService: 우수한 설계 확인 (중복제거, 비재시도 에러 감지)

### Phase 4: Quality & Polish — COMPLETE
- 테스트: 5개 파일 27 케이스 (14% 커버리지)
- 접근성: Semantics 0건, Tooltip 1건
- ARB: 109키 3언어 완벽 동기화
- debugPrint: 50+ 건 kDebugMode 미가드

### Phase 5: Platform Integration — COMPLETE
- 딥링크: iOS/Android 정상 설정
- FCM: 스트림 관리 우수, 포그라운드 핸들러 빈 상태
- IAP: 우수한 구현 (검증, 재시도, 분석 통합)
- Android 권한 명시적 선언 누락

### Phase 6: Backend Security — COMPLETE (CRITICAL 발견)
- IDOR: record 엔드포인트 4개에서 pet 소유권 미검증 (CRITICAL)
- 비밀번호 초기화: 인메모리 + 4자리 코드 (HIGH)
- JWT Secret: 기본값 약함 (HIGH)
- CORS: 와일드카드 기본값 (MEDIUM)
- Rate Limiting: auth 엔드포인트 미적용 (MEDIUM)

## 5-Question Reboot Check
| Question | Answer |
|----------|--------|
| Where am I? | 모든 Phase 완료, findings.md 작성 중 |
| Where am I going? | 최종 리뷰 결과 정리 및 사용자 전달 |
| What's the goal? | Flutter 19개 스킬 기준 체계적 코드 리뷰 |
| What have I learned? | CRITICAL 보안 이슈 2건, HIGH 6건, MEDIUM 7건 |
| What have I done? | 6단계 전체 리뷰 + findings 문서화 |
