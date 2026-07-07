# perch_care 모션 디자인 시스템 구축 — 페이지 전환·인터랙션 개선기

**메타**: 2026-07-07 | `feature/stage2-4-mvvm-completion` | 셀프 리뷰 10건 수정 완료 · analyze 무경고 · 테스트 297건 green

---

## 1. 한 장 요약

| 항목 | Before | After |
|------|--------|-------|
| **페이지 전환** | 100% 프레임워크 기본값 (CustomTransitionPage 사용 0건, 탭 전환 0ms 하드컷) | 브랜드 모션 시스템 (탭 크로스페이드 200ms, 플랫폼별 pageTransitionsTheme, 히어로 모먼트 fade+scale) |
| **터치 피드백** | GestureDetector 139곳 vs InkWell 8곳, HapticFeedback 0건 | 공용 피드백 레이어 (PressableScale 위젯 + 스낵바 타입별 햅틱 자동화) |
| **접근성** | MediaQuery.disableAnimations 존중 0건 | 모션 토큰 레벨에서 전 앱 일괄 지원 (AppDurations.of() 활용) |
| **데이터 시각화** | BHI 링/WCI 게이지/신뢰도 바 정적 pop-in | sweep + 카운트업 (600ms dataReveal, 500ms gauge) |
| **규모** | — | 27개 파일, +971 줄/−288 줄, 신규 공용 위젯 1개 |

---

## 2. 데이터 기반 진단

프로젝트 시작 때 "빠르지만 딱딱하다"는 문제의식을 감으로만 삼기로는 부족했다. 6개 영역(라우터 / 인증 플로우 / 홈 / 기록·차트 / AI 기능 / 공용 위젯·접근성)을 병렬로 코드 감사한 결과 58건의 잠재 개선점을 발굴했다. 각 발견마다 "반박해 보자"는 자세로 적대적 검증을 거친 후 26건을 확정했다.

**핵심 인사이트**: "애니메이션이 없는 앱이 아니라 고여 있는 앱이었다". 스플래시 동심원 스태거 연출, weight 상세의 주/월 토글 pill 슬라이드(AnimatedPositioned), 스낵바 진입(350ms)/이탈(250ms) 비대칭 커브는 이미 수준급이었는데, 그 품질이 **일관된 시스템**으로 승격되지 못하고 한두 곳에만 고여 있었다. 이를 토큰화·공용화해 전 앱에 확산하는 것이 작업의 본질이었다.

---

## 3. 설계 결정 5선

### 3.1 모션 토큰에 접근성 내장

**문제**: 애니메이션을 도입하되 OS '동작 줄이기' 사용자를 고립시킬 수 없다.  
**선택지**: (a) 매 화면마다 `if (MediaQuery.disableAnimations)` 분기 추가, (b) 토큰 레벨에서 중앙화.  
**결정 근거**: (b)를 선택했다. 토큰 헬퍼 `AppDurations.of(context, d)`가 `MediaQuery.maybeDisableAnimationsOf(context)` 체크를 일괄 처리해 `Duration.zero`를 반환하도록 했다. 모든 implicit animation이 토큰을 거치므로, 개별 화면 코드에는 분기가 0건이다. 접근성이 기본값이 된다.

```dart
// lib/src/theme/durations.dart
static Duration of(BuildContext context, Duration duration) {
  return MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : duration;
}

class AppCurves {
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasize = Curves.easeInOutCubic;
}
```

### 3.2 탭 전환 크로스페이드

**문제**: StatefulShellRoute의 indexedStack은 상태 유지가 강점이지만 탭 전환이 0ms 하드컷이다.  
**선택지**: (a) pageTransitionsTheme로 전역 전환 통일, (b) navigatorContainerBuilder 커스텀화.  
**결정 근거**: (b)를 선택했다. 상태 유지(indexedStack)의 장점을 포기하지 않으면서 AnimatedOpacity + IgnorePointer + TickerMode를 조합해 시각만 페이드한다. 입력 차단과 티커 음소거로 비활성 탭이 애니메이션을 재생하지 않으므로 프레임 낭비를 막는다.

```dart
// lib/src/router/app_router.dart — _AnimatedBranchContainer
Widget _branch(BuildContext context, int index, Widget navigator) {
  final bool active = index == currentIndex;
  return AnimatedOpacity(
    opacity: active ? 1 : 0,
    duration: AppDurations.of(context, AppDurations.branchCrossfade),
    curve: AppCurves.enter,
    child: IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: navigator,
      ),
    ),
  );
}
```

### 3.3 GlobalKey 충돌 발견 → 계획 변경

**문제**: 홈 화면 펫 전환을 AnimatedSwitcher 크로스페이드로 구성하려다, 전환 중 old/new 서브트리가 스택에 공존하면서 코치마크용 GlobalKey가 중복되는 크래시 경로를 **설계 단계에서** 발견했다.  
**선택지**: (a) GlobalKey 관계를 재설계해 허용, (b) 화려함을 포기하고 안전한 대체 애니메이션 적용.  
**결정 근거**: (b)를 선택했다. AnimatedOpacity 디밍(0.5)으로 대체했다. "구현 후 버그 수정"이 아니라 "설계 단계에서 실패 모드를 찾아 선제적으로 회피하는" 판단력의 사례다.

### 3.4 플랫폼별 pageTransitionsTheme

**문제**: iOS와 Android가 기대하는 페이지 전환 관례가 다르다 (iOS: 가장자리 스와이프 제스처, Android: Material 3 규격).  
**선택지**: (a) 양 플랫폼 일괄 M3 FadeForwards, (b) OS별 맞춤.  
**결정 근거**: (b)를 선택했다. iOS는 CupertinoPageTransitionsBuilder 유지 — 뒤로가기 스와이프 제스처 보존이 브랜드 일관성보다 우선한다. Android만 M3 FadeForwards로 브랜드화했다. 플랫폼 관례를 존중하는 것이 사용자 학습곡선을 낮춘다.

