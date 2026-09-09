# 프론트엔드 화면·라우트 전체 검토 — 2026-09-09

검토 결론: **컴파일 성공과 실제 사용 흐름의 정상 동작은 별개이며, 인증 갱신·펫 상태·안내 오버레이·오류 복구에서 재현 가능한 문제가 있다.** 특히 비활성 AI 탭의 코치마크가 홈의 터치를 가로채는 현상은 “오류는 없지만 버튼이 동작하지 않는다”는 증상을 설명할 수 있다. 사용자가 겪은 정확한 기기·순서는 미제공이므로 동일 원인이라고 단정하지 않는다.

## 수정 현황 (2026-09-09, 브랜치 `fix/audit-2026-09-09`)

17개 발견 사항을 현재 코드에서 재검증했다. 진단 프로브의 기능 실패 8건과 overflow 13조건은 모두 그대로 재현됐고, 코드 검토 항목(F07·F10·F12·F16·F17)도 근거가 확인됐다. 결정이 필요 없는 항목은 수정했고, 정책·계약이 걸린 항목은 결정 대기로 남겼다.

| 항목 | 상태 | 비고 |
|---|---|---|
| F01 F02 | 수정 | api_client 재시도 헤더 재생성, refresh는 401/403만 세션 삭제 |
| F03 | 수정 | 로그인 성공 시 활성 펫·펫 목록 즉시 재로드, 알림 lazy 무효화 |
| F04 | 수정 | 수분·식사·체중·AI 화면이 활성 펫 로딩/전환 구독, 시퀀스 가드 |
| F05 | 수정 | CoachMarkOverlay.show() 가시성 가드, 경로 변경 시 자동 dismiss |
| F06 | 수정 | HomeViewModel.retry(), 홈·체중 상세·펫 목록 오류+재시도 UI |
| F08 F09 | 수정 | 인증번호 칸 가용 폭 계산, 7개 화면 고정 높이/폭 제거, 병원 요약 스크롤 |
| F13 F14 F15 | 수정 | 스플래시 provider.future 1회 대기, 알림 폴링 실패 시 목록 유지, popOrGo |
| F17(문구) | 수정 | 오전/오후·펫 나이·요일·접근성 라벨 22키 ko/en/zh |
| F07 | 결정 대기 | 백엔드 User에 gender/phone 없음 — 필드 추가 vs 입력 제거 |
| F10 | 결정 대기 | Android Apple 로그인 — Service ID 구성 vs 버튼 숨김 |
| F11 | 결정 대기 | 브랜드색 대비 — 색 변경 vs 텍스트 토큰만 조정 |
| F12 | 결정 대기 | Firebase 초기화 실패 비치명화·지원 플랫폼 명시 |
| F16 | 결정 대기 | 호출처 없는 /home/pet/profile 라우트 삭제 여부 |
| F17(폰트) | 결정 대기 | Pretendard 자산 등록 vs 시스템 폰트 정책 |

검증: `flutter analyze` 무결점, `flutter test` 393개 통과, 진단 프로브 13/13 통과(overflow 0). 실기기·실서버 검증은 미실시.

## 검토 범위와 증거

- 화면 구현 **32개**, GoRoute **34개**(공개 9개, 보호 25개)를 정리했다. `TermsDetailScreen`, `WeightAddScreen`은 복수 라우트에서 재사용한다.
- 네이티브 부팅이 필요한 스플래시는 코드로 검토했다. 나머지 **33개 라우트 × 4환경 = 132개 렌더링 조건**을 실제 라우트 builder와 StatefulShellRoute로 검사했다.
- 환경: 한국어 390×844, 영어 320×568, 한국어 390×844 글자 200%, 중국어 390×844. DPR 1, 키보드 없음, reduced motion 활성화.
- 라우트 보호 검사에는 앱의 실제 top-level redirect를 사용했다. 렌더링 검사에서는 인증 redirect를 분리하고 화면 자체를 열었다.
- API 재요청 테스트는 실제 ApiClient + MockClient, 상태 테스트는 실제 ViewModel 또는 실제 화면 + 대체 Repository를 사용했다. 정상 렌더링 행은 실서버 기능 통과를 뜻하지 않는다.
- Firebase는 테스트용 초기화, 펫·홈·기록·채팅·이미지 저장소는 합성 데이터/대체 객체를 사용했다. 프로필 이미지의 직접 싱글톤 I/O는 실기기에서 추가 확인해야 한다.
- macOS에 설치된 Apple SD Gothic Neo를 테스트의 Pretendard 이름으로 로드해 Ahem 테스트 폰트로 인한 오검출을 줄였다. 앱에 Pretendard가 등록되어 있다는 의미는 아니다. 중국어 글리프의 세밀한 시각 품질은 판정하지 않았다.
- 실기기의 콜드 스타트, OAuth 공급자 인증, 카메라·앨범 권한, 푸시, 실제 AI 분석·서버 저장·공유·회원 탈퇴는 실행하지 않았다. 백엔드/운영 데이터 변경 없음.

## 검증 결과

