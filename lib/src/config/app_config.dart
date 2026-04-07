/// App-wide compile-time configuration.
class AppConfig {
  AppConfig._();

  static const String authRedirectUri = 'perchcare://auth-callback';

  /// false로 설정하면 프리미엄 게이팅 비활성화 (App Store 리뷰용).
  /// IAP 준비 완료 시 true로 변경.
  static const bool premiumEnabled = false;
}
