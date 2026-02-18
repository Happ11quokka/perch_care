# 베타 테스트 사용자 피드백 UX 개선 (2026-02-18)

**날짜**: 2026-02-18
**작성자**: Claude Code
**상태**: 진행 중

---

## 사용자 원본 피드백

> ux적으로 조금 아쉬운 것 같아요! 에러가 나면 에러가 어디서 나는지 같은거에 대한 설명이 조금 없는 느낌이고 아이 추가가 수정기능으로 바뀌어있고 (그마저도 데려온날은 스테이트 관리가 안된건지 초기화되네요..) 등의 문제가 있는 것 같아요
>
> 체중도 처음에 아이 추가할때 현재 무게를 입력할텐데 첫 체중 입력은 현재 무게와는 상관없는 수치를 입력해도 되구요
>
> 첫 입력에 대한 배려가 조금 있었으면 좋을것 같아요!

---

## 수정 요약

| # | 카테고리 | 이슈 | 상태 |
|---|---------|------|------|
| 1 | 버그 | 새 아이 등록이 기존 아이 수정으로 연결됨 | 완료 |
| 2 | 버그 | 펫 편집 시 데려온날/체중 초기화 | 완료 |
| 3 | 기능 | 초기 체중 입력 → 체중 기록 미연동 | 완료 |
| 4 | UX | 에러 메시지가 기술적이고 불친절 | 완료 |
| 5 | UX | 첫 사용자를 위한 가이드 부재 | 완료 |
| 6 | UI 숨김 | 카카오 로그인 사업자 등록 미완료 | 완료 |
| 7 | 버그 | 체중 저장 후 "저장되었습니다" 스낵바 미표시 | 완료 |
| 8 | UX | 체중 저장 UX 통일 (모달 → 인라인 입력 + 저장 버튼) | 완료 |
| 9 | UX | 체중 기록 리스트 접기/펼치기 (10개 기본) | 완료 |
| 10 | UX | 일정 기록 삭제 기능 부재 (스와이프 삭제 추가) | 완료 |
| 11 | 기능 | 체중 기록 시 시간대(시/분) 함께 기록 | 완료 |
| 12 | 기능 | 1일 다중 체중 기록 + 일평균 차트 | 완료 |
| 13 | 기능 | 식이 배식/취식 누적 기록 (탭 구분) | 완료 |
| 14 | UI | AnalogTimePicker 분 선택 모드 추가 (1분 단위) | 완료 |
| 15 | UX | 기록/앵박사 페이지 코치마크 가이드 확장 | 완료 |
| 16 | 버그/기능 | 앵박사 다국어 답변 미매칭 + 기록 미반영 + API 파라미터 미전달 | 완료 |
| 17 | 버그 | 체중 기록 화면 하드코딩 한국어 → 로컬라이제이션 미적용 | 완료 |

---

## 1. 새 아이 등록 네비게이션 버그

**파일**: [profile_screen.dart](../../lib/src/screens/profile/profile_screen.dart)

### 문제
프로필에서 "새로운 아이 등록하기" 탭 → 기존 반려조 데이터가 채워진 편집 폼이 열림 (빈 폼이어야 함)

### 원인
`_buildAddPetButton()`이 `RouteNames.petProfileDetail` (항상 기존 펫 로드)로 이동하고 있었음

### 수정
```dart
// Before: context.pushNamed(RouteNames.petProfileDetail)
// After:
context.pushNamed(RouteNames.petAdd)  // petId 없이 → 빈 폼 (새 등록 모드)
```

---

## 2. 펫 편집 시 데려온날/체중 초기화 버그

**파일**: [pet_add_screen.dart](../../lib/src/screens/pet/pet_add_screen.dart)

### 문제
펫 편집 화면 진입 시 `_loadExistingPet()`에서 `adoptionDate`와 `weight` 로딩이 누락되어 데려온날이 초기화됨

### 수정
`_loadExistingPet()` 메서드에 누락된 필드 복원 추가:
```dart
_selectedAdoptionDate = pet.adoptionDate;
if (pet.weight != null) {
  _weightController.text = pet.weight!.toStringAsFixed(1);
}
```

---

## 3. 초기 체중 → WeightRecord 자동 생성

**파일**: [pet_add_screen.dart](../../lib/src/screens/pet/pet_add_screen.dart)

### 문제
펫 등록 시 입력한 체중이 체중 기록 화면에 반영되지 않음. 사용자가 같은 체중을 다시 입력해야 하는 불편함.

