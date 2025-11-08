# Flutter 스플래시 화면 OverflowBox 기반 반응형 애니메이션 구현

**날짜**: 2025-11-03
**파일**: [lib/src/screens/splash/splash_screen.dart](../../lib/src/screens/splash/splash_screen.dart)

## 구현 목표

스플래시 화면에서 동심원 구조의 애니메이션을 구현하되, 다음 요구사항을 만족해야 합니다:

1. **중앙 정렬**: 모든 원이 화면 중앙을 기준으로 완벽하게 정렬
2. **반응형 디자인**: 다양한 화면 크기에서 일관된 비율 유지
3. **화면 밖 렌더링**: 외부 원이 화면 밖으로 넘어가도 정상 표시
4. **시간차 애니메이션**: 내부 → 중간 → 외부 원 순서로 순차적 등장
5. **코드 모듈화**: 재사용 가능하고 유지보수하기 쉬운 구조

---

## 핵심 구현 방법

### 1. OverflowBox를 활용한 화면 밖 렌더링

일반적으로 Flutter의 위젯은 부모의 제약(constraints) 내에서만 렌더링됩니다. 하지만 **OverflowBox**를 사용하면 부모 제약을 무시하고 더 큰 크기로 자식을 렌더링할 수 있습니다.

```dart
Widget _buildCircle({
  required double size,
  required double scale,
  required double opacity,
  bool useOverflow = false,
}) {
  final circle = Transform.scale(
    scale: scale,
    child: Opacity(
      opacity: opacity,
      child: SvgPicture.asset(
        'assets/images/ellipse-67.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: opacity),
          BlendMode.srcIn,
        ),
      ),
    ),
  );

  if (useOverflow) {
    return OverflowBox(
      maxWidth: size * 1.5,   // 원래 크기의 1.5배까지 허용
      maxHeight: size * 1.5,
      alignment: Alignment.center,
      child: circle,
    );
  }

  return circle;
}
```

**핵심 포인트**:
- `maxWidth`, `maxHeight`: 자식이 렌더링될 수 있는 최대 크기 지정
- `alignment: Alignment.center`: 중앙 정렬 유지
- `useOverflow` 플래그로 필요한 경우에만 OverflowBox 사용

---

### 2. MediaQuery를 통한 반응형 크기 계산

고정 크기 대신 화면 크기에 비례한 동적 크기 계산:

```dart
({double inner, double middle, double outer}) _calculateCircleSizes(
    Size screenSize) {
  final width = screenSize.width;

  return (
    inner: width * 0.52,        // 화면 너비의 52%
    middle: width * 0.89,       // 화면 너비의 89% (내부 원의 약 1.7배)
    outer: width * 1.35,        // 화면 너비의 135% (중간 원의 약 1.5배, 화면 밖으로 넘침)
  );
}
```

**크기 비율 설정 이유**:
- **내부 원 (52%)**: 브랜드 로고가 들어갈 기준 크기
- **중간 원 (89%)**: 내부 원과 적절한 간격 유지
- **외부 원 (135%)**: 화면 너비를 초과하여 가장자리에서 일부만 보이도록

**Named Records 활용**:
- Dart 3의 Named Records 문법 `(inner: ..., middle: ..., outer: ...)` 사용
- 반환 값의 의미가 명확하고 가독성 향상
- `sizes.inner`, `sizes.middle`, `sizes.outer`로 직관적 접근

---

### 3. Stack의 clipBehavior 설정

```dart
Stack(
  clipBehavior: Clip.none,  // 중요: 화면 밖으로 넘어간 요소도 렌더링
  children: [
    // 원형 위젯들...
  ],
)
```

**clipBehavior: Clip.none의 역할**:
- 기본값은 `Clip.hardEdge`로, 부모 영역을 벗어난 자식을 잘라냄
- `Clip.none`으로 설정하면 화면 밖 요소도 정상적으로 표시
- OverflowBox와 함께 사용하여 외부 원이 화면 밖으로 넘어가도록 구현

---

### 4. 시간차 애니메이션 구현

각 원이 순차적으로 나타나도록 `Interval`을 활용:

```dart
// 애니메이션 컨트롤러 (총 2초)
_controller = AnimationController(
  duration: const Duration(milliseconds: 2000),
  vsync: this,
);

// 내부 원 - 가장 먼저 시작 (0.0 ~ 0.4초)
_innerCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
  ),
);

// 중간 원 - 약간 지연 (0.15 ~ 0.6초)
_middleCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
  ),
);

// 외부 원 - 가장 늦게 시작 (0.3 ~ 0.8초)
_outerCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
  ),
);

// 로고 - 원들이 확장된 후 나타남 (0.6 ~ 1.0초)
_logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
  CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
  ),
);
```

**애니메이션 타임라인**:
```
0.0초 ──────────────────────────────────── 2.0초
│
├─ [0.0 ~ 0.4초] 내부 원 등장 (easeOut)
│   └─ [0.15 ~ 0.6초] 중간 원 등장 (easeOut)
│       └─ [0.3 ~ 0.8초] 외부 원 등장 (easeOut)
│           └─ [0.6 ~ 1.0초] 로고 페이드인 (easeIn)
```

**Interval의 장점**:
- 하나의 AnimationController로 여러 애니메이션을 시간차 제어
- 각 애니메이션마다 다른 시작/종료 시점과 curve 적용 가능
- 코드 간결성과 동기화 용이

