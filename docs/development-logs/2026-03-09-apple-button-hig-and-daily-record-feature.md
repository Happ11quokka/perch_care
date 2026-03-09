# 2026-03-09 Apple 버튼 HIG 준수 + 일일 기록 기능 + API 다국어 수정 + 기록 화면 UX 개선

## 개요
- App Store 리젝 대응으로 Apple 로그인 버튼을 HIG(Human Interface Guidelines)에 맞게 수정 (main → dev cherry-pick)
- 체중 상세 화면에 일일 기록(Daily Record) 기능 추가
- API 클라이언트의 Accept-Language 헤더가 앱 내 설정 언어를 우선 반영하도록 수정
- 체중 기록 섹션 순서 변경 + 일정/메모를 선택 날짜 기준 필터링으로 UX 개선

---

## 1. Apple 로그인 버튼 HIG 준수 (App Store 리젝 대응)

### 배경
- App Store 심사에서 Apple 로그인 버튼이 Human Interface Guidelines를 위반하여 리젝
- `Icons.apple`(Material 아이콘) 사용 → Apple Design Resources 공식 로고 SVG로 교체 필요

### 변경 파일
| 파일 | 변경 내용 |
|------|-----------|
| `assets/images/btn_apple/apple_logo_black.svg` | Apple 공식 검정 로고 SVG 추가 (프로필 화면용) |
| `assets/images/btn_apple/apple_logo_white.svg` | Apple 공식 흰색 로고 SVG 추가 (이메일 로그인 화면용) |
| `lib/src/screens/login/email_login_screen.dart` | `Icons.apple` → 공식 SVG 로고(흰색, 60x60) + 검정 배경 버튼 |
| `lib/src/screens/login/login_screen.dart` | 커스텀 버튼 → `SignInWithAppleButton` 공식 위젯(black 스타일) 적용 |
| `lib/src/screens/profile/profile_screen.dart` | `Icons.apple` → 공식 SVG 로고(검정, 24x24) |

### 주요 변경 사항

#### email_login_screen.dart
- Apple 버튼 전용 스타일링: 검정 배경(`backgroundColor: Colors.black`) + 검정 테두리
- 로딩 인디케이터 색상 커스텀 지원 (`loadingColor: Colors.white`)
- `_buildSocialLoginButton`에 `backgroundColor`, `borderColor`, `loadingColor` 파라미터 추가

#### login_screen.dart
- `_buildSocialLoginButton` + `_buildAppleIcon()` 제거
- `SignInWithAppleButton` 공식 위젯으로 대체 (`style: SignInWithAppleButtonStyle.black`)
- 높이 64, borderRadius 16

#### profile_screen.dart
- 소셜 계정 연동 목록에서 `Icons.apple` → `SvgPicture.asset('assets/images/btn_apple/apple_logo_black.svg')`

---

## 2. 일일 기록(Daily Record) 기능 추가

### 배경
- 체중 상세 화면에서 반려조의 기분, 활동량, 메모를 날짜별로 기록하는 기능 필요
- 기존 일정(Schedule) 추가 버튼을 메뉴 방식으로 변경하여 일정 추가 / 일일 기록 추가 선택 가능

### 변경 파일
| 파일 | 변경 내용 |
|------|-----------|
| `lib/src/screens/weight/weight_detail_screen.dart` | 일일 기록 목록 UI + CRUD + 추가 메뉴 |
| `lib/src/widgets/add_daily_record_bottom_sheet.dart` | 일일 기록 입력 바텀시트 (신규) |
| `lib/l10n/app_en.arb` | 일일 기록 관련 영어 번역 20개 키 추가 |
| `lib/l10n/app_ko.arb` | 일일 기록 관련 한국어 번역 20개 키 추가 |
| `lib/l10n/app_zh.arb` | 일일 기록 관련 중국어 번역 20개 키 추가 |
| `lib/l10n/app_localizations.dart` | 자동 생성 (abstract 클래스) |
| `lib/l10n/app_localizations_en.dart` | 자동 생성 (영어 구현) |
| `lib/l10n/app_localizations_ko.dart` | 자동 생성 (한국어 구현) |
| `lib/l10n/app_localizations_zh.dart` | 자동 생성 (중국어 구현) |

### 주요 기능

#### 일일 기록 데이터 모델 (`DailyRecord`)
- `mood`: 기분 상태 (great / good / normal / bad / sick)
- `activityLevel`: 활동량 (1~5 별점)
- `notes`: 자유 메모
- `recordedDate`: 기록 날짜

#### weight_detail_screen.dart 변경
- `_dailyRecordService` 추가, 월별 데이터 로드 (`_loadDailyRecordData`)
- `_buildDailyRecordList()`: 월별 일일 기록 카드 목록 렌더링
- `_buildDailyRecordCard()`: 날짜, 기분 이모지, 활동량 별, 메모 표시 + Dismissible 삭제
- `_showAddRecordMenu()`: 하단 버튼 탭 시 "일정 추가" / "일일 기록 추가" 선택 메뉴
- 기존 FAB의 `onTap`이 `_openScheduleBottomSheetFor` → `_showAddRecordMenu`로 변경