### 수정
새 펫 생성 시 체중값이 있으면 `WeightRecord`를 자동 생성:
```dart
if (weightValue != null && _existingPet == null) {
  final record = WeightRecord(petId: savedPet.id, date: DateTime.now(), weight: weightValue);
  await weightService.saveLocalWeightRecord(record);
  await weightService.saveWeightRecord(record);  // 백엔드 동기화 (실패해도 로컬 유지)
}
```

---

## 4. 에러 메시지 사용자 친화적 개선

**파일**:
- [error_handler.dart](../../lib/src/utils/error_handler.dart) (신규)
- [app_ko.arb](../../lib/l10n/app_ko.arb), [app_en.arb](../../lib/l10n/app_en.arb), [app_zh.arb](../../lib/l10n/app_zh.arb)

### 문제
에러 발생 시 `e.toString()` 그대로 표시 → 사용자에게 기술적 메시지 노출

### 수정
`ErrorHandler.getUserMessage()` 유틸리티로 에러 유형별 친화적 메시지 매핑:

| 에러 유형 | 감지 | 메시지 |
|-----------|------|--------|
| 네트워크 | `SocketException`, `TimeoutException` | "네트워크 연결을 확인해 주세요." |
| 서버 (5xx) | `statusCode >= 500` | "서버에 일시적인 문제가 발생했습니다." |
| 인증 (401/403) | `statusCode == 401/403` | "로그인이 필요합니다." |
| 유효성 (422) | `statusCode == 422` | "입력 정보를 다시 확인해 주세요." |

---

## 5. 첫 사용자 코치마크 가이드

**파일**:
- [coach_mark_overlay.dart](../../lib/src/widgets/coach_mark_overlay.dart) (신규)
- [coach_mark_service.dart](../../lib/src/services/coach_mark/coach_mark_service.dart) (신규)
- [home_screen.dart](../../lib/src/screens/home/home_screen.dart)
- [bottom_nav_bar.dart](../../lib/src/widgets/bottom_nav_bar.dart)

### 기능
첫 로그인 후 홈 화면 진입 시 7단계 코치마크로 주요 기능 안내:

| 단계 | 타겟 | 안내 내용 |
|------|------|-----------|
| 1/7 | WCI 건강 상태 카드 | "WCI 건강 상태를 확인하세요" |
| 2/7 | 체중 카드 | "여기서 체중을 기록해보세요!" |
| 3/7 | 수분 카드 | "음수량을 기록해보세요" |
| 4/7 | 사료 카드 | "사료 취식량을 기록해보세요" |
| 5/7 | 건강 신호 카드 | "AI가 분석한 건강 신호를 확인해보세요" |
| 6/7 | 기록 탭 (하단 네비) | "체중 변화와 일정을 확인할 수 있어요" |
| 7/7 | 앵박사 탭 (하단 네비) | "AI 앵박사에게 물어보세요!" |

### 구현 방식
- 외부 패키지 없이 `OverlayEntry` + `CustomPainter` 커스텀 구현
- 반투명 배경 + 타겟 위젯 spotlight (`PathFillType.evenOdd`)
- 브랜드 그라데이션 툴팁 (`#FF9A42` → `#FF7C2A`) + 화살표
- `SharedPreferences`로 "이미 봤음" 상태 저장
- `ScrollController`로 자동 스크롤 (카드가 화면 밖일 때)

### 반복 수정 이력 (위치 조정)

#### Round 1: 초기 구현
- 수동 `TooltipPosition.above/below` 지정 방식
- **문제**: 화면 밖으로 넘어가는 체크 없어서 일부 툴팁 안 보임

#### Round 2: 자동 위치 결정 + gap 수정
- `TooltipPosition` enum 제거 → 화면 여유 공간 기반 자동 결정
- gap 수정: `arrowSize + 8` (18px) → `8px`
- `isScrollable: false` 추가 (하단 네비 등 고정 요소)
- `Expanded` → `Container`로 GlobalKey 이동 (bottom_nav_bar)
- **문제**: 여전히 툴팁이 타겟에서 200-400px 떨어짐, 네비바 스포트라이트 없음

#### Round 3: 오버레이 좌표계 수정 (현재)
**근본 원인 발견**: `Overlay.of(context)`가 `StatefulShellRoute` 서브 Navigator의 body-only 오버레이 반환
- `localToGlobal()` → 화면 좌표 (전체 스크린 기준)
- `Positioned()` → 오버레이 좌표 (Scaffold body 영역만, 네비바 제외)
- 좌표계 불일치 → 툴팁 위치 틀어짐 + 네비바 영역 스포트라이트 불가

