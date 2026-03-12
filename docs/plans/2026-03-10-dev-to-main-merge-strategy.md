# dev → main 합병 계획 (v2.0 릴리스)

> 작성일: 2026-03-10
> 목표: dev 브랜치의 v2.0 기능을 main(production)에 합병하여 프로덕션 배포
> 예상 소요: 1~2주

---

## 1. 현재 브랜치 상태

| 항목 | main (production) | dev (staging) |
|------|-------------------|---------------|
| Railway 연결 | production | staging |
| 분기 기준 | 커밋 `0932ae9` 이후 7 커밋 | 커밋 `0932ae9` 이후 35+ 커밋 |
| 버전 | 1.4.0+7 | 1.3.0+5 |
| 주요 작업 | 오프라인 큐 SyncService, Apple 로그인 수정, App Store 리뷰 대응 | AI/RAG, 프리미엄/결제, 건강체크, 품종 표준, 건강 요약 카드 |

### main 커밋 목록 (분기 이후)

```
06372b4 |FEAT| HomeScreen 오프라인 큐 동기화 추가 + 버전 1.4.0+7 업데이트
f543e4d |FEAT| SyncService 오프라인 큐 구현 + 코드 리뷰 3차 수정 + 국가 선택 다국어 지원
e98f9ab |FIX| Apple 로그인 버튼 로고 크기 확대 (44→60)
ba9f43b |CHORE| 버전 1.3.1+6 업데이트 (App Store 리뷰 대응 재제출)
3552934 |FIX| Sign in with Apple 버튼 HIG 준수 및 공식 로고 적용
8cd6a46 |FIX| Sign in with Apple 버튼 디자인 가이드라인 준수 (App Store 리젝 대응)
1c27777 |FIX| legal 문제 수정 - 중국 정부에서 gpt, openai 메타데이터에서 표현 금지
```

### dev 주요 기능 (분기 이후)

- Phase 3: 건강 요약 카드 + 주간 인사이트
- Phase 4: pgvector + HyDE 벡터 검색 RAG
- Phase 3 프론트엔드 SSE 스트리밍
- 인앱 구독 결제 시스템 (Monetization Phase 1)
- 건강체크 히스토리 시스템 + 프리미엄 잠금
- 품종 표준 시스템
- AI 채팅 서버 연동
- 관리자 페이지 업그레이드
- 일일 기록 기능 (사료/물/체중)

---

## 2. 접근 방식 비교

| 방식 | 안전성 | 롤백 | 테스트 기회 | main 영향 |
|------|--------|------|------------|-----------|
| **A. Release Branch (추천)** | 높음 | 쉬움 (브랜치 삭제) | 충분 | 없음 |
| B. 직접 PR (dev→main) | 중간 | 어려움 | 부족 | PR 중 main 변경 시 재충돌 |
| C. Cherry-pick | 낮음 | 매우 어려움 | 부족 | dev 히스토리 오염 |

### 추천: Release Branch 전략

- main과 dev 모두 **합병 완료 전까지 영향 없음** — main 핫픽스 계속 가능
- 충돌 해결을 **격리된 환경**에서 진행
- staging에서 **충분한 테스트** 후 main에 반영
- 문제 발생 시 **브랜치 삭제만으로 롤백**

---

## 3. 충돌 분석

### 양쪽 모두 수정된 파일 (27개 — 충돌 위험)

#### 위험도 높음 (수동 합병 필수)

| 파일 | main 변경 | dev 변경 |
|------|----------|----------|
| `lib/src/screens/home/home_screen.dart` | SyncService 통합, `_syncOfflineData()` 추가 | 프리미엄 서비스, 건강 요약 카드, BHI, 인사이트 추가 (329줄 증가) |
| `lib/src/services/api/api_client.dart` | `postAI()`, `_aiTimeout`, `_makeRequest()` timeout 파라미터 | `uploadMultipart()`, `Accept-Language`, `tryRefreshToken()`, `_inferMediaType()` |
| `lib/src/screens/splash/splash_screen.dart` | SyncService.init() + processQueue() 초기화 플로우 | IapService 초기화 + `_isNavigating` 네비게이션 가드 |

#### 위험도 중간 (양쪽 로직 병합 필요)

| 파일 | main 변경 | dev 변경 |
|------|----------|----------|
| `pubspec.yaml` | 1.4.0+7, `image_cropper` 추가 | 1.3.0+5, `in_app_purchase`, `share_plus`, `uuid`, `http_parser` 추가 |
| `lib/main.dart` | 초기화 순서 변경 | 초기화 패턴 변경 |
| `lib/src/screens/login/login_screen.dart` | Apple 로그인 버튼 수정 | OAuth 콜백 핸들링 변경 |
| `lib/src/screens/signup/signup_screen.dart` | 등록 플로우 변경 | 등록 플로우 변경 |
| `lib/src/screens/pet/pet_add_screen.dart` | SyncService enqueue 추가 | 품종 선택 통합 |
| `lib/src/screens/weight/weight_add_screen.dart` | SyncService enqueue 추가 | 저장 로직 변경 |
| `lib/src/screens/weight/weight_record_screen.dart` | SyncService enqueue 추가 | UI 업데이트 |
| `lib/src/services/ai/ai_encyclopedia_service.dart` | AI 서비스 변경 | AI 서비스 변경 |

