/// 앱의 애니메이션 타이밍 상수 정의
class AppDurations {
  AppDurations._();

  // UI Transitions
  static const Duration quick = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);

  // Snack Bar
  static const Duration snackBarEnter = Duration(milliseconds: 350);
  static const Duration snackBarExit = Duration(milliseconds: 250);
  static const Duration snackBarDisplay = Duration(seconds: 3);

  // Coach Mark
  static const Duration coachMarkDelay = Duration(milliseconds: 800);
  static const Duration coachMarkTransition = Duration(milliseconds: 300);

  // Chart & Data
  static const Duration chartAnimation = Duration(milliseconds: 240);

  // Feature Animations
  static const Duration splash = Duration(milliseconds: 2000);
  static const Duration analyzing = Duration(milliseconds: 1200);
}