**수정 내용**:
1. `Overlay.of(context, rootOverlay: true)` → MaterialApp 레벨 루트 오버레이 사용
2. `Positioned(bottom:)` → `Positioned(top:)` 전환 (좌표 불일치 근본 방지)
3. 카드 키를 `Expanded` → `Container`로 이동 (`findRenderObject()` 안정성)
4. `targetRect` null 시 100ms 재시도 로직 추가

---

## 6. 카카오 로그인 UI 숨김

**파일**:
- [login_screen.dart](../../lib/src/screens/login/login_screen.dart)
- [profile_screen.dart](../../lib/src/screens/profile/profile_screen.dart)

### 사유
사업자 등록 미완료로 카카오 로그인 기능 사용 불가. 코드는 전부 유지하되 UI에서만 주석 처리.

### 복원 방법
사업자 등록 완료 후 아래 TODO 검색하여 주석 해제:
```
// TODO: 사업자 등록 완료 후 카카오 로그인 활성화
// TODO: 사업자 등록 완료 후 카카오 연동 활성화
```

---

## 7. 체중 저장 후 "저장되었습니다" 스낵바 미표시 버그

**파일**: [weight_record_screen.dart](../../lib/src/screens/weight/weight_record_screen.dart)

### 문제
수분/먹이 화면은 저장 후 "저장되었습니다." 스낵바가 표시되지만, 체중 화면에서는 표시되지 않음.

### 원인
체중 저장은 `WeightRecordScreen._openWeightEditor()`의 모달 바텀시트에서 이루어지고 있었는데, 저장 후 `AppSnackBar.success()` 호출이 아예 누락되어 있었음. (별도 라우트로 정의된 `WeightAddScreen`은 실제로 사용되지 않는 dead route였음)

### 수정
`_openWeightEditor()` 저장 완료 후 성공 스낵바 추가 → 이후 #8에서 전체 구조 변경됨

---

## 8. 체중 저장 UX 통일 (모달 바텀시트 → 인라인 입력)

**파일**: [weight_record_screen.dart](../../lib/src/screens/weight/weight_record_screen.dart)

### 문제
수분/먹이 화면은 **인라인 입력 + 저장 버튼** 패턴인데, 체중 화면만 **모달 바텀시트**로 입력받는 불일치 UX

### 수정
- 모달 바텀시트(`_openWeightEditor`) 제거
- 인라인 `TextField` 추가 (계산 박스 아래, 저장 버튼 위)
  - 소수점 1자리 제한, `g` 접미사, 기존 기록값 자동 반영
- 주황색 "저장" 버튼 → `_saveWeight()` 직접 호출
  - 로컬 + 백엔드 저장 → 성공 스낵바 표시
  - 저장 중 로딩 상태 (버튼 비활성화 + 스피너)
- 날짜 변경 시 해당 날짜의 기존 체중이 입력 필드에 자동 동기화

---

## 9. 체중 기록 리스트 접기/펼치기

**파일**: [weight_detail_screen.dart](../../lib/src/screens/weight/weight_detail_screen.dart), ARB 파일 3개

### 문제
캘린더 아래 "N월 체중 기록" 리스트가 기록 수에 관계없이 전부 표시되어 스크롤이 길어짐

### 수정
- 기본 최근 10개만 표시, 11개 이상일 때 "전체 보기 (N건)" 토글 버튼 표시
- 펼침 상태에서 "접기" 버튼으로 다시 10개로 축소
- `_isRecordsExpanded` state 변수로 상태 관리
- 로컬라이제이션 키 추가: `common_collapse` (접기), `common_showAll` (전체 보기 N건)

---

## 10. 일정 기록 스와이프 삭제 기능 추가

**파일**: [weight_detail_screen.dart](../../lib/src/screens/weight/weight_detail_screen.dart), ARB 파일 3개, app_localizations*.dart 4개

### 문제
"이번 달 일정" 섹션에서 일정 추가는 가능하지만, 삭제 UI가 없어 잘못 등록한 일정을 제거할 수 없음. 백엔드 API(`DELETE /pets/{petId}/schedules/{id}`)와 `ScheduleService.deleteSchedule()`은 이미 구현되어 있으나 UI에서 미사용.

