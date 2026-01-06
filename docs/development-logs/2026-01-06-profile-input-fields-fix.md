# 프로필 화면 입력 필드 스타일 통일 및 UI 개선

**날짜**: 2026-01-06
**파일**:
- [lib/src/screens/profile/pet_profile_detail_screen.dart](../../lib/src/screens/profile/pet_profile_detail_screen.dart)
- [assets/images/profile/pet_profile_placeholder.svg](../../assets/images/profile/pet_profile_placeholder.svg)
- [assets/images/profile/back_arrow.svg](../../assets/images/profile/back_arrow.svg)

## 구현 목표

- 반려동물 프로필 상세 페이지의 모든 입력 필드 스타일을 완전히 통일
- TextField의 기본 회색 배경 제거 및 깨끗한 하얀색 배경 적용
- SVG 아이콘의 CSS 변수 문제 해결
- 뒤로가기 버튼 정렬 및 저장 버튼 위치 개선

## 주요 변경 사항

### 1. TextField 배경색 문제 해결 ⭐

**문제**: Material TextField의 기본 회색 배경이 계속 표시되는 문제

**해결 방법**:
```dart
// Container에 명시적 배경색 및 패딩 설정
Container(
  height: 60,
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: const Color(0xFF97928A), width: 1),
    borderRadius: BorderRadius.circular(16),
  ),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  alignment: Alignment.centerLeft,
  child: Theme(
    // 커서 색상 오버라이드
    data: ThemeData(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brandPrimary,
      ),
    ),
    child: TextFormField(
      // ...
      decoration: InputDecoration(
        filled: false,              // ✅ 명시적으로 비활성화
        fillColor: Colors.transparent, // ✅ 투명 배경
        isDense: true,              // ✅ 컴팩트 레이아웃
        contentPadding: EdgeInsets.zero, // ✅ 내부 패딩 제거
        // 모든 border 상태를 none으로 설정
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      ),
    ),
  ),
)
```

**핵심 포인트**:
- `filled: false` - Material TextField의 기본 배경 채우기 비활성화
- `fillColor: Colors.transparent` - 배경색을 투명으로 설정
- `isDense: true` - 불필요한 내부 공간 제거
- `contentPadding: EdgeInsets.zero` - TextField 내부 패딩 제거 (Container의 padding 사용)
- 6가지 border 상태를 모두 `InputBorder.none`으로 설정
- Container의 `alignment: Alignment.centerLeft`로 텍스트 정렬

### 2. SVG 파일 CSS 변수 수정

**문제**: SVG 파일에 `var(--fill-0, #D9D9D9)` 형식의 CSS 변수가 포함되어 flutter_svg가 렌더링 실패

**수정 파일**:
- `pet_profile_placeholder.svg`: 모든 `var(--fill-0, ...)` → 실제 색상 값으로 변경
- `back_arrow.svg`: `var(--stroke-0, #1A1A1A)` → `#1A1A1A`로 변경

**변경 예시**:
```xml
<!-- 변경 전 -->
<circle fill="var(--fill-0, #D9D9D9)" />

<!-- 변경 후 -->
<circle fill="#D9D9D9" />
```

### 3. 뒤로가기 버튼 정렬 수정

**기존**: `Positioned(left: 0)` 사용으로 수직 정렬 불완전

**변경**: `Align` 위젯으로 수직 중앙 정렬
```dart
Stack(
  children: [
    // 뒤로가기 버튼
    Align(
      alignment: Alignment.centerLeft,  // ✅ 수직/수평 모두 정렬
      child: GestureDetector(/* ... */),
    ),
    // 제목
    Center(
      child: Text('프로필'),
    ),
  ],
)
```

### 4. 저장 버튼 위치 변경

**기존**: 화면 하단 고정 (`Column`의 마지막 child)

**변경**: 스크롤 영역 내부로 이동
```dart
SingleChildScrollView(
  child: Column(
    children: [
      _buildProfileImage(),
      _buildInputFields(),
      const SizedBox(height: 32),
      // ✅ 저장 버튼을 스크롤 영역 내부로 이동
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: _buildSaveButton(),
      ),
      const SizedBox(height: 32),
    ],
  ),
)
```