| 검사 | 결과 |
|---|---|
| 정적 분석 | 이전 턴의 Cupertino import 호환성 수정 후 오류 없음; 이번 진단 소스도 최종 정적 분석 확인 |
| 기존 기본 테스트 | 297개 통과(최종 별도 실행 결과 기준) |
| 비로그인 보호 라우트 | 25/25 로그인으로 이동 |
| 화면 렌더링 조건 | 119/132에서 검출 오류 없음, 13/132에서 overflow 검출 |
| 기능 재현 테스트 | 8개 기대 동작 실패를 재현 — F01/F02/F03/F04(2개)/F05/F06/F15 |
| 진단 테스트 그룹 | 보호 경로 1개 통과, 기능 8개+렌더링 그룹 4개 실패. 이를 기존 테스트 297개의 실패로 혼동하면 안 됨 |

진단 테스트는 **정상이어야 할 동작을 assert하는 실패 재현용**이다. 기본 `test/` 밖에 저장하여 기존 테스트 실행과 구분했다. 현재 코드를 고치기 전에는 진단 명령이 실패하는 것이 예상 결과다.

```sh
flutter test docs/audits/2026-09-09/frontend_probe_test.dart --reporter expanded
flutter analyze --no-pub
flutter test --no-pub
```

[재현 테스트](frontend_probe_test.dart) · [원시 렌더링 결과](route-results.json) · [최종 테스트 로그](probe-output.txt)

## 기술 품질 점수

안티패턴 판정: **브랜드 방향은 유지할 만함.** 오렌지·반려조 일러스트·기록 중심 구성이 기존 디자인 맥락에 맞는다. 카드형 UI와 밝은 테마는 프로젝트의 명시적 방향이므로 그 자체를 결함으로 보지 않았다. 다만 카드의 고정 높이, 장식 그라데이션과 낮은 대비가 실제 가독성·확대 대응을 해치는 곳이 있다. 전체 시각 디자인을 사람의 실제 기기 사용처럼 평가한 점수는 아니다.

| 영역 | 점수 /4 | 근거 |
|---|---:|---|
| 접근성 | 1 | 활성 버튼 대비 부족, 글자 2배에서 정보 잘림; VoiceOver/TalkBack 전수 검증은 미실시 |
| 성능 | 2 | 스플래시 서버 대기·중복 사전조회; 캐시/재사용 HTTP/SSE 쓰로틀링은 있음. 프레임 시간은 미측정 |
| 반응형 | 1 | 기본 폭 인증코드 및 작은 화면/확대 환경의 overflow 재현 |
| 테마 | 3 | 공용 토큰과 브랜드 일관성 있음. 폰트 미등록·텍스트 대비 보완 필요. 다크 모드는 제품 범위 밖 |
| 디자인 안티패턴 | 3 | 브랜드 맥락은 명확; 일부 카드/장식 중심 구성이 공간 제약에서 문제 |
| **합계** | **10/20** | **Acceptable — 중요한 개선 필요. 인증/저장 기능 위험은 이 디자인 점수와 별도로 판단** |


## 우선순위별 발견 사항

총 **17개 원인 그룹: P0 0 / P1 11 / P2 6 / P3 0**. 조건부·특정 플랫폼 문제를 앱 전체 P0 장애로 과장하지 않았다. 단순 스타일 취향은 별도 결함으로 세지 않았다.


### F01 [P1] 토큰 갱신 뒤 POST가 이전 토큰으로 재전송됨

- 범주: 인증 / 데이터 저장
- 위치: [api_client.dart:71](/Users/imdonghyeon/perch_care/lib/src/services/api/api_client.dart:71)
- 증거: 재현: POST → 401 → refresh 200 → POST 401. 저장 토큰은 new지만 요청 헤더는 [Bearer old, Bearer old].
- 사용자 영향: 오래 앱을 켜둔 뒤 펫 생성, AI 세션 생성 등 인증 POST 작업이 실패한다. 사용자가 다시 누르면 이미 갱신된 토큰을 사용해 성공할 수 있어 간헐적 오류로 보인다.
- 조치: 재시도 콜백 안에서 현재 토큰으로 헤더를 새로 생성한다. GET/PUT/POST를 함께 검증한다. /harden


### F02 [P1] 일시적인 통신 실패가 로그인 세션 삭제로 이어짐

- 범주: 인증 / 복구
- 위치: [api_client.dart:218](/Users/imdonghyeon/perch_care/lib/src/services/api/api_client.dart:218) · [app_router.dart:108](/Users/imdonghyeon/perch_care/lib/src/router/app_router.dart:108)
- 증거: 재현: 인증 GET의 401 이후 refresh에서 ClientException을 발생시키자 refreshToken이 null로 변경됨.
- 사용자 영향: 지하철·오프라인 등에서 세션이 삭제된다. 라우터가 토큰 변경을 구독하지 않아 현재 화면은 남고, 다음 화면 이동 때 갑자기 로그인으로 이동할 수 있다.
- 조치: 명시적인 refresh 자격 거절과 네트워크/5xx를 구분한다. 일시 실패에는 토큰을 유지하고 재시도 상태를 알린다. 인증 상태 변경을 라우터에 연결한다. /harden