### 수정
- `_buildScheduleItem()`에 `Dismissible` 위젯 래핑 (알림 화면과 동일한 스와이프 삭제 패턴)
  - `direction: DismissDirection.endToStart` (왼쪽 스와이프)
  - 빨간 배경 + 삭제 아이콘 노출
- `_deleteSchedule()` 메서드 추가:
  - 낙관적 업데이트: 로컬 state에서 즉시 제거
  - 서버 삭제 성공 시 "일정이 삭제되었습니다" 스낵바
  - 서버 삭제 실패 시 `_loadScheduleData()`로 데이터 복구 + 에러 스낵바
- 로컬라이제이션 키 추가: `schedule_deleted`, `schedule_deleteError` (ko/en/zh)

---

## 수정된 파일 전체 목록

| 파일 | 변경 유형 |
|------|-----------|
| `lib/src/screens/profile/profile_screen.dart` | 네비게이션 버그 수정, 카카오 UI 숨김 |
| `lib/src/screens/pet/pet_add_screen.dart` | 데려온날/체중 버그, 초기 WeightRecord, 에러 처리 |
| `lib/src/screens/login/login_screen.dart` | 카카오 UI 숨김 |
| `lib/src/screens/home/home_screen.dart` | 코치마크 GlobalKey, 트리거, 카드 키 이동 |
| `lib/src/utils/error_handler.dart` | **신규** - 에러 메시지 매핑 |
| `lib/src/services/coach_mark/coach_mark_service.dart` | **신규** - 코치마크 상태 관리 |
| `lib/src/widgets/coach_mark_overlay.dart` | **신규** - 코치마크 오버레이 위젯 |
| `lib/src/widgets/bottom_nav_bar.dart` | 코치마크용 정적 GlobalKey 추가 |
| `lib/l10n/app_ko.arb` | 에러/코치마크/일정삭제 l10n 추가 |
| `lib/l10n/app_en.arb` | 에러/코치마크/일정삭제 l10n 추가 |
| `lib/l10n/app_zh.arb` | 에러/코치마크/일정삭제 l10n 추가 |
| `lib/src/screens/weight/weight_record_screen.dart` | 모달 → 인라인 입력 UX 변경, 저장 스낵바 추가 |
| `lib/src/screens/weight/weight_detail_screen.dart` | 체중 기록 리스트 접기/펼치기, 일정 스와이프 삭제 |
| `lib/src/screens/weight/weight_add_screen.dart` | 저장 후 스낵바 딜레이 추가 (dead route) |

---

## 11. 체중 기록 시 시간대(시/분) 함께 기록

**파일**:
- [weight_record.dart](../../lib/src/models/weight_record.dart) — 모델 확장
- [weight_service.dart](../../lib/src/services/weight/weight_service.dart) — 다중 기록 지원
- [weight_record_screen.dart](../../lib/src/screens/weight/weight_record_screen.dart) — 시간 선택 카드 UI
- [weight_add_screen.dart](../../lib/src/screens/weight/weight_add_screen.dart) — 시간 선택 카드 UI

### 배경
베타 유저 피드백: "체중 기록 시 시간대도 함께 기록하고 싶다. 공복체중 표준화가 어렵고 시간 없이는 헷갈린다."

### WeightRecord 모델 확장
```dart
final int? recordedHour;   // 0-23, null이면 시간 미기록 (기존 데이터 호환)
final int? recordedMinute; // 0-59
bool get hasTime => recordedHour != null && recordedMinute != null;
```
- `fromJson`/`copyWith`에 시간 필드 추가
- `toJson`/`toInsertJson`: 시간 필드는 포함하지 않음 (백엔드 미변경)
- `==`/`hashCode`: `id` 기반으로 변경 (같은 날짜 다중 기록 구분)

### WeightRecordScreen 시간 선택 UI
- `TimeOfDay _selectedTime = TimeOfDay.now()` 상태 추가
- 기존 기록 목록과 체중 입력 필드 사이에 시간 선택 카드 배치
- 탭하면 `showAnalogTimePicker()` 호출
- 선택된 시간 표시: "오전 8:30" 형식
- 저장 시 `recordedHour`, `recordedMinute` 포함
- 저장 완료 후 시간 현재 시각으로 리셋

### WeightAddScreen 시간 선택 UI
- 날짜 카드 아래에 시간 선택 카드 추가 (동일 패턴)
- GestureDetector 탭 충돌 해결: 부모 바텀시트의 `onTap`을 드래그 핸들로 이동

