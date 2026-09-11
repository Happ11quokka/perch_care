import 'package:flutter/foundation.dart';

/// 플랫폼별로 사용할 수 있는 기능 판별.
///
/// `Platform.isIOS`(dart:io) 대신 `defaultTargetPlatform`을 쓴다. 웹에서도
/// 동작하고, 위젯 테스트에서 `debugDefaultTargetPlatformOverride`로 두 경로를
/// 모두 검사할 수 있다.

/// Apple 로그인으로 **인증을 시작**할 수 있는 플랫폼인지.
///
/// `sign_in_with_apple`은 Apple 플랫폼이 아니면 `webAuthenticationOptions`
/// (Apple Service ID + 서버 redirect URI) 없이 `getAppleIDCredential()`을
/// 호출할 때 예외를 던진다. 앱은 해당 설정을 전달하지 않으므로 Android에서
/// 버튼을 노출하면 누르는 즉시 실패한다. App Store 심사 기준에서도 Apple
/// 로그인은 Apple 플랫폼에서만 필수다.
///
/// 이미 연동된 Apple 계정의 **연동 해제**는 서버 호출이므로 이 값과 무관하게
/// 어느 플랫폼에서나 가능하다.
bool get canStartAppleSignIn =>
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS;