### F03 [P1] 로그인 후 기존 펫 Provider 상태를 다시 불러오지 않음

- 범주: 인증 / 상태 관리
- 위치: [auth_view_model.dart:22](/Users/imdonghyeon/perch_care/lib/src/view_models/auth/auth_view_model.dart:22) · [auth_view_model.dart:68](/Users/imdonghyeon/perch_care/lib/src/view_models/auth/auth_view_model.dart:68)
- 증거: 재현: 로그인 전 activePet=null 로드 → 로그인 결과 hasPets=true → activePet은 계속 null.
- 사용자 영향: 로그아웃 과정에서 재평가된 빈 상태·에러가 다음 로그인에도 남을 수 있다. 홈·기록·프로필이 펫 없는 상태처럼 보인다. 로그인 전 Provider가 이미 생성된 경우에 해당한다.
- 조치: 인증 성공 후 세션에 종속된 Provider를 일관되게 무효화한다. 이메일/Google/Apple, 계정 변경, 회원 탈퇴 후 재로그인을 같은 정책으로 처리한다. /harden


### F04 [P1] 기록 화면과 AI가 활성 펫의 첫 값만 사용함

- 범주: 기록 / 데이터 일관성
- 위치: [water_record_screen.dart:52](/Users/imdonghyeon/perch_care/lib/src/screens/water/water_record_screen.dart:52) · [water_record_screen.dart:119](/Users/imdonghyeon/perch_care/lib/src/screens/water/water_record_screen.dart:119) · [food_record_screen.dart:58](/Users/imdonghyeon/perch_care/lib/src/screens/food/food_record_screen.dart:58) · [weight_add_screen.dart:74](/Users/imdonghyeon/perch_care/lib/src/screens/weight/weight_add_screen.dart:74) · [ai_encyclopedia_screen.dart:487](/Users/imdonghyeon/perch_care/lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart:487)
- 증거: 재현 1: 수분 화면 진입 시 펫 로딩 중 → 이후 펫 완료 → loadByDate 호출 0회. 재현 2: AI 진입(A) → 활성 펫 B로 변경 → loadConversation(A)만 호출됨.
- 사용자 영향: 늦게 로드된 펫이 반영되지 않아 기록을 못 한다. 수분 저장은 petId가 null이면 아무 작업 없이 반환한 뒤 성공 안내를 띄운다. 유지되는 AI 탭은 이전 펫의 프로필·대화로 질문을 전송한다.
- 조치: 펫 id를 구독하고 로딩/없음/실패를 구분한다. 펫 전환 시 기록 및 AI 세션을 다시 로드하며 진행 중 요청의 이전 결과를 폐기한다. petId 없는 저장은 성공 안내를 띄우지 않는다. /harden


### F05 [P1] 비활성 탭의 코치마크가 현재 화면을 덮음

- 범주: 라우팅 / 터치 입력
- 위치: [ai_encyclopedia_screen.dart:137](/Users/imdonghyeon/perch_care/lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart:137) · [coach_mark_overlay.dart:43](/Users/imdonghyeon/perch_care/lib/src/widgets/coach_mark_overlay.dart:43) · [coach_mark_overlay.dart:267](/Users/imdonghyeon/perch_care/lib/src/widgets/coach_mark_overlay.dart:267) · [app_router.dart:514](/Users/imdonghyeon/perch_care/lib/src/router/app_router.dart:514)
- 증거: 재현: AI 첫 진입 직후 홈으로 이동 → AI 코치마크 문구가 홈 위에 나타남.
- 사용자 영향: 탭은 상태를 유지하므로 mounted가 true여도 보이는 화면은 아니다. 루트 Overlay의 전체 화면 GestureDetector가 현재 화면 버튼 대신 터치를 받는다. 앱이 반응하지 않는다는 증상과 직접 연결된다.
- 조치: 안내 표시 전 현재 활성 탭과 최상위 경로를 확인하고, 경로 전환 시 안내를 닫는다. 지연 콜백에도 유효성 확인을 적용한다. /harden


### F06 [P1] 홈 첫 조회 실패 이후 당겨서 새로고침이 복구하지 못함

- 범주: 로딩 / 오류 처리
- 위치: [home_view_model.dart:160](/Users/imdonghyeon/perch_care/lib/src/view_models/home/home_view_model.dart:160) · [home_screen.dart:233](/Users/imdonghyeon/perch_care/lib/src/screens/home/home_screen.dart:233) · [weight_detail_screen.dart:202](/Users/imdonghyeon/perch_care/lib/src/screens/weight/weight_detail_screen.dart:202) · [pet_profile_screen.dart:133](/Users/imdonghyeon/perch_care/lib/src/screens/pet/pet_profile_screen.dart:133)
- 증거: 재현: 첫 loadPetWithBhi 실패 → 다음 요청은 성공하도록 변경 → pullToRefresh 호출 → hasError=true 유지.
- 사용자 영향: 홈은 오류를 빈 HomeState로 표시하고, 새로고침은 current.activePet이 없으면 즉시 반환한다. 기록 탭은 오류를 펫 없음으로, 펫 목록은 오류를 빈 위젯으로 표시하는 유사 패턴이 있다.
- 조치: 초기 오류 화면과 재시도 동작을 제공한다. 홈 데이터가 없을 때는 활성 펫 및 초기 데이터를 다시 불러온다. 서버 실패를 펫 없음과 구분한다. /harden