---

## 12. 1일 다중 체중 기록 + 일평균 차트

**파일**:
- [weight_service.dart](../../lib/src/services/weight/weight_service.dart)
- [weight_record_screen.dart](../../lib/src/screens/weight/weight_record_screen.dart)
- [weight_detail_screen.dart](../../lib/src/screens/weight/weight_detail_screen.dart)

### WeightService 다중 기록 지원
- Upsert → Insert 전환 (로컬): id 기반 관리, 날짜가 같아도 별도 기록
- `getRecordsByDate(date, petId)` → 해당 날짜의 모든 기록 리스트 반환
- `getDailyAverageWeight(date, petId)` → 해당 날짜 평균 체중
- `deleteWeightRecordById(id, petId)` → 개별 기록 삭제
- API 호출은 변경 없음 (로컬에서만 다중 기록 관리)

### WeightRecordScreen 다중 기록 표시
- `_recordsForDate()`: 해당 날짜의 모든 기록 반환
- `_dailyAverageForDate()`: 일평균 계산
- `_buildExistingRecordsList()`: "3회 측정 | 일평균 65.3g" + 개별 기록 목록
- 입력 필드 비움 (다중 기록이므로 기존 값 자동 로드하지 않음)

### WeightDetailScreen 기록 목록 그룹화
- 같은 날짜의 기록이 여러 개인 경우 그룹화 표시:
  ```
  2/14 (금)    평균 65.3g [2회 측정]
    오전 8:30  64.8g
    오후 7:15  65.8g
  ```
- 단일 기록인 날은 기존처럼 한 줄로 표시
- 차트는 이미 리스트 기반 평균 계산이므로 변경 불필요

---

## 13. 식이 배식/취식 누적 기록

**파일**:
- [diet_entry.dart](../../lib/src/models/diet_entry.dart) — **신규** 모델
- [food_record_screen.dart](../../lib/src/screens/food/food_record_screen.dart) — 전면 개편

### DietEntry 모델 (신규)
```dart
enum DietType { serving, eating }

class DietEntry {
  final String foodName;
  final DietType type;       // 배식 or 취식
  final double grams;
  final int? recordedHour;
  final int? recordedMinute;
  final String? memo;
}
```
- `fromJson`, `fromLegacyJson` (기존 `_FoodEntry` JSON 호환), `toJson`, `copyWith`
- `hasTime`, `timeDisplayString` getter

### FoodRecordScreen 전면 개편
- **상단 요약 영역**: 배식 총량 | 취식 총량 | 취식률(%) 3열 표시
- **배식/취식 토글**: 오렌지 pill 형태 (WeightDetail의 주간/월간 토글과 동일 스타일)
- **각 탭의 기록 리스트**: 시간 + 음식명 + 양(g) + 삭제 버튼
- **"+ 기록 추가" 버튼**: DashedBorder 스타일, 현재 탭 유형에 맞는 라벨
- **입력 모달 (ModalBottomSheet)**:
  - 기록 유형 라디오 (배식/취식)
  - 음식 이름 입력
  - 양(g) 입력
  - 시간 선택 (`showAnalogTimePicker` 재활용)
  - 메모 (선택)
- **취식률 계산**: `(totalEaten / totalServed * 100).clamp(0, 999)`
- **저장**: SharedPreferences (로컬) + 백엔드 동시 저장
- **레거시 호환**: 기존 `_FoodEntry` JSON 데이터를 `DietEntry.fromLegacyJson()`으로 자동 마이그레이션

---

## 14. AnalogTimePicker 분 선택 모드 추가

**파일**: [analog_time_picker.dart](../../lib/src/widgets/analog_time_picker.dart)

### 문제
기존 AnalogTimePicker는 시간(시)만 다이얼로 선택 가능하고, 분은 변경할 수 없었음.

### 수정: 2단계 선택 방식 (시 → 분)

**모드 전환**:
- `_isSelectingHour` 상태로 시/분 모드 관리
- 시 선택 완료 시 자동으로 분 모드로 전환 (`onTapUp`/`onPanEnd`)
- 상단 시간 표시(`12:44`)에서 시/분 부분을 각각 탭하여 수동 전환 가능
- 현재 선택 중인 부분이 오렌지 배경으로 하이라이트

**시 선택 모드** (기존):
- `_HourClockPainter`: 1~12 숫자 + 시침

