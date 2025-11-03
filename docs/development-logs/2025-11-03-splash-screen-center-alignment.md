# Flutter 스플래시 화면 원형 요소 중앙 정렬 문제 해결

**날짜**: 2025-11-03
**파일**: [lib/src/screens/splash/splash_screen.dart](../../lib/src/screens/splash/splash_screen.dart)

## 문제 정의

Flutter 앱의 스플래시 화면에서 동심원 구조의 애니메이션을 구현했는데, 외부 원과 중간 원이 브랜드 아이콘을 기준으로 중앙 정렬되지 않는 문제가 발생했습니다.

### 기존 코드의 문제점

```dart
// 배경 원형 링들 (바깥쪽) - 애니메이션
Positioned(
  left: -53,
  top: 177,
  child: Transform.scale(
    scale: _outerCircleScale.value,
    child: // ...
  ),
),
// 중간 원형 링 - 애니메이션
Positioned(
  left: 25,
  top: 256,
  child: Transform.scale(
    scale: _middleCircleScale.value,
    child: // ...
  ),
),
```

`Positioned` 위젯을 사용하여 고정된 좌표(`left`, `top`)로 원들을 배치했기 때문에:
- 화면 크기나 비율이 달라지면 정렬이 깨질 수 있음
- 브랜드 아이콘(`Center` 위젯으로 화면 중앙에 배치)과 시각적으로 중심이 맞지 않음
- 유지보수 시 위치 조정이 어려움

## 문제 해결 방법

`Positioned` 위젯을 `Center` 위젯으로 변경하여 모든 원형 요소가 화면 중앙을 기준으로 정렬되도록 수정했습니다.

### 수정된 코드

```dart
// 배경 원형 링들 (바깥쪽) - 애니메이션
Center(
  child: Transform.scale(
    scale: _outerCircleScale.value,
    child: Opacity(
      opacity: _outerCircleScale.value * 0.25,
      child: SvgPicture.asset(
        'assets/images/ellipse-67.svg',
        width: 499,
        height: 499,
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: 0.25),
          BlendMode.srcIn,
        ),
      ),
    ),
  ),
),
// 중간 원형 링 - 애니메이션
Center(
  child: Transform.scale(
    scale: _middleCircleScale.value,
    child: Opacity(
      opacity: _middleCircleScale.value * 0.5,
      child: SvgPicture.asset(
        'assets/images/ellipse-67.svg',
        width: 342,
        height: 342,
        colorFilter: ColorFilter.mode(
          Colors.white.withValues(alpha: 0.5),
          BlendMode.srcIn,
        ),
      ),
    ),
  ),
),
```

### 변경 사항
- **외부 원**: `Positioned(left: -53, top: 177)` → `Center()`
- **중간 원**: `Positioned(left: 25, top: 256)` → `Center()`
- **내부 원**: 기존부터 `Center()` 사용 (변경 없음)

## 느낀 점

### 1. **절대 위치 vs 상대 위치의 중요성**
Flutter에서 레이아웃을 구성할 때 `Positioned`와 같은 절대 위치 기반 위젯은 특정 상황에서 유용하지만, 중앙 정렬이나 반응형 디자인이 필요한 경우 `Center`, `Align` 같은 상대 위치 기반 위젯이 훨씬 효과적입니다.

### 2. **동심원 구조의 일관성**
세 개의 원이 모두 같은 중심점을 공유해야 하는 상황에서, 하나만 `Center`로 배치하고 나머지를 `Positioned`로 배치하면 시각적 불일치가 발생할 수밖에 없습니다. **같은 구조의 요소는 같은 방식으로 배치**하는 것이 중요하다는 것을 다시 한번 깨달았습니다.

### 3. **코드의 간결성과 유지보수성**
- 수정 전: 각 원마다 고정 좌표 계산 필요
- 수정 후: 모든 원이 자동으로 중앙 정렬

코드가 더 간결해졌을 뿐만 아니라, 향후 원의 크기를 변경하거나 디자인을 조정할 때도 위치 재계산 없이 쉽게 수정할 수 있게 되었습니다.

### 4. **Stack 위젯의 특성 이해**
`Stack` 내부에서 여러 요소를 겹쳐 배치할 때, `Center` 위젯을 여러 번 사용해도 모두 같은 중심점을 공유한다는 점을 활용하면 동심원 같은 디자인 패턴을 매우 쉽게 구현할 수 있습니다.

---

이번 수정을 통해 스플래시 화면의 애니메이션이 시각적으로 더 조화롭고, 다양한 화면 크기에서도 일관되게 동작하는 코드가 되었습니다. 🎯