### F07 [P1] 프로필의 성별·전화번호 입력이 저장되지 않음

- 범주: 폼 / 데이터 저장
- 위치: [profile_setup_screen.dart:176](/Users/imdonghyeon/perch_care/lib/src/screens/profile_setup/profile_setup_screen.dart:176) · [profile_setup_screen.dart:705](/Users/imdonghyeon/perch_care/lib/src/screens/profile_setup/profile_setup_screen.dart:705) · [profile_setup_screen.dart:74](/Users/imdonghyeon/perch_care/lib/src/screens/profile_setup/profile_setup_screen.dart:74)
- 증거: 코드 확인: 화면은 성별, 국가 전화코드, 전화번호를 입력받지만 _handleComplete는 nickname만 전달한다. 다시 불러오는 값도 email/nickname뿐이다.
- 사용자 영향: 입력완료 후 복귀는 성공하지만 성별·전화번호가 사라진다. 초기 설정과 기존 사용자 프로필 수정 모두 영향받는다.
- 조치: 지원할 필드를 명확히 정하고 저장/조회 계약을 연결한다. 지원하지 않는 필드는 입력받지 않도록 한다. 이메일은 계정 값으로 읽기 전용 정책을 일관되게 적용한다. /harden


### F08 [P1] 인증번호 6칸이 일반 휴대폰 화면 밖으로 넘침

- 범주: 반응형 / 입력
- 위치: [forgot_password_code_screen.dart:202](/Users/imdonghyeon/perch_care/lib/src/screens/forgot_password/forgot_password_code_screen.dart:202)
- 증거: 재현: 390px 화면에서 오른쪽 46px, 320px 화면에서 116px overflow. 한/영/중 및 글자 확대에서 확인.
- 사용자 영향: 6×52px + 5×12px = 372px인데 부모의 좌우 32px 여백을 제외하면 390px 화면에서 326px만 사용할 수 있다. 마지막 입력칸이 잘려 비밀번호 재설정이 어려워진다.
- 조치: LayoutBuilder/Expanded로 칸 폭을 가용 폭에 맞춘다. 코드 붙여넣기·자동완성 및 좁은 화면에서 마지막 칸 접근까지 검사한다. /adapt


### F09 [P1] 작은 화면·글자 확대에서 정보와 버튼이 잘림

- 범주: 반응형 / 접근성
- 위치: [vet_summary_screen.dart:77](/Users/imdonghyeon/perch_care/lib/src/screens/health_check/vet_summary_screen.dart:77) · [home_screen.dart:228](/Users/imdonghyeon/perch_care/lib/src/screens/home/home_screen.dart:228) · [profile_screen.dart:284](/Users/imdonghyeon/perch_care/lib/src/screens/profile/profile_screen.dart:284) · [email_login_screen.dart:111](/Users/imdonghyeon/perch_care/lib/src/screens/login/email_login_screen.dart:111)
- 증거: 재현: 영어 320×568에서 홈/BHI/병원 요약, 한국어 390×844 글자 2배에서 홈/프로필/펫 등록/건강체크 촬영/병원 요약/이메일 로그인에 overflow. F08은 별도 집계.
- 사용자 영향: 병원 요약은 영어 작은 화면에서 아래로 85px 넘쳐 하단 내용과 공유 버튼 접근이 어려워진다. 큰 글자 사용자에게 카드와 버튼 설명이 잘린다.
- 조치: 고정 높이 카드·Row를 Wrap/Flexible 및 내용 기반 높이로 바꾸고 병원 요약을 스크롤 가능하게 한다. 키보드와 실제 기기 글자 확대도 검증한다. WCAG 1.4.4/1.4.10을 참조한다. /adapt


### F10 [P1] Android에서도 노출되는 Apple 로그인에 필수 설정이 없음

- 범주: 플랫폼 / 인증
- 위치: [auth_repository.dart:192](/Users/imdonghyeon/perch_care/lib/src/repositories/auth_repository.dart:192) · [login_screen.dart:155](/Users/imdonghyeon/perch_care/lib/src/screens/login/login_screen.dart:155) · [profile_screen.dart:160](/Users/imdonghyeon/perch_care/lib/src/screens/profile/profile_screen.dart:160)
- 증거: 앱 코드 및 설치된 sign_in_with_apple_platform_interface 2.0.0 소스 확인: Android에서는 webAuthenticationOptions가 없으면 예외를 던지는데 호출부에 전달하지 않음. Android 실기기 로그인은 미실행.
- 사용자 영향: Android의 Apple 로그인과 프로필 계정 연결은 설정 없이 호출되어 진행할 수 없다. iOS 네이티브 로그인과 구분해야 한다.
- 조치: Android용 Service ID/redirect URI와 네이티브 콜백을 연결하거나 해당 플랫폼에서 제공 가능한 로그인 수단만 노출한다. /harden


