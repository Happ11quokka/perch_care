# Flutter 홈 화면 구현 및 UI 개선

**날짜**: 2025-11-08
**파일**:
- [lib/src/screens/home/home_screen.dart](../../lib/src/screens/home/home_screen.dart)
- [lib/src/router/app_router.dart](../../lib/src/router/app_router.dart)
- [lib/src/screens/login/login_screen.dart](../../lib/src/screens/login/login_screen.dart)

---

## 구현 목표

반려동물 케어 앱의 메인 대시보드인 홈 화면을 구현합니다:

1. **앱바**: 반려동물 선택 드롭다운, 알림, 프로필 아이콘
2. **AI 카메라 배너**: 건강 체크 유도 CTA
3. **캘린더 위젯**: 주간 달력과 날짜 선택 기능
4. **AI 체크 섹션**: 반려동물 건강 체크 안내
5. **하단 카드**: 체중 기록 및 AI 백과사전
6. **브랜드 디자인 시스템**: 일관된 색상, 그림자, 타이포그래피 적용

---

## 1. 홈 화면 기본 구조 구현

### 1.1 전체 화면 레이아웃

```dart
Scaffold
└─ SafeArea
   └─ SingleChildScrollView
      └─ Padding (16px)
         └─ Column
            ├─ _buildAppBar()
            ├─ _buildAICameraBanner()
            ├─ _buildCalendar()
            ├─ _buildAICheckSection()
            └─ _buildBottomCards()
```

**디자인 결정**:
- 배경색: `AppColors.gray50` (연한 회색으로 카드들이 돋보이도록)
- 스크롤 가능: 콘텐츠가 많아질 경우 대비
- 섹션 간 간격: `AppSpacing.lg` (24px)로 통일

### 1.2 상태 관리