#### 위험도 낮음 (자동 합병 또는 단순 합집합)

| 파일 | 해결 방법 |
|------|----------|
| `app_en.arb`, `app_ko.arb`, `app_zh.arb` | 번역 키 합집합 (JSON 키 병합) |
| `app_localizations.dart` 등 | arb 해결 후 `flutter gen-l10n`으로 재생성 |
| `.gitignore` | 양쪽 항목 합집합 |
| `pubspec.lock` | `flutter pub get`으로 재생성 |
| `ios/Podfile.lock` | `pod install`로 재생성 |
| `lib/src/data/terms_content.dart` | 내용 비교 후 최신 반영 |
| `lib/src/widgets/analog_time_picker.dart` | dev 우선 |
| `docs/privacy-policy.html` | dev 우선 |
| `assets/images/btn_apple/*` | 양쪽 에셋 모두 포함 |

### main에만 존재하는 파일 (자동 포함, 연동 확인 필요)

| 파일 | 비고 |
|------|------|
| `lib/src/services/sync/sync_service.dart` | 359줄, 오프라인 큐 시스템. 자동 포함되나 dev가 수정한 화면에서 연동 확인 필요 |
| `assets/images/btn_apple/apple_logo_black.svg` | Apple 로그인 에셋 |
| `assets/images/btn_apple/apple_logo_white.svg` | Apple 로그인 에셋 |

### dev에만 존재하는 파일 (80+개, 자동 포함)

충돌 없이 그대로 포함됨 — 백엔드 모델/라우터/서비스, 프론트엔드 화면/위젯/서비스, DB 마이그레이션, 지식 베이스 등

---

## 4. 실행 단계

### Phase 1: 준비 (Day 1)

```bash
# 1. 최신 상태 동기화
git fetch origin

# 2. dev에서 release 브랜치 생성
git checkout dev
git pull origin dev
git checkout -b release/v2.0

# 3. main을 release 브랜치에 합병 (충돌 발생 지점)
git merge origin/main
```

> **왜 `main → release/v2.0` 방향인가?**
> dev 기반 위에 main의 7 커밋만 올리면 되므로 충돌이 최소화된다.
> dev의 80+ 새 파일은 충돌 없이 보존된다.

### Phase 2: 충돌 해결 (Day 1~3)

충돌 해결 순서 — **의존성 → 서비스 → 초기화 → UI → 로컬라이제이션**

#### 계층 1: 설정 파일

| 파일 | 해결 방법 |
|------|----------|
| `pubspec.yaml` | 양쪽 의존성 합집합 + 버전 `2.0.0+8`로 설정 |
| `pubspec.lock` | `git checkout --theirs pubspec.lock` 후 `flutter pub get`으로 재생성 |
| `.gitignore` | 양쪽 항목 합집합 |
| `ios/Podfile.lock` | `cd ios && pod install`로 재생성 |

#### 계층 2: 서비스 레이어

| 파일 | 해결 방법 |
|------|----------|
| `api_client.dart` | **양쪽 코드 모두 유지**: main의 `postAI()` + `_aiTimeout` + dev의 `uploadMultipart()` + `Accept-Language` + `tryRefreshToken()`. `_makeRequest()` 시그니처는 dev 기반에 main의 `timeout` 파라미터 추가 |
| `sync_service.dart` | 자동 포함됨 (main 전용 파일). 연동 포인트만 확인 |
| `ai_encyclopedia_service.dart` | dev 우선, main 고유 변경 있으면 병합 |

#### 계층 3: 초기화 & 진입점

| 파일 | 해결 방법 |
|------|----------|
| `main.dart` | dev 기반 + main의 SyncService 초기화 순서 통합 |
| `splash_screen.dart` | 양쪽 초기화 플로우 통합. 순서: `ApiClient → SyncService.init() → SyncService.processQueue() → IapService → PetService` |

#### 계층 4: UI 화면

| 파일 | 해결 방법 |
|------|----------|
| `home_screen.dart` | dev 기반(프리미엄+건강요약) 위에 main의 `_syncOfflineData()` 메서드 + SyncService import 추가 |
| `login_screen.dart` | dev 기반 + main의 Apple 로그인 수정사항 반영 |
| `signup_screen.dart` | dev 기반 + main의 변경사항 검토 후 병합 |
| `pet_add_screen.dart` | dev 기반 + main의 SyncService enqueue 로직 유지 |
| `weight_add_screen.dart` | dev 기반 + main의 SyncService enqueue 로직 유지 |
| `weight_record_screen.dart` | dev 기반 + main의 SyncService enqueue 로직 유지 |

#### 계층 5: 로컬라이제이션