### F11 [P1] 주요 버튼과 보조 텍스트의 색 대비 부족

- 범주: 접근성 / 테마
- 위치: [colors.dart:8](/Users/imdonghyeon/perch_care/lib/src/theme/colors.dart:8) · [colors.dart:64](/Users/imdonghyeon/perch_care/lib/src/theme/colors.dart:64) · [forgot_password_code_screen.dart:277](/Users/imdonghyeon/perch_care/lib/src/screens/forgot_password/forgot_password_code_screen.dart:277) · [vet_summary_screen.dart:142](/Users/imdonghyeon/perch_care/lib/src/screens/health_check/vet_summary_screen.dart:142)
- 증거: 색상 상대휘도 계산: 흰색↔brandPrimary 2.11:1, 흰색↔brandDark 2.57:1, 흰색↔warmGray 3.09:1.
- 사용자 영향: 흰 글씨 주황 버튼과 작은 회색 안내문은 읽기 어렵다. 활성 버튼 텍스트 기준 WCAG 일반 텍스트 4.5:1에 못 미친다. 단순 장식·비활성 컨트롤은 동일 기준으로 판정하지 않았다.
- 조치: 브랜드 배경 위에는 대비를 확보한 글자색을 쓰거나 버튼 배경을 어둡게 한다. 본문용 보조 텍스트 토큰을 별도로 조정한다. /normalize


### F12 [P2] 시작 전 Firebase 실패를 처리하지 않으며 데스크톱·웹 설정이 없음

- 범주: 시작 / 플랫폼
- 위치: [main.dart:40](/Users/imdonghyeon/perch_care/lib/main.dart:40) · [firebase_options.dart:19](/Users/imdonghyeon/perch_care/lib/firebase_options.dart:19) · [analytics_service.dart:9](/Users/imdonghyeon/perch_care/lib/src/services/analytics/analytics_service.dart:9)
- 증거: 코드 확인: runApp 전에 Firebase.initializeApp을 Future.wait로 기다리며 예외 화면이 없다. 현재 firebase_options.dart는 web/macOS/windows/linux에서 UnsupportedError를 던짐.
- 사용자 영향: 현재 구성으로 Chrome/macOS를 선택하면 앱 UI 전에 중단된다. iOS/Android에서도 초기화 예외가 생기면 복구 UI가 없다. 이는 모든 iOS 실행이 실패한다는 뜻은 아니다.
- 조치: 지원 플랫폼을 실행 안내에 명시한다. Firebase 의존성을 선택 기능과 필수 기능으로 나누고 초기화 실패 시 재시도 또는 사용 가능한 UI를 제공한다. Analytics observer의 의존성도 함께 처리한다. /harden


### F13 [P2] 스플래시가 서버 조회까지 기다리고 첫 조회가 중복됨

- 범주: 시작 / 성능
- 위치: [splash_screen.dart:144](/Users/imdonghyeon/perch_care/lib/src/screens/splash/splash_screen.dart:144) · [active_pet_view_model.dart:21](/Users/imdonghyeon/perch_care/lib/src/view_models/pet/active_pet_view_model.dart:21) · [pet_list_view_model.dart:16](/Users/imdonghyeon/perch_care/lib/src/view_models/pet/pet_list_view_model.dart:16) · [api_client.dart:29](/Users/imdonghyeon/perch_care/lib/src/services/api/api_client.dart:29)
- 증거: 코드 확인: 로그인 상태이면 activePet/petList notifier.refresh를 await한다. notifier 첫 read는 build 조회도 시작하므로 초기화 시 build와 refresh 요청이 겹친다. 일반 API timeout은 10초, refresh는 5초.
- 사용자 영향: 서버가 느리면 브랜드 스플래시에서 오래 기다리며 사용자에게 진행·재시도 안내가 없다. 정확한 실기기 시작 시간은 측정하지 않았다.
- 조치: 첫 Provider.future를 한 번만 기다리거나 화면 진입 후 로드한다. 캐시 우선 표시 및 로딩 상태를 제공한다. /optimize


### F14 [P2] 알림 폴링 실패가 기존 목록을 비움

- 범주: 오류 처리
- 위치: [notification_service.dart:96](/Users/imdonghyeon/perch_care/lib/src/services/notification/notification_service.dart:96) · [notification_view_model.dart:31](/Users/imdonghyeon/perch_care/lib/src/view_models/notification/notification_view_model.dart:31)
- 증거: 코드 확인: subscribeToNotifications는 오류 시 []를 yield하고 ViewModel은 이를 AsyncData로 적용한다.
- 사용자 영향: 일시적인 통신 오류만으로 이미 보던 알림이 사라져 삭제된 것처럼 보인다. 읽음 처리 실패 뒤 재조회도 실패하면 화면 콜백까지 예외가 전달될 수 있다.
- 조치: 폴링 실패에서는 마지막 성공 목록을 유지하고 별도 오류 상태·재시도를 제공한다. /harden


### F15 [P2] 공개 라우트 직접 진입 후 뒤로가기 예외