```dart
class _HomeScreenState extends State<HomeScreen> {
  DateTime selectedDate = DateTime.now();  // 선택된 날짜
  String selectedPet = '사랑이';           // 선택된 반려동물 이름

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

**향후 확장**:
- 반려동물 목록은 서버에서 가져와 동적으로 표시
- 날짜별 기록 데이터 연동

---

## 2. 앱바 구현

### 2.1 반려동물 선택 드롭다운

```dart
Container(
  padding: const EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  ),
  decoration: BoxDecoration(
    color: Colors.white,
    border: Border.all(color: AppColors.brandPrimary, width: 2),
    borderRadius: BorderRadius.circular(AppRadius.md),
    boxShadow: [
      BoxShadow(
        color: AppColors.brandPrimary.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Row(
    children: [
      Text('🐶', style: const TextStyle(fontSize: 20)),
      const SizedBox(width: AppSpacing.xs),
      Text(
        selectedPet,
        style: AppTypography.bodyLarge.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.nearBlack,
        ),
      ),
      const SizedBox(width: AppSpacing.xs),
      Icon(Icons.arrow_drop_down, size: 24, color: AppColors.brandPrimary),
    ],
  ),
)
```

**디자인 포인트**:
- 브랜드 컬러 2px 테두리로 강조
- 브랜드 컬러 섀도우로 입체감
- 드롭다운 아이콘은 브랜드 컬러로 통일

### 2.2 알림 및 프로필 아이콘

```dart
Row(
  children: [
    Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.notifications_outlined, size: 24, color: AppColors.nearBlack),
            onPressed: () {},
          ),
        ),
        Positioned(
          right: 10,
          top: 10,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    ),
    const SizedBox(width: AppSpacing.xs),
    Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(Icons.person_outline, size: 24, color: AppColors.nearBlack),
        onPressed: () {},
      ),
    ),
  ],
)
```

**UI 개선 포인트**:
- 아이콘 버튼을 흰색 원형 배경으로 감싸 일관성 확보
- 부드러운 그림자로 플로팅 효과
- 알림 배지는 `error` 컬러로 시선 유도

---

## 3. AI 카메라 배너

### 3.1 그라디언트 배경

```dart
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(AppSpacing.lg),
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [
        AppColors.gradientTop,     // #FDCD66
        AppColors.brandPrimary,    // #FF9A42
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(AppRadius.lg),
    boxShadow: [
      BoxShadow(
        color: AppColors.brandPrimary.withOpacity(0.3),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  ),
  child: Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI카메라로 우리 아이',
              style: AppTypography.h6.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              '건강 체크해주세요',
              style: AppTypography.h6.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text('📱', style: const TextStyle(fontSize: 36)),
        ),
      ),
    ],
  ),
)
```

**디자인 특징**:
- 브랜드 그라디언트 활용으로 시선 유도
- 흰색 텍스트로 강한 대비
- 브랜드 컬러 그림자로 입체감과 중요도 강조
- 아이콘 배경에 그림자를 추가하여 레이어 분리

---

## 4. 캘린더 위젯

### 4.1 캘린더 헤더

```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: [
        Text(
          '${selectedDate.year}년 ${selectedDate.month.toString().padLeft(2, '0')}월 ${selectedDate.day.toString().padLeft(2, '0')}일',
          style: AppTypography.h6.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
          ),
        ),
        Icon(Icons.arrow_drop_down, size: 24, color: AppColors.mediumGray),
      ],
    ),
    Container(
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: IconButton(
        icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.brandPrimary),
        onPressed: () {},
      ),
    ),
  ],
)
```

### 4.2 주간 캘린더 구현

```dart
Widget _buildWeekCalendar() {
  final now = DateTime.now();
  final startOfWeek = now.subtract(Duration(days: now.weekday % 7 - 1));

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: List.generate(7, (index) {
      final date = startOfWeek.add(Duration(days: index));
      final isSelected = date.day == selectedDate.day &&
          date.month == selectedDate.month &&
          date.year == selectedDate.year;
      final weekdays = ['일', '월', '화', '수', '목', '금', '토'];

      return GestureDetector(
        onTap: () {
          setState(() {
            selectedDate = date;
          });
        },
        child: Container(
          width: 45,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Column(
            children: [
              Text(
                weekdays[date.weekday % 7],
                style: AppTypography.bodySmall.copyWith(
                  color: isSelected ? Colors.white : AppColors.mediumGray,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date.day.toString(),
                style: AppTypography.h6.copyWith(
                  color: isSelected ? Colors.white : AppColors.nearBlack,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }),
  );
}
```

**주요 로직**:
- `now.weekday % 7 - 1`: 주의 시작(일요일) 계산
- `List.generate(7, ...)`: 7일치 날짜 동적 생성
- `isSelected` 조건으로 선택 상태 표시
- `setState()`: 날짜 선택 시 UI 즉시 업데이트

**디자인 포인트**:
- 선택된 날짜: 브랜드 컬러 배경 + 흰색 텍스트
- 미선택 날짜: 투명 배경 + 회색/검정 텍스트
- 45px 고정 너비로 균등 배치

---

## 5. AI 체크 섹션

```dart
Widget _buildAICheckSection() {
  return Container(
    padding: const EdgeInsets.all(AppSpacing.lg),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI체크',
                style: AppTypography.h5.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.nearBlack,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'AI카메라로 우리 아이 건강을',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mediumGray,
                ),
              ),
              Text(
                '직접 체크해 보세요',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _buildPetAvatar('🐶'),
            _buildPetAvatar('🐱'),
            _buildPetAvatar('🦜'),
            _buildPetAvatar('🐹'),
          ],
        ),
      ],
    ),
  );
}

Widget _buildPetAvatar(String emoji) {
  return Container(
    margin: const EdgeInsets.only(left: 8),
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: AppColors.gray100,
      shape: BoxShape.circle,
    ),
    child: Center(
      child: Text(emoji, style: const TextStyle(fontSize: 24)),
    ),
  );
}
```

**UI 요소**:
- 왼쪽: 제목 + 설명 텍스트
- 오른쪽: 4개의 반려동물 아바타 (원형, 8px 간격)
- 전체 카드에 부드러운 그림자 적용

---

## 6. 하단 카드 (체중 / AI 백과사전)

### 6.1 카드 레이아웃

```dart
Widget _buildBottomCards() {
  return Row(
    children: [
      Expanded(
        child: _buildCard(
          title: '체중',
          value: '0',
          unit: 'g',
          color: Colors.lightBlue.shade100,
          iconColor: Colors.blue,
        ),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: _buildCard(
          title: 'AI 백과사전',
          value: '0',
          unit: 'g',
          color: Colors.brown.shade100,
          iconColor: Colors.brown,
        ),
      ),
    ],
  );
}
```

### 6.2 공통 카드 위젯

```dart
Widget _buildCard({
  required String title,
  required String value,
  required String unit,
  required Color color,
  required Color iconColor,
}) {
  return Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTypography.h6.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.nearBlack,
              ),
            ),
            Icon(Icons.chevron_right, size: 24, color: AppColors.mediumGray),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const SizedBox(height: AppSpacing.xl),
        const SizedBox(height: AppSpacing.xl),
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: iconColor, size: 20),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '$value$unit',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