### 3.5 MVVM 계약을 지킨 pull-to-refresh

**문제**: HomeViewModel의 기존 `refreshBhi()`가 5분 TTL 캐시-우선 로직인데, pull-to-refresh는 "캐시 무시하고 강제 최신화"를 의미한다 — 의미론적 충돌.  
**선택지**: (a) ViewModel과 무관하게 Screen에서 Service 싱글턴을 직접 부르기, (b) Repository 인터페이스에 forceRefresh 파라미터 추가.  
**결정 근거**: (b)를 선택했다. Repository는 MVVM 계약이다 — Screen→Service 직결은 계약 위반이다. `HomeRepository.loadBhiForDate()`에 `forceRefresh` 파라미터를 추가하고 ViewModel에 `pullToRefresh()`를 신설해 배선했으며, Screen은 ViewModel만 호출한다. 아키텍처 일관성이 나중 리팩터링 비용을 절감한다.

---

## 4. 히어로 모먼트

AI 건강체크 결과는 앱의 최고조 모멘트다. 수십 초 분석을 기다린 후 결과가 평범한 페이드-슬라이드로 나오는 것은 대기 시간에 대한 보상이 부족했다. **fade-through 패턴**(fade + 미세 스케일 0.96→1.0 전개)으로 reveal하고, 신뢰도 게이지와 퍼센트를 카운트업으로 표현했다. 

```dart
// lib/src/widgets/pressable_scale.dart — 핵심 요약
// PressableScale: 탭 가능 요소에 눌림(scale-down) 피드백을 주는 공용 위젯
AnimatedScale(
  scale: _pressed ? widget.pressedScale : 1.0,
  duration: AppDurations.of(context, AppDurations.press),
  curve: AppCurves.enter,
  child: widget.child,
)
```

PressableScale 위젯은 Material 리플이 어울리지 않는 그라데이션·그림자 커스텀 표면에도 동작하며, reduced-motion을 존중한다(토큰 호출 덕분). 탭 시 선택적 `HapticFeedback.lightImpact()`를 추가해 터치 확인을 명시적으로 전달한다.

---

## 5. 검증 루프 — 구현만큼 중요한 단계

**이 프로젝트에서 가장 공들인 부분**: 검증을 한 바퀴가 아니라 여러 겹으로 돌렸다.

- **정적 검증**: `flutter analyze` 무경고 + 기존 테스트 297개 green (배치마다 검증).
- **셀프 코드리뷰**: 구현 직후 8개 관점(라인 스캔·제거된 동작·파일 간 추적·재사용·단순화·효율·수정 깊이·컨벤션)으로 리뷰를 돌려 **10건의 결함을 스스로 발견**했다. 대표 3건:
  - **접근성 사용자를 크래시시키는 접근성 코드**: reduced-motion 사용자가 월 선택을 탭하면 `ScrollController.animateTo(Duration.zero)`가 Flutter의 `assert(duration > 0)`에 걸려 크래시했다. "동작 줄이기"를 존중하려고 넣은 토큰이 정작 그 사용자를 크래시시키는 아이러니 — `jumpTo` 분기로 수정.
  - **상태 불일치**: pull-to-refresh가 화면에서 선택한 과거 월/주를 무시하고 항상 오늘 데이터로 카드를 덮어썼다. ViewModel의 `pullToRefresh()`에 `targetDate`를 넘기도록 수정.
  - **GlobalKey 함정의 재발**: 3.3에서 펫 전환 때 피했던 GlobalKey 중복 크래시가, 로딩→콘텐츠 크로스페이드용으로 새로 넣은 `AnimatedSwitcher`에서 다시 나타났다(전환 중 두 콘텐츠 서브트리 공존). 같은 실패 모드를 두 번째로 확인하고 크로스페이드를 제거했다 — "화려함보다 안전"의 재확인.

**10건 전부 수정 후 재검증했다**(analyze 무경고, 테스트 297건 green).

**교훈**: 관찰 가능한 동작(297 테스트)은 지켰지만 **애니메이션·접근성·상태 일관성 경로는 기존 테스트가 전혀 커버하지 못했다**. 리뷰 관점을 다양화해 "작성자 ≠ 리뷰어"를 도구화한 것이 실질 안전망이었다. 절반은 병렬로 진행한 작업의 통합 이음새(이중 햅틱 등)에서 나왔다는 점도 기록해 둘 만하다.

---

## 6. 회고

스코프 절충 2건:

1. **Skeleton 로딩**: 크로스페이드로 대체했다. Skeleton 레이아웃을 유지하는 이중 코드 비용이 극적 reveal 효과보다 크다고 판단했다.
2. **가입 폼 shake**: 테두리 danger 색상 전환 + 햅틱으로 축소했다. shake를 넣으려면 기존 폼 구조를 크게 손대야 해서, 검증·제출 플로우의 안정성을 화려함보다 우선했다.

**남은 일**:
- 실기기 모션 QA (시뮬레이터로는 햅틱·120Hz 리프레시 검증 불가).
- 복붙된 fade+scale 빌더 4곳·로딩 크로스페이드 4곳·reduced-motion repeat 분기 3곳을 공용 헬퍼/믹스인으로 추출 (리뷰의 재사용 앵글이 지적한 클린업).
- pull-to-refresh가 BHI만 갱신 → 건강요약·인사이트까지 확장.