- 범주: 라우팅
- 위치: [signup_screen.dart:108](/Users/imdonghyeon/perch_care/lib/src/screens/signup/signup_screen.dart:108) · [forgot_password_method_screen.dart:51](/Users/imdonghyeon/perch_care/lib/src/screens/forgot_password/forgot_password_method_screen.dart:51) · [terms_detail_screen.dart:32](/Users/imdonghyeon/perch_care/lib/src/screens/terms/terms_detail_screen.dart:32)
- 증거: 재현: /signup을 첫 경로로 열고 뒤로가기 → GoError: There is nothing to pop. 일반 로그인 화면에서 push로 진입한 흐름과 구분되는 조건이다.
- 사용자 영향: 딥링크·복원 등으로 부모 스택 없이 공개 화면을 열면 뒤로가기가 실패한다. 다른 인증 하위 화면도 같은 무조건 pop 패턴을 사용한다.
- 조치: canPop이면 pop, 아니면 로그인 등 안전한 경로로 이동하는 공통 뒤로가기 처리를 사용한다. /harden


### F16 [P2] 펫 목록 화면이 존재하지 않는 SVG 5개를 참조함

- 범주: 리소스 / 화면 표시
- 위치: [pet_profile_screen.dart:167](/Users/imdonghyeon/perch_care/lib/src/screens/pet/pet_profile_screen.dart:167) · [pet_profile_screen.dart:195](/Users/imdonghyeon/perch_care/lib/src/screens/pet/pet_profile_screen.dart:195) · [pet_profile_screen.dart:243](/Users/imdonghyeon/perch_care/lib/src/screens/pet/pet_profile_screen.dart:243)
- 증거: 파일 존재 검사: default_profile.svg, settings_icon.svg, pet_profile.svg, gender_male.svg, gender_female.svg가 assets/images에 없다. 현재 화면 렌더링 검사에서는 비동기 SVG 오류가 검출되지 않았으므로 파일 검사 결과로 분류.
- 사용자 영향: /home/pet/profile 진입 시 프로필·설정·성별 아이콘을 정상 로드할 수 없다. 주요 프로필 화면과 별도로 남아 있는 라우트다.
- 조치: 실제로 등록된 공용 SVG/Material 아이콘으로 맞추고 이 별도 펫 목록 라우트를 계속 제공할지 정리한다. /normalize


### F17 [P2] 폰트 등록 누락과 일부 한국어·영어 고정 문구

- 범주: 테마 / 다국어
- 위치: [typography.dart:10](/Users/imdonghyeon/perch_care/lib/src/theme/typography.dart:10) · [pubspec.yaml:10](/Users/imdonghyeon/perch_care/pubspec.yaml:10) · [food_record_screen.dart:678](/Users/imdonghyeon/perch_care/lib/src/screens/food/food_record_screen.dart:678) · [pet_profile_screen.dart:63](/Users/imdonghyeon/perch_care/lib/src/screens/pet/pet_profile_screen.dart:63) · [coach_mark_overlay.dart:270](/Users/imdonghyeon/perch_care/lib/src/widgets/coach_mark_overlay.dart:270)
- 증거: 코드 확인: AppTheme은 Pretendard를 지정하지만 pubspec에 fonts 등록이 없고 GoogleFonts 로딩도 없다. 식사 시간은 오전/오후, 펫 나이는 년/개월/일, 코치마크 Next 및 사진 삭제 라벨은 고정 문자열.
- 사용자 영향: 설계한 폰트 대신 기기별 대체 폰트가 사용된다. 영어·중국어 사용자는 화면 일부 또는 보조기기 안내에서 다른 언어를 보게 된다.
- 조치: 실제 폰트를 자산에 등록하거나 의도한 시스템 폰트 정책으로 정리한다. 시간·나이·접근성 라벨을 l10n으로 통일한다. /normalize /clarify


## 화면·라우트별 결과

`○`는 해당 대체 데이터의 렌더링에서 Flutter 오류가 검출되지 않았다는 뜻이며, 서버 연결·모든 버튼 동작·접근성 통과를 뜻하지 않는다. `넘침`은 RenderFlex overflow가 확인된 조건이다. 각 수치는 [route-results.json](route-results.json)에 남겼다.