**디자인 특징**:
- 제목과 chevron 아이콘으로 탭 가능한 느낌
- 하단 우측에 값 표시 영역 배치
- 값 영역: 컬러별 배경 + 아이콘 + 텍스트
- 컬러별 그림자로 입체감 부여

---

## 7. 색상 에러 해결 및 UI 개선

### 7.1 문제 상황

초기 구현 시 존재하지 않는 색상을 사용하여 빌드 에러 발생:

```
Error: Member not found: 'backgroundPrimary'.
Error: Member not found: 'brandSecondary'.
Error: Member not found: 'textSecondary'.
Error: Member not found: 'textPrimary'.
Error: Member not found: 'backgroundSecondary'.
```

### 7.2 해결 방법

[colors.dart](../../lib/src/theme/colors.dart)에 정의된 색상으로 교체:

| 잘못된 색상 | 올바른 색상 | 정의 값 |
|------------|-----------|--------|
| `backgroundPrimary` | `background` | `#FFFFFF` |
| `brandSecondary` | `gradientBottom` | `#FF572D` |
| `textSecondary` | `mediumGray` | `#6B6B6B` |
| `textPrimary` | `nearBlack` | `#1A1A1A` |
| `backgroundSecondary` | `gray100` | `#F5F5F5` |

### 7.3 브랜드 디자인 시스템 적용

앱 테마에 맞춰 전체적인 UI 개선:

**배경색 변경**:
```dart
backgroundColor: AppColors.gray50,  // 연한 회색으로 카드 강조
```

**일관된 그림자 적용**:
```dart
boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.05),
    blurRadius: 12,
    offset: const Offset(0, 2),
  ),
]
```

**브랜드 그라디언트 활용**:
```dart
gradient: const LinearGradient(
  colors: [
    AppColors.gradientTop,     // #FDCD66
    AppColors.brandPrimary,    // #FF9A42
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
)
```

**폰트 굵기 강화**:
- 제목: `FontWeight.w700`
- 본문: `FontWeight.w600`
- 보조 텍스트: 기본 또는 `w500`

---

## 8. 라우팅 구성

### 8.1 홈 라우트 추가

**app_router.dart**:
```dart
import '../screens/home/home_screen.dart';

static final GoRouter router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    // ... 기존 라우트들
    GoRoute(
      path: RoutePaths.home,
      name: RouteNames.home,
      builder: (context, state) => const HomeScreen(),
    ),
  ],
);
```

### 8.2 테스트 로그인 버튼 추가

로그인 기능 미완성 상태에서 홈 화면 테스트를 위한 임시 버튼:

**login_screen.dart**:
```dart
SizedBox(
  width: 311,
  child: OutlinedButton(
    onPressed: () {
      context.goNamed(RouteNames.home);
    },
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      side: const BorderSide(
        color: AppColors.brandPrimary,
        width: 2,
      ),
    ),
    child: const Text(
      '테스트 로그인',
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.brandPrimary,
      ),
    ),
  ),
)
```