**분 선택 모드** (신규):
- `_MinuteClockPainter`: 00, 05, 10, ..., 55 라벨 (12개 5분 눈금)
- 1분 단위 작은 눈금 48개 (5분 눈금 사이 외곽 tick)
- **1분 단위 자유 선택**: 드래그/탭으로 0~59분 어디든 선택 가능 (스냅 없음)
- 5분 단위가 아닌 분(예: 7분, 13분) 선택 시 분침 끝에 해당 숫자가 표시된 오렌지 포인터 원 표시
- 분침 색상: 오렌지 (`AppColors.brandPrimary`)

---

## 로컬라이제이션 키 추가 (#11~#14)

**파일**: [app_ko.arb](../../lib/l10n/app_ko.arb), [app_en.arb](../../lib/l10n/app_en.arb), [app_zh.arb](../../lib/l10n/app_zh.arb)

### 체중 시간 관련
| 키 | 한국어 | 영어 | 중국어 |
|----|--------|------|--------|
| `weight_selectTime` | 측정 시간 | Measurement Time | 测量时间 |
| `weight_timeNotRecorded` | 시간 미기록 | Time not recorded | 未记录时间 |
| `weight_dailyAverage` | 일평균 | Daily Avg | 日均 |
| `weight_multipleRecords` | {count}회 측정 | {count} measurements | {count}次测量 |
| `weight_amPeriod` | 오전 | AM | 上午 |
| `weight_pmPeriod` | 오후 | PM | 下午 |
| `weight_addAnother` | 추가 기록 | Add Another | 再次记录 |
| `weight_deleteRecord` | 이 기록을 삭제하시겠습니까? | Delete this record? | 确定删除此记录？ |
| `weight_deleteConfirm` | 삭제 | Delete | 删除 |

### 식이 관련
| 키 | 한국어 | 영어 | 중국어 |
|----|--------|------|--------|
| `diet_serving` | 배식 | Served | 投喂 |
| `diet_eating` | 취식 | Eaten | 进食 |
| `diet_addServing` | 배식 기록 추가 | Add Serving Record | 添加投喂记录 |
| `diet_addEating` | 취식 기록 추가 | Add Eating Record | 添加进食记录 |
| `diet_addRecord` | 기록 추가 | Add Record | 添加记录 |
| `diet_totalServed` | 총 배식량 | Total Served | 总投喂量 |
| `diet_totalEaten` | 총 취식량 | Total Eaten | 总进食量 |
| `diet_eatingRate` | 취식률 | Eating Rate | 进食率 |
| `diet_eatingRateValue` | {rate}% | {rate}% | {rate}% |
| `diet_selectTime` | 급여/섭취 시간 | Serving/Eating Time | 投喂/进食时间 |
| `diet_servingSummary` | 배식 {count}회 · {grams}g | Served {count}x · {grams}g | 投喂 {count}次 · {grams}g |
| `diet_eatingSummary` | 취식 {count}회 · {grams}g | Eaten {count}x · {grams}g | 进食 {count}次 · {grams}g |
| `diet_selectType` | 기록 유형 | Record Type | 记录类型 |
| `diet_foodName` | 음식 이름 | Food Name | 食物名称 |
| `diet_amount` | 양(g) | Amount (g) | 量(g) |
| `diet_memo` | 메모 (선택) | Memo (optional) | 备注（选填） |

---

## 수정된 파일 전체 목록 (추가분 #11~#14)

| 파일 | 변경 유형 |
|------|-----------|
| `lib/src/models/weight_record.dart` | recordedHour/Minute 필드 추가, id 기반 equality |
| `lib/src/models/diet_entry.dart` | **신규** - DietEntry 모델 (배식/취식) |
| `lib/src/services/weight/weight_service.dart` | 다중 기록 지원, id 기반 관리, 신규 메서드 |
| `lib/src/screens/weight/weight_record_screen.dart` | 시간 선택 카드, 다중 기록 목록, 시간 포함 저장 |
| `lib/src/screens/weight/weight_add_screen.dart` | 시간 선택 카드, GestureDetector 탭 충돌 해결 |
| `lib/src/screens/weight/weight_detail_screen.dart` | 기록 목록 날짜별 그룹화, 시간 표시 |
| `lib/src/screens/food/food_record_screen.dart` | 배식/취식 탭, DietEntry 적용, 시간 선택, 요약행 |
| `lib/src/widgets/analog_time_picker.dart` | 2단계 선택 (시→분), 1분 단위 자유 선택 |
| `lib/l10n/app_ko.arb` | 체중 시간 + 식이 l10n 키 추가 |
| `lib/l10n/app_en.arb` | 체중 시간 + 식이 l10n 키 추가 |
| `lib/l10n/app_zh.arb` | 체중 시간 + 식이 l10n 키 추가 |