---

### 5. 자동 화면 전환 준비

애니메이션 완료 후 자동으로 다음 화면으로 전환:

```dart
_controller.addStatusListener((status) {
  if (status == AnimationStatus.completed) {
    // TODO: 메인 화면이 구현되면 주석 해제
    // context.go('/home');
  }
});
```

---

## 전체 위젯 구조

```
Scaffold
└─ SafeArea
   └─ AnimatedBuilder (애니메이션 리스너)
      └─ Stack (clipBehavior: Clip.none)
         ├─ Center
         │  └─ OverflowBox (외부 원)
         │     └─ Transform.scale + Opacity + SvgPicture
         │
         ├─ Center
         │  └─ OverflowBox (중간 원)
         │     └─ Transform.scale + Opacity + SvgPicture
         │
         └─ Center
            └─ Transform.scale (내부 원 + 로고)
               └─ SizedBox
                  └─ Stack
                     ├─ SvgPicture (내부 원)
                     └─ Opacity + SvgPicture (브랜드 로고)
```

---

## 크기 조정 과정

### 초기 시도
```dart
inner: width * 0.45,
middle: diagonal * 0.7,
outer: diagonal * 1.2,
```
**문제점**: 외부 원이 너무 커서 화면에서 완전히 사라짐

### 1차 수정
```dart
inner: width * 0.5,
middle: width * 1.1,
outer: diagonal * 0.95,
```
**문제점**: 원들 사이 간격이 디자인보다 너무 넓음

### 최종 버전 ✅
```dart
inner: width * 0.52,        // 화면 너비의 52%
middle: width * 0.89,       // 화면 너비의 89%
outer: width * 1.35,        // 화면 너비의 135%
```
**결과**: 디자인 의도에 맞는 적절한 간격 유지

---

## 구현 시 주요 결정 사항

### 1. 대각선 vs 화면 너비 기준
- **초기**: 대각선 길이를 기준으로 계산 → 외부 원이 너무 커짐
- **최종**: 모든 원을 화면 너비 기준으로 통일 → 일관성 있는 비율 유지

### 2. OverflowBox의 maxWidth/maxHeight
- `size * 1.5`로 설정하여 애니메이션 확장 시에도 제약이 걸리지 않도록 함
- Transform.scale이 적용되어도 충분한 여유 공간 확보

### 3. 로고 크기 비율
```dart
width: sizes.inner * 0.92,  // 내부 원의 92% 크기
height: sizes.inner * 0.92,
```
- 로고가 원 안에서 적절한 여백을 유지하도록 설정

---

## 배운 점

### 1. **OverflowBox의 활용**
Flutter에서 부모 제약을 벗어나야 하는 디자인을 구현할 때 OverflowBox가 매우 유용합니다. 특히 스플래시 화면처럼 시각적 효과가 중요한 곳에서 화면 밖으로 요소를 확장할 수 있습니다.

### 2. **반응형 크기 계산의 중요성**
고정 크기 대신 화면 크기 비율로 계산하면:
- 다양한 디바이스에서 일관된 UX 제공
- 태블릿/폴더블 기기에서도 자연스러운 표현
- 유지보수 시 비율만 조정하면 되므로 간편

### 3. **Named Records의 가독성**
Dart 3의 Named Records를 사용하면:
```dart
// Before: 튜플 형태 (위치 기반)
(double, double, double) _calculateSizes() => (100, 200, 300);
final sizes = _calculateSizes();
sizes.$1  // 의미 불명확

// After: Named Records (이름 기반)
({double inner, double middle, double outer}) _calculateSizes()
    => (inner: 100, middle: 200, outer: 300);
final sizes = _calculateSizes();
sizes.inner  // 명확하고 직관적
```

### 4. **Interval을 활용한 시간차 애니메이션**
하나의 AnimationController로 복잡한 시퀀스 애니메이션을 구현할 수 있어, 타이밍 동기화와 코드 관리가 훨씬 쉬워집니다.

### 5. **코드 모듈화의 중요성**
`_buildCircle()` 같은 헬퍼 메서드로 반복 코드를 제거하면:
- 코드 중복 감소
- 수정이 필요할 때 한 곳만 변경
- 테스트 및 디버깅 용이

### 6. **clipBehavior의 역할**
`Clip.none`을 설정하지 않으면 OverflowBox를 사용해도 화면 밖 요소가 잘릴 수 있습니다. 두 가지를 함께 사용해야 의도한 효과를 얻을 수 있습니다.

---

## 결론

이번 구현을 통해 Flutter의 레이아웃 시스템을 깊이 이해하게 되었습니다:

✅ **OverflowBox + Clip.none** 조합으로 화면 밖 렌더링 구현
✅ **MediaQuery 기반 반응형 크기 계산**으로 디바이스 대응
✅ **Interval을 활용한 시간차 애니메이션**으로 자연스러운 연출
✅ **헬퍼 메서드와 Named Records**로 코드 가독성 향상
✅ **비율 기반 크기 조정**으로 디자인 의도 정확히 구현

스플래시 화면이 모든 디바이스에서 일관되고 아름답게 동작하며, 코드 또한 확장 가능하고 유지보수하기 쉬운 구조가 되었습니다. 🎯
