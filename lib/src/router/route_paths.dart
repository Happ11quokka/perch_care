/// 앱의 라우트 경로 상수
class RoutePaths {
  RoutePaths._();

  // 인증 관련 (Shell 바깥)
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String emailLogin = '/email-login';
  static const String forgotPasswordMethod = '/forgot-password/method';
  static const String forgotPasswordCode = '/forgot-password/code';
  static const String forgotPasswordReset = '/forgot-password/reset';
  static const String termsDetailPublic = '/terms/detail';

  // 탭 루트 경로
  static const String home = '/home';
  static const String weightDetail = '/weight-detail';
  static const String aiEncyclopedia = '/ai-encyclopedia';

  // 홈 탭 하위 경로 (full: /home/...)
  static const String notification = '/home/notification';
  static const String profile = '/home/profile';
  static const String petProfileDetail = '/home/pet/profile/detail';
  static const String petAdd = '/home/pet/add';
  static const String petProfile = '/home/pet/profile';
  static const String foodRecord = '/home/food/record';
  static const String waterRecord = '/home/water/record';
  static const String wciIndex = '/home/wci/index';
  static const String bhiDetail = '/home/bhi/detail';
  static const String profileSetup = '/home/profile/setup';
  static const String profileSetupComplete = '/home/profile/setup/complete';
  static const String termsDetail = '/home/terms/detail';
  static const String faq = '/home/faq';

  // 체중 탭 하위 경로 (full: /weight-detail/...)
  static const String weightRecord = '/weight-detail/record';
  static const String weightAddToday = '/weight-detail/add/today';
  static const String weightAdd = '/weight-detail/add/:date';

  // 추가 라우트 경로들을 여기에 정의
}