---

## 15. 기록/앵박사 페이지 코치마크 가이드 확장

**파일**:
- [coach_mark_service.dart](../../lib/src/services/coach_mark/coach_mark_service.dart) — records/chatbot 메서드 추가
- [weight_detail_screen.dart](../../lib/src/screens/weight/weight_detail_screen.dart) — 기록 페이지 코치마크 4단계
- [ai_encyclopedia_screen.dart](../../lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart) — 앵박사 페이지 코치마크 2단계
- [app_ko.arb](../../lib/l10n/app_ko.arb), [app_en.arb](../../lib/l10n/app_en.arb), [app_zh.arb](../../lib/l10n/app_zh.arb) — 코치마크 키 12개 추가

### 배경
홈 화면에만 코치마크 가이드가 있어 기록 페이지와 앵박사 페이지에 처음 진입한 사용자가 기능을 파악하기 어려웠음. 기존 CoachMarkService + CoachMarkOverlay 패턴을 그대로 확장.

### CoachMarkService 확장
```dart
static const _keyRecordsCoachSeen = 'coach_mark_records_seen';
static const _keyChatbotCoachSeen = 'coach_mark_chatbot_seen';
```
- `hasSeenRecordsCoachMarks()` / `markRecordsCoachMarksSeen()`
- `hasSeenChatbotCoachMarks()` / `markChatbotCoachMarksSeen()`

### 기록 페이지 (WeightDetailScreen) — 4단계

| 단계 | 타겟 | 안내 내용 |
|------|------|-----------|
| 1/4 | 주간/월간 토글 | "주간/월간 버튼을 눌러 기간별 체중 변화를 확인하세요" |
| 2/4 | 체중 차트 | "차트에서 체중 추이를 한눈에 확인할 수 있어요" |
| 3/4 | 캘린더 카드 | "날짜를 선택하면 해당 날의 기록을 볼 수 있어요" |
| 4/4 | 기록 추가 버튼 | "이 버튼을 눌러 새 체중을 기록하세요" |

- GlobalKey 4개 + ScrollController 추가
- 데이터 로드 완료 후 800ms 딜레이로 표시
- 추가 버튼은 스크롤 영역 밖 (`isScrollable: false`)

### 앵박사 페이지 (AIEncyclopediaScreen) — 2단계 (Welcome 상태 전용)

| 단계 | 타겟 | 안내 내용 |
|------|------|-----------|
| 1/2 | 추천 질문 칩 | "궁금한 주제를 탭하면 바로 AI에게 물어볼 수 있어요" |
| 2/2 | 질문 입력 영역 | "직접 질문을 입력해서 앵박사에게 물어보세요" |

- Welcome 상태 가드: `_messages.isEmpty` 일 때만 표시
- GlobalKey 2개 추가 (`isScrollable: false`)
- 채팅 초기화 완료 후 800ms 딜레이로 표시

### 로컬라이제이션 키 추가 (#15)

| 키 | 한국어 | 영어 | 중국어 |
|----|--------|------|--------|
| `coach_recordToggle_title` | 기간 전환 | Period Toggle | 周期切换 |
| `coach_recordToggle_body` | 주간/월간 버튼을 눌러... | Tap Weekly/Monthly... | 点击周/月按钮... |
| `coach_recordChart_title` | 체중 차트 | Weight Chart | 体重图表 |
| `coach_recordChart_body` | 차트에서 체중 추이를... | See your weight trends... | 在图表中一目了然... |
| `coach_recordCalendar_title` | 캘린더 | Calendar | 日历 |
| `coach_recordCalendar_body` | 날짜를 선택하면... | Select a date... | 选择日期... |
| `coach_recordAddBtn_title` | 기록 추가 | Add Record | 添加记录 |
| `coach_recordAddBtn_body` | 이 버튼을 눌러... | Tap this button... | 点击此按钮... |
| `coach_chatSuggestion_title` | 추천 질문 | Suggestions | 推荐问题 |
| `coach_chatSuggestion_body` | 궁금한 주제를 탭하면... | Tap a topic... | 点击主题即可... |
| `coach_chatInput_title` | 질문 입력 | Ask a Question | 输入问题 |
| `coach_chatInput_body` | 직접 질문을 입력해서... | Type your own question... | 直接输入问题... |