| 파일 | 해결 방법 |
|------|----------|
| `app_en.arb`, `app_ko.arb`, `app_zh.arb` | 양쪽 번역 키 합집합. 키 충돌 시 dev 우선 |
| `app_localizations.dart` 등 | arb 해결 후 `flutter gen-l10n`으로 자동 재생성 |

#### SyncService 연동 체크리스트

main의 SyncService가 dev의 수정된 화면에서 정상 작동하는지 확인:

- [ ] `splash_screen.dart` — `SyncService.instance.init()` + `processQueue()` 호출 유지
- [ ] `home_screen.dart` — `_syncOfflineData()` 메서드 유지
- [ ] `food_record_screen.dart` — catch 블록의 `SyncService.instance.enqueue()` 확인
- [ ] `water_record_screen.dart` — catch 블록의 `SyncService.instance.enqueue()` 확인
- [ ] `weight_add_screen.dart` — catch 블록의 `SyncService.instance.enqueue()` 확인
- [ ] `weight_record_screen.dart` — catch 블록의 `SyncService.instance.enqueue()` 확인
- [ ] `pet_add_screen.dart` — catch 블록의 `SyncService.instance.enqueue()` 확인

### Phase 3: 빌드 & 검증 (Day 3~5)

```bash
# 1. 의존성 정리
flutter clean && flutter pub get
cd ios && pod install && cd ..

# 2. 코드 분석
flutter analyze

# 3. 로컬라이제이션 재생성
flutter gen-l10n

# 4. 테스트
flutter test

# 5. 빌드 검증
flutter build ios --no-codesign
flutter build apk
```

#### 수동 테스트 체크리스트

- [ ] 앱 시작 → 스플래시 → 로그인 플로우
- [ ] 소셜 로그인 (Google, Apple, Kakao)
- [ ] 펫 등록 + 체중/사료/물 기록
- [ ] **오프라인 모드**: 비행기 모드에서 기록 → 온라인 복귀 시 자동 동기화
- [ ] AI 건강체크 (dev 신규 기능)
- [ ] 프리미엄/결제 (dev 신규 기능)
- [ ] 건강 요약 카드 (dev 신규 기능)
- [ ] 다국어 전환 (한/영/중)

### Phase 4: Staging 배포 & 테스트 (Day 5~7)

```bash
# release/v2.0 브랜치를 staging에 배포
git push origin release/v2.0

# Railway staging 환경에서 백엔드 확인
railway link
railway logs
```

staging에서 백엔드 API + 프론트엔드 통합 테스트 진행

### Phase 5: main 합병 (Day 7~10)

```bash
# 1. PR 생성 (release/v2.0 → main)
gh pr create \
  --base main \
  --head release/v2.0 \
  --title "v2.0 Release: AI 건강체크, 프리미엄, 오프라인 동기화 통합" \
  --body "..."

# 2. PR 리뷰 후 merge (히스토리 보존)
gh pr merge --merge

# 3. main 태그
git checkout main && git pull
git tag -a v2.0.0 -m "v2.0.0 Release"
git push origin v2.0.0

# 4. release 브랜치 정리
git branch -d release/v2.0
git push origin --delete release/v2.0

# 5. dev를 main과 동기화
git checkout dev && git merge main && git push origin dev
```

### Phase 6: Production 배포 (Day 10~14)

```bash
# Railway production 배포 확인
railway environment production
railway logs

# App Store / Play Store 제출
flutter build ios --release
flutter build apk --release
```

---

## 5. 합병 중 main 핫픽스 대응

합병 작업 중에도 main에 긴급 핫픽스가 필요한 경우:

```bash
# 1. main에서 직접 핫픽스 (평소처럼)
git checkout main
git checkout -b hotfix/urgent-fix
# ... 수정 ...
git checkout main && git merge hotfix/urgent-fix
git push origin main

# 2. release 브랜치에 핫픽스 반영
git checkout release/v2.0
git merge origin/main
# 추가 충돌 있으면 해결
```

---

## 6. 롤백 시나리오

| 상황 | 대응 |
|------|------|
| 충돌 해결 중 너무 복잡 | `git merge --abort`로 합병 취소, release 브랜치 삭제 후 재시작 |
| release 브랜치 테스트 실패 | release 브랜치에서 수정, main은 영향 없음 |
| main 합병 후 문제 발견 | `git revert -m 1 <merge-commit>`으로 합병 커밋 되돌리기 |
| production 배포 후 문제 | Railway에서 이전 커밋으로 롤백 + git revert |

---

## 7. 일정 요약

| 기간 | 작업 | 산출물 |
|------|------|--------|
| Day 1 | release/v2.0 생성 + merge 시작 | release 브랜치 |
| Day 1~3 | 27개 파일 충돌 해결 | 충돌 해결 완료 |
| Day 3~5 | flutter analyze + test + build | 빌드 성공 확인 |
| Day 5~7 | staging 배포 + 통합 테스트 | staging 검증 완료 |
| Day 7~10 | PR 생성 + main 합병 + 태그 | v2.0.0 태그 |
| Day 10~14 | production 배포 + 스토어 제출 | v2.0 릴리스 |