**디자인 특징**:
- SNS 로그인 버튼 아래 배치
- 브랜드 컬러 아웃라인 스타일
- 실제 로그인 버튼(그라디언트)과 시각적으로 구분

**네비게이션 플로우**:
```
[Splash] → [Login] → [Home]
                     (테스트 로그인)
```

---

## 배운 점

### 1. **디자인 시스템의 중요성**

일관된 색상, 간격, 그림자를 사용하면:
- 전문적이고 통일감 있는 UI
- 코드 재사용성 증가
- 디자인 변경 시 중앙 집중식 관리 가능

**Before**:
```dart
color: Color(0xFF6B6B6B),  // 하드코딩
```

**After**:
```dart
color: AppColors.mediumGray,  // 디자인 시스템 사용
```

### 2. **상태 기반 UI 렌더링**

Flutter의 선언적 UI 패턴 활용:
```dart
final isSelected = date.day == selectedDate.day;

decoration: BoxDecoration(
  color: isSelected ? AppColors.brandPrimary : Colors.transparent,
),
```

- 상태(`selectedDate`)가 변경되면 UI 자동 업데이트
- 조건부 스타일링으로 직관적인 코드

### 3. **반응형 레이아웃 설계**

`Expanded`와 `Row` 조합으로 유연한 레이아웃:
```dart
Row(
  children: [
    Expanded(child: _buildCard(...)),  // 50% 너비
    const SizedBox(width: AppSpacing.md),
    Expanded(child: _buildCard(...)),  // 50% 너비
  ],
)
```

- 화면 크기에 따라 자동으로 카드 너비 조정
- 균등 분할로 깔끔한 배치

### 4. **DateTime 계산**

주간 캘린더 구현 시 날짜 계산:
```dart
final now = DateTime.now();
final startOfWeek = now.subtract(Duration(days: now.weekday % 7 - 1));
final date = startOfWeek.add(Duration(days: index));
```

- `weekday % 7 - 1`: 일요일부터 시작하도록 조정
- `subtract`, `add`로 날짜 이동

### 5. **코드 모듈화**

공통 위젯을 헬퍼 메서드로 분리:
```dart
Widget _buildCard({...}) { ... }
Widget _buildPetAvatar(String emoji) { ... }
```

**장점**:
- 중복 코드 제거
- 수정 시 한 곳만 변경
- 테스트 및 재사용 용이

### 6. **그림자 활용**

부드러운 그림자로 깊이감 표현:
```dart
boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.05),  // 5% 불투명도
    blurRadius: 12,
    offset: const Offset(0, 2),  // 아래쪽으로 2px
  ),
]
```

- `0.05` 불투명도: 지나치게 강하지 않은 자연스러운 그림자
- `Offset(0, 2)`: 카드가 살짝 떠 있는 느낌

### 7. **GoRouter 네비게이션**

```dart
context.goNamed(RouteNames.home);  // 스택 교체 (뒤로가기 불가)
context.pushNamed(RouteNames.home);  // 스택 추가 (뒤로가기 가능)
```

- 테스트 로그인은 `goNamed` 사용 (로그인 화면으로 돌아가지 않도록)
- 실제 로그인 시에는 `goNamed`로 스택 리셋 필요

### 8. **withOpacity() → withValues() 마이그레이션**

Flutter 3.27부터 `Color.withOpacity()`가 deprecated 되어 `Color.withValues()`로 교체:

**Before (Deprecated)**:
```dart
color: AppColors.brandPrimary.withOpacity(0.1),
```

**After (Recommended)**:
```dart
color: AppColors.brandPrimary.withValues(alpha: 0.1),
```

**변경 이유**:

1. **정밀도 향상**
   - `withOpacity()`: 0.0 ~ 1.0 범위의 double 값 사용
   - `withValues()`: Named parameter로 더 명확한 의도 표현
   - 부동 소수점 연산으로 인한 정밀도 손실 방지