---

## 16. 앵박사 AI 프롬프트 개선 (다국어 대응 + RAG 강화)

**파일**: [ai_service.py](../../backend/app/services/ai_service.py)

### 문제 1: 질문 언어와 다른 언어로 답변
시스템 프롬프트가 한국어 전용으로 작성되어 있어, 중국어나 영어로 질문해도 항상 한국어로 답변하는 문제 발생.

### 문제 2: 저장된 앵무새 기록 미반영
RAG로 주입된 건강 데이터(체중, 사료, 음수량)를 답변에 반영하라는 지시가 약해서 GPT가 일반적인 답변만 하는 경우 발생.

### 문제 3: temperature/max_tokens 미전달 버그
프론트엔드에서 전달하는 `temperature`(0.2)와 `max_tokens`(512) 파라미터가 실제 OpenAI API 호출에 전달되지 않고 무시되고 있었음.

### 수정

**1. SYSTEM_PROMPT 다국어 대응 (L32-42)**
```python
# Before (한국어 전용)
SYSTEM_PROMPT = (
    "너는 앵무새(반려조) 케어 전문가야. "
    "사용자의 질문에 친절하고 정확하게 답변해. ..."
)

# After (언어 매칭 지시 + 영어 기반)
SYSTEM_PROMPT = (
    "You are an expert in parrot (companion bird) care. "
    "IMPORTANT: Always respond in the SAME language as the user's message. "
    "If the user writes in Korean, reply in Korean. "
    "If the user writes in Chinese, reply in Chinese. "
    "If the user writes in English, reply in English. "
    "Match the user's language exactly.\n\n"
    "Answer kindly and accurately. ..."
)
```

**2. RAG 컨텍스트 강제 지시 강화 (L153-159)**
```python
# Before
"위 데이터를 참고하여 이 앵무새에 맞는 맞춤 답변을 제공해."

# After
"CRITICAL: You MUST reference the health data above in your answer. "
"When the user asks about weight, diet, or water intake, cite the specific numbers from the data. "
"Always personalize your advice based on this parrot's actual records. "
"Do not give generic answers when specific data is available."
```

**3. API 파라미터 전달 버그 수정 (L178-183)**
```python
# Before (temperature, max_tokens 무시)
response = await _openai_client.chat.completions.create(
    model=MODEL, messages=messages,
)

# After
response = await _openai_client.chat.completions.create(
    model=MODEL, messages=messages,
    temperature=temperature, max_tokens=max_tokens,
)
```

---

## 17. 체중 기록 화면 하드코딩 한국어 → 로컬라이제이션 적용

**파일**: [weight_detail_screen.dart](../../lib/src/screens/weight/weight_detail_screen.dart), ARB 파일 3개

### 문제
체중 기록 화면에서 로컬라이제이션 키가 이미 존재함에도 한국어를 하드코딩하여, 중국어/영어 모드에서도 한국어가 그대로 표시됨.

### 하드코딩 수정 5곳

| 위치 | 하드코딩 | 수정 |
|------|---------|------|
| L752 (월간 차트 라벨) | `'${m.month}월'` | `l10n.weightDetail_monthChartLabel(m.month)` (새 키) |
| L900-905 (기록 요약) | `'$_petName의 몸무게 총 '` + `'$_totalRecordDays일'` + `' 기록 중'` | `l10n.weightDetail_recordSummary(...)` (기존 키) |
| L951 (캘린더 헤더) | `'$_selectedYear년 $_selectedMonth월'` | `l10n.weightDetail_yearMonth(...)` (기존 키) |
| L1266 (일정 날짜) | `'${date.month}월 ${date.day}일 ($weekday)'` | `l10n.schedule_dateDisplay(...)` (새 키) |
| L1409 (알림 시간) | `'${schedule.reminderMinutes}분 전'` | `l10n.schedule_reminderMinutes(...)` (기존 키) |

### 새 로컬라이제이션 키 2개

| 키 | 한국어 | 영어 | 중국어 |
|----|--------|------|--------|
| `weightDetail_monthChartLabel` | {month}월 | M{month} | {month}月 |
| `schedule_dateDisplay` | {month}월 {day}일 ({weekday}) | {month}/{day} ({weekday}) | {month}月{day}日（{weekday}） |