### 5. 입력 필드 스타일 완전 통일

**공통 스타일 적용**:
- 높이: `60px`
- 배경색: `Colors.white`
- 테두리: `Color(0xFF97928A)`, 두께 `1px`
- 모서리: `16px` 둥근 모서리
- 패딩: `horizontal: 20, vertical: 20`
- 폰트: Pretendard 14px

**적용된 위젯**:
1. **TextField** (이름, 몸무게, 종)
2. **성별 선택기** (GestureDetector + Container)
3. **날짜 선택기** (생일, 가족이 된 날)

## Analyzer Warnings 수정

### 1. home_screen.dart
```dart
// 변경 전
bool _hasWeightData = false;
bool _hasFoodData = false;
bool _hasWaterData = false;

// 변경 후
final bool _hasWeightData = false;  // ✅ final 추가
final bool _hasFoodData = false;
final bool _hasWaterData = false;
```

### 2. profile_screen.dart
```dart
// 변경 전
String _userName = '쿼카16978님';

// 변경 후
final String _userName = '쿼카16978님';  // ✅ final 추가
```

### 3. weight_detail_screen.dart
```dart
// 변경 전
_MonthlyGuideLinePainter({
  // ...
  this.lineHeightFactor = 0.7,  // ❌ 사용되지 않는 파라미터
})

final double lineHeightFactor;

// 변경 후
_MonthlyGuideLinePainter({
  // lineHeightFactor 파라미터 제거
  this.drawBackground = true,
  this.drawLabel = false,
})

// 하드코딩된 값 사용
final lineHeight = size.height * 0.7;  // ✅ 직접 계산
```

## UI 개선 효과

- ✅ 모든 입력 필드가 깨끗한 하얀색 배경으로 통일
- ✅ 텍스트 입력, 선택 필드 간 시각적 일관성 확보
- ✅ Material TextField의 불필요한 기본 스타일 완전 제거
- ✅ SVG 아이콘 정상 표시 (프로필 이미지, 편집 버튼, 뒤로가기)
- ✅ 뒤로가기 버튼 정확한 수직 정렬
- ✅ 저장 버튼의 자연스러운 배치 (스크롤 영역 내부)
- ✅ 모든 analyzer warnings 제거

## 기술적 세부사항

### TextField 배경 문제의 원인

Material Design의 TextField는 기본적으로 다음과 같은 동작을 합니다:
1. `filled` 속성이 설정되지 않으면 테마의 기본값 사용
2. `InputDecoration`의 `fillColor`가 지정되지 않으면 회색 배경 적용
3. 단순히 `Container`의 배경색만 설정해도 TextField 내부 배경이 우선 표시됨

### 해결 전략

1. **Container 레벨**에서 배경색 및 테두리 제어
2. **Theme 오버라이드**로 커서 색상 등 세부 스타일 제어
3. **InputDecoration**에서 모든 배경 관련 속성 명시적으로 비활성화
4. **contentPadding을 zero**로 설정하고 Container의 padding 사용

이 방식으로 Material TextField의 기본 스타일을 완전히 제거하고 커스텀 스타일만 적용할 수 있습니다.

## 코드 위치

- TextField 구현: [pet_profile_detail_screen.dart:228-286](../../lib/src/screens/profile/pet_profile_detail_screen.dart#L228-L286)
- 성별 선택기: [pet_profile_detail_screen.dart:288-321](../../lib/src/screens/profile/pet_profile_detail_screen.dart#L288-L321)
- 날짜 선택기: [pet_profile_detail_screen.dart:323-355](../../lib/src/screens/profile/pet_profile_detail_screen.dart#L323-L355)
- 뒤로가기 버튼: [pet_profile_detail_screen.dart:83-121](../../lib/src/screens/profile/pet_profile_detail_screen.dart#L83-L121)
- 저장 버튼 위치: [pet_profile_detail_screen.dart:63-67](../../lib/src/screens/profile/pet_profile_detail_screen.dart#L63-L67)