| 라우트 | KO 기본 | EN 320 | KO 200% | ZH 기본 | 흐름 및 추가 검토 |
|---|---|---|---|---|---|
| `/` 스플래시 | 코드 검토 | 코드 검토 | 코드 검토 | 코드 검토 | F12–F13. 세션 복원 및 온보딩 분기; 네이티브 초기화는 실기기 미검증 |
| `/onboarding` | ○ | ○ | ○ | ○ | 첫 실행 안내→로그인 이동 확인. 완료 플래그 저장 경로 확인. |
| `/login` | ○ | ○ | ○ | ○ | F01–F03, F10. 로그인 목적지는 hasPets tri-state로 분기. |
| `/signup` | ○ | ○ | ○ | ○ | F15. 약관 검증·중복 제출 가드 존재. 가입 후 토큰 폐기→로그인 흐름. |
| `/home` | ○ | 넘침 | 넘침 | ○ | F03–F06, F09, F13. 데이터 실패를 빈 상태로 표시하는 문제. |
| `/home/notification` | ○ | ○ | ○ | ○ | F14. 목록/읽음/삭제 동작을 VM에 위임. |
| `/home/profile` | ○ | ○ | 넘침 | ○ | F03, F09, F10. 로그아웃 예외는 화면에서 catch하지 않음; 로컬 정리 실패 조건 추가 검증 권장. |
| `/home/pet/profile/detail` | ○ | ○ | ○ | ○ | F04 계열: 진입 때 활성 펫을 한 번 읽음. 로딩 중 null이면 신규 등록 모드가 됨. 사진 I/O 실패가 폼 로드를 중단할 수 있음. |
| `/home/pet/add` | ○ | ○ | 넘침 | ○ | F01, F09. 등록·수정·첫 설정 모드 분기 및 저장 후 Provider 무효화 확인. |
| `/home/pet/profile` | ○ | ○ | ○ | ○ | F06, F16, F17. 실제 파일 없는 SVG와 오류 시 빈 목록. |
| `/home/food/record` | ○ | ○ | ○ | ○ | F04, F17. 날짜 변경 응답 순서 가드 및 저장 중 잠금도 추가 검증 권장. |
| `/home/water/record` | ○ | ○ | ○ | ○ | F04. null pet 저장 후 성공 안내 가능. 날짜별 조회·편집·오프라인 저장 경로 확인. |
| `/home/wci/index` | ○ | ○ | ○ | ○ | 설명 화면 기본 렌더링 정상. 뒤로가기 fallback 있음. |
| `/home/bhi/detail` | ○ | 넘침 | ○ | ○ | F09. BHI extra 누락 시 빈 상태 처리 있음. |
| `/home/terms/detail` | ○ | ○ | ○ | ○ | 로그인 상태 홈 하위 약관. 스크롤 렌더링 확인. |
| `/home/faq` | ○ | ○ | ○ | ○ | 기존 ko/en/zh 위젯 테스트 통과. 아코디언 및 뒤로가기 fallback 확인. |
| `/home/profile/setup` | ○ | ○ | ○ | ○ | F07. 수정 모드 취소/완료와 초기 설정 진행 구분은 기존 테스트로 보호됨. |
| `/home/profile/setup/complete` | ○ | ○ | ○ | ○ | 렌더링 정상. 시작/건너뛰기 모두 홈 이동. 현재 등록 완료에서 이 라우트로 이동하는 호출은 없음. |
| `/home/health-check` | ○ | ○ | ○ | ○ | F05 계열: 안내 지연 중 다음 화면 이동 시 표시 유효성 확인 필요. 모드 4개 진입 확인. |
| `/home/health-check/capture` | ○ | ○ | 넘침 | ○ | F09. 카메라/앨범 취소·크기 제한 존재. 실제 권한/HEIC 변환은 네이티브 검증 필요. |
| `/home/health-check/analyzing` | ○ | ○ | ○ | ○ | 모의 서버 503의 오류 상태 렌더링 검사. mode/image/fileName 필수 인자 가드 확인. 성공 분석·과금/쿼터는 서버 미검증. |
| `/home/health-check/result` | ○ | ○ | ○ | ○ | 히스토리 모드의 최소 결과 데이터 렌더링 검사. 초기 결과는 로컬 미러 저장; 실서버 결과 스키마 미검증. |
| `/home/health-check/history` | ○ | ○ | ○ | ○ | 활성 펫 변경을 구독함. 서버 히스토리 조회가 Repository에서 2회 발생하는 성능 개선 여지. |
| `/home/health-check/vet-summary` | ○ | 넘침 | 넘침 | ○ | F09. 펫 없으면 공유가 무응답으로 반환. 실제 공유 시트/서버 공유 URL 미검증. |
| `/weight-detail` | ○ | ○ | ○ | ○ | F06. 활성 펫을 구독해 다시 조회. 달력/일정/일일 기록 경로 확인; 저장 뒤 로드 실패 시 상태 복구 추가 검증 권장. |
| `/weight-detail/record` | ○ | ○ | ○ | ○ | F04 계열: 활성 펫 첫 스냅샷+로컬 폴백. 날짜/시간/저장 가드 확인. 기존 기록은 fetchLocal로 로드. |
| `/weight-detail/add/today` | ○ | ○ | ○ | ○ | F04. WeightAddScreen을 오늘 날짜로 사용. |
| `/weight-detail/add/2026-09-09` | ○ | ○ | ○ | ○ | F04. 날짜 파라미터 parse 실패는 오늘 날짜로 대체. |
| `/ai-encyclopedia` | ○ | ○ | ○ | ○ | F04–F05. SSE timeout·fallback·중복 전송 방지 존재. 탭 유지 상태에서 펫/세션 교체 누락. |
| `/terms/detail` | ○ | ○ | ○ | ○ | 비로그인 공개 약관. 스택 없는 직접 진입 뒤로가기는 F15 검토 대상. |
| `/email-login` | ○ | ○ | 넘침 | ○ | F01–F03, F09–F10. 이메일 검증과 로그인 재진입 방지 확인. |
| `/forgot-password/method` | ○ | ○ | ○ | ○ | 메일 전송 오류 안내 있음. 직접 진입 뒤로가기는 F15와 같은 패턴. |
| `/forgot-password/code` | 넘침 | 넘침 | 넘침 | 넘침 | F08. 6칸 입력/타이머/재전송/자동 검증 경로 확인. |
| `/forgot-password/reset` | ○ | ○ | ○ | ○ | 코드·식별자 extra 전달, 비밀번호 검증, 완료 후 로그인 이동 확인. extra 없는 직접 진입을 차단하지 않음. |


