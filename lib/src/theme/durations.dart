import 'package:flutter/widgets.dart';

/// 앱의 애니메이션 타이밍 상수 정의
class AppDurations {
  AppDurations._();

  // UI Transitions
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);

  // Micro-interaction (탭 다운/업 피드백)
  static const Duration press = Duration(milliseconds: 100);
  static const Duration feedback = Duration(milliseconds: 150);

  // Snack Bar
  static const Duration snackBarEnter = Duration(milliseconds: 350);
  static const Duration snackBarExit = Duration(milliseconds: 250);
  static const Duration snackBarDisplay = Duration(seconds: 3);

  // Coach Mark
  static const Duration coachMarkDelay = Duration(milliseconds: 800);
  static const Duration coachMarkTransition = Duration(milliseconds: 300);

  // Chart & Data
  static const Duration chartAnimation = Duration(milliseconds: 240);

  // Page transition
  static const Duration pageFade = Duration(milliseconds: 450);
  static const Duration pageFadeExit = Duration(milliseconds: 300); // enter의 ~66%
  static const Duration branchCrossfade = Duration(milliseconds: 200);

  // Data viz (게이지/링 채움, 카운트업)
  static const Duration dataReveal = Duration(milliseconds: 600);
  static const Duration gauge = Duration(milliseconds: 500);

  // Feature Animations
  static const Duration splash = Duration(milliseconds: 2000);
  static const Duration analyzing = Duration(milliseconds: 1200);

  /// OS의 '동작 줄이기(Reduce Motion)' 설정을 존중해 duration을 반환한다.
  /// disableAnimations가 켜져 있으면 [Duration.zero]를 돌려 즉시 완료시킨다.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? Duration.zero
        : duration;
  }
}

/// 앱 전역 이징 커브 계약.
/// - [enter]: 진입/등장 (자연스러운 감속)
/// - [exit]: 이탈/소멸 (exit는 enter보다 빠르게)
/// - [emphasize]: 왕복/강조 (양방향 가속·감속)
class AppCurves {
  AppCurves._();

  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
  static const Curve emphasize = Curves.easeInOutCubic;
}