#### add_daily_record_bottom_sheet.dart (신규)
- 날짜 선택, 기분 선택 (이모지 기반), 활동량 별점, 메모 입력
- 기존 기록이 있으면 수정 모드로 로드
- 3개 국어 지원 (한/영/중)

### 추가된 l10n 키
```
dailyRecord_title, dailyRecord_mood, dailyRecord_activity, dailyRecord_notes,
dailyRecord_notesHint, dailyRecord_moodGreat, dailyRecord_moodGood,
dailyRecord_moodNormal, dailyRecord_moodBad, dailyRecord_moodSick,
dailyRecord_saved, dailyRecord_deleted, dailyRecord_saveError,
dailyRecord_deleteError, weightDetail_monthDailyRecord,
weightDetail_noDailyRecord, weightDetail_addDailyRecordHint,
btn_addSchedule, btn_addDailyRecord
```

---

## 3. API 클라이언트 Accept-Language 수정

### 변경 파일
| 파일 | 변경 내용 |
|------|-----------|
| `lib/src/services/api/api_client.dart` | `_acceptLanguage` getter에 `LocaleProvider` 우선 참조 추가 |

### 변경 내용
- 기존: `PlatformDispatcher.instance.locale` (시스템 언어만 사용)
- 변경: `LocaleProvider.instance.currentLanguageCode`를 먼저 확인 → 앱 내 설정 언어가 있으면 해당 값 반환, 없으면 시스템 언어 폴백
- 사용자가 앱 내에서 언어를 변경했을 때 API 응답도 해당 언어로 반환되도록 보장

---

## 4. 기록 화면 섹션 순서 변경 + 날짜별 필터링 UX 개선

### 배경
- 체중 상세 화면에서 캘린더 아래 체중 기록이 먼저 나오고 일정/메모가 뒤에 있어 스크롤이 많이 필요
- 일정, 메모가 월 단위 전체를 보여줘서 특정 날짜 기록을 확인하기 어려움

### 변경 파일
| 파일 | 변경 내용 |
|------|-----------|
| `lib/src/screens/weight/weight_detail_screen.dart` | 섹션 순서 변경 + 일정/메모 날짜 필터링 |
| `lib/l10n/app_ko.arb` | 날짜별 타이틀 키 4개 추가 |
| `lib/l10n/app_en.arb` | 날짜별 타이틀 키 4개 추가 |
| `lib/l10n/app_zh.arb` | 날짜별 타이틀 키 4개 추가 |
| `lib/l10n/app_localizations*.dart` | 자동 생성 (3개 언어) |

### 주요 변경 사항

#### 섹션 순서 변경
- 기존: 캘린더 → **체중 기록** → 일정 → 메모
- 변경: 캘린더 → **일정** → **메모** → **체중 기록** (맨 밑)
- 캘린더에서 날짜 선택 후 바로 아래에서 해당 날짜의 일정/메모 확인 가능

#### 일정 리스트 날짜 필터링 (`_buildScheduleList`)
- 기존: `_selectedYear` + `_selectedMonth` 기준 월 전체 필터
- 변경: `_selectedYear` + `_selectedMonth` + `_selectedDay` 기준 날짜 필터
- 타이틀: `weightDetail_monthSchedule`("이번 달 일정") → `weightDetail_dateSchedule`("3월 9일 일정")
- 빈 상태 메시지: `weightDetail_noScheduleOnDate`("이 날에 등록된 일정이 없습니다")

#### 일일 기록 리스트 날짜 필터링 (`_buildDailyRecordList`)
- 기존: `_selectedYear` + `_selectedMonth` 기준 월 전체 필터
- 변경: `_selectedYear` + `_selectedMonth` + `_selectedDay` 기준 날짜 필터
- 타이틀: `weightDetail_monthDailyRecord`("이번 달 일일 기록") → `weightDetail_dateDailyRecord`("3월 9일 일일 기록")
- 빈 상태 메시지: `weightDetail_noDailyRecordOnDate`("이 날에 등록된 일일 기록이 없습니다")

### 추가된 l10n 키
```
weightDetail_dateSchedule         - "{month}월 {day}일 일정" / "Schedule for {month}/{day}" / "{month}月{day}日日程"
weightDetail_noScheduleOnDate     - "이 날에 등록된 일정이 없습니다" / "No scheduled events for this date" / "此日暂无日程"
weightDetail_dateDailyRecord      - "{month}월 {day}일 일일 기록" / "Daily Record for {month}/{day}" / "{month}月{day}日每日记录"
weightDetail_noDailyRecordOnDate  - "이 날에 등록된 일일 기록이 없습니다" / "No daily records for this date" / "此日暂无每日记录"
```

---

## 커밋 이력 (main → dev cherry-pick)
- `8cd6a46` - Sign in with Apple 버튼 디자인 가이드라인 준수 (App Store 리젝 대응)
- `3552934` - Sign in with Apple 버튼 HIG 준수 및 공식 로고 적용
- `e98f9ab` - Apple 로그인 버튼 로고 크기 확대 (44→60)