## 화면 증거

아래 이미지는 합성 데이터로 만든 위젯 테스트 캡처다. 사용자 계정이나 실제 건강 기록은 사용하지 않았다.

- [인증번호 입력 — 한국어 390px](screenshots/forgot-password-code-ko.png): 마지막 칸이 오른쪽으로 잘림.
- [병원 방문 요약 — 영어 320×568](screenshots/vet-summary-en.png): 화면 아래 콘텐츠가 넘치고 하단 탭 영역과 겹침.

## 공통 원인과 정상 패턴

반복되는 원인은 **비동기 데이터의 첫 값만 읽기**, **오류를 빈 데이터로 바꾸기**, **mounted를 화면 가시성과 동일시하기**, **인증 세션과 Provider 수명 분리**, **고정 폭·높이**다. 화면별 땜질보다는 이 공통 계약을 먼저 정리하는 편이 영향 범위를 줄인다.

유지할 만한 구현도 있다. 라우트 이름/경로는 중앙화되어 있고 보호 경로 25개는 테스트를 통과했다. 홈·기록·건강체크 이력의 일부 ViewModel은 펫 변경 구독과 오래된 BHI 요청 방지 로직을 갖고 있다. 펫 저장 후 Provider 무효화, 식사·수분의 로컬 저장 및 동기화 큐, SSE 타임아웃·fallback, 여러 화면의 reduced-motion 및 저장 버튼 재진입 가드가 존재한다. FAQ 다국어, 프로필 수정/초기 설정 분기는 기존 위젯 테스트가 보호한다.

기존 테스트가 대부분 Repository/ViewModel 단위이며 초기 데이터를 동기 완료시키는 fixture를 사용한다는 점이 이번 누락과 연결된다. **펫이 아직 로딩 중인 화면 진입, 로그아웃→재로그인, 탭 변경 직후 지연 콜백, 실제 폭에서의 글자 확대**를 지속적인 검증 범위에 넣어야 한다.

## 권장 작업 순서

1. **[P1] `/harden`** — F01–F06: 토큰 재요청, 세션 유지·갱신, 펫 구독, 코치마크 가시성, 초기 오류 재시도. 기능 재현 테스트를 먼저 통과시킨다.
2. **[P1] `/harden`** — F07/F10: 프로필 입력 저장 계약, Android Apple 로그인. 지원 범위에 맞는 실제 기기 검증을 수행한다.
3. **[P1] `/adapt`** — F08/F09: 인증번호 입력, 병원 요약, 확대 시 카드·버튼. 4환경 라우트 검사의 overflow를 제거하고 키보드 조건을 추가한다.
4. **[P1/P2] `/normalize` + `/clarify`** — F11/F16/F17: 대비, 실제 자산·폰트, 다국어 및 접근성 라벨.
5. **[P2] `/harden` + `/optimize`** — F12–F15: 플랫폼 초기화, 스플래시 중복 로드, 알림 오류 보존, 직접 진입 뒤로가기.
6. **`/audit` → `/polish`** — 수정 후 같은 재현 조건을 다시 검사하고, 실제 iPhone/Android에서 로그인→펫 선택→기록 저장→AI→프로필→로그아웃을 확인한다.

항목별·전체 일괄·우선순위 변경 모두 가능하다. 후속 수정 후 `/audit`를 같은 조건으로 반복하면 개선을 비교할 수 있다.

## 판정 기준 및 참고

- [W3C: Contrast Minimum](https://www.w3.org/WAI/WCAG20/Understanding/contrast-minimum.html): 일반 텍스트 4.5:1, 큰 글자 3:1 기준을 대비 계산에 사용했다.
- [W3C: Resize Text](https://www.w3.org/WAI/WCAG22/Understanding/resize-text.html): 글자 200% 확대 시 내용·기능 보존을 점검 기준으로 사용했다.
- [W3C: Reflow](https://www.w3.org/WAI/WCAG22/Understanding/reflow): 작은 가용 폭에서 콘텐츠 접근성을 평가하는 참고 기준이다. 네이티브 앱의 법적 준수 판정은 하지 않았다.
- [Flutter: Page transition builders reorganization](https://docs.flutter.dev/release/breaking-changes/decouple-page-transition-builders): 이전 턴의 Cupertino import 수정 근거. 이번 턴은 추가 제품 코드 변경 없이 검토·진단 산출물을 작성했다.