2. **API 일관성**
   ```dart
   // withValues()는 모든 색상 채널을 명시적으로 변경 가능
   color.withValues(
     alpha: 0.5,      // 투명도
     red: 1.0,        // 빨강 채널
     green: 0.8,      // 초록 채널
     blue: 0.6,       // 파랑 채널
   )
   ```

3. **타입 안전성**
   - Named parameter로 실수로 잘못된 값 전달 방지
   - IDE 자동완성 지원 향상

**프로젝트 전체 수정 항목**:
```dart
// 1. 브랜드 컬러 그림자
AppColors.brandPrimary.withValues(alpha: 0.1)   // 10% 투명도
AppColors.brandPrimary.withValues(alpha: 0.3)   // 30% 투명도

// 2. 검정 그림자
Colors.black.withValues(alpha: 0.05)   // 5% 투명도
Colors.black.withValues(alpha: 0.1)    // 10% 투명도

// 3. 동적 색상 그림자
iconColor.withValues(alpha: 0.2)       // 20% 투명도
```

**마이그레이션 팁**:
- VSCode/Android Studio의 Quick Fix(Cmd/Ctrl + .)로 자동 변환 가능
- 프로젝트 전체 검색: `withOpacity` → 일괄 교체
- `flutter analyze`로 모든 deprecated 사용 감지

---

## 파일 구조

```
lib/src/
├── screens/
│   ├── home/
│   │   └── home_screen.dart         (500줄)
│   └── login/
│       └── login_screen.dart        (테스트 로그인 버튼 추가)
├── router/
│   └── app_router.dart              (home 라우트 추가)
└── theme/
    ├── colors.dart                  (브랜드 색상 정의)
    ├── typography.dart              (텍스트 스타일)
    ├── spacing.dart                 (간격 상수)
    └── radius.dart                  (둥근 모서리 상수)
```

---

## 다음 단계

### 1. **데이터 연동**

```dart
// TODO: 반려동물 목록 가져오기
List<Pet> pets = await petService.getPets();

// TODO: 날짜별 기록 조회
List<Record> records = await recordService.getRecordsByDate(selectedDate);
```

### 2. **기능 구현**

- **반려동물 선택 드롭다운**: 실제 선택 UI 및 상태 변경
- **캘린더 월 변경**: 좌우 스와이프 또는 월 선택 다이얼로그
- **체중 기록**: 입력 모달 및 그래프 표시
- **AI 백과사전**: 검색 및 카테고리 탐색

### 3. **애니메이션 추가**

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Text(
    selectedPet,
    key: ValueKey(selectedPet),
  ),
)
```

- 반려동물 전환 시 부드러운 애니메이션
- 카드 탭 시 리플 효과

### 4. **로딩 상태 처리**

```dart
bool _isLoading = true;

@override
void initState() {
  super.initState();
  _loadData();
}

Future<void> _loadData() async {
  setState(() => _isLoading = true);
  try {
    await Future.wait([
      _loadPets(),
      _loadRecords(),
    ]);
  } finally {
    setState(() => _isLoading = false);
  }
}
```

### 5. **에러 처리**

- 네트워크 에러 시 재시도 UI
- 데이터 없을 때 Empty State

### 6. **접근성 개선**

```dart
Semantics(
  label: '${date.day}일',
  button: true,
  selected: isSelected,
  child: GestureDetector(...),
)
```

---

## 결론

✅ **완성된 홈 화면 레이아웃** - 앱바, 배너, 캘린더, 카드 섹션
✅ **브랜드 디자인 시스템 적용** - 일관된 색상, 그림자, 타이포그래피
✅ **주간 캘린더 구현** - 날짜 선택 및 상태 관리
✅ **반응형 카드 레이아웃** - Expanded로 균등 분할
✅ **테스트 로그인 기능** - 개발 중 홈 화면 접근
✅ **모듈화된 코드 구조** - 재사용 가능한 헬퍼 메서드

반려동물 케어 앱의 메인 대시보드가 완성되었으며, 향후 실제 데이터를 연동하면 서비스 가능한 수준입니다. 🎯
