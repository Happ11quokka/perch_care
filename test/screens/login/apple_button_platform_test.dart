import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/screens/login/login_screen.dart';
import 'package:perch_care/src/utils/platform_support.dart';

/// Apple 로그인 버튼은 Apple 플랫폼에서만 노출해야 한다 — 감사 F10.
///
/// `sign_in_with_apple`은 Android에서 webAuthenticationOptions 없이 호출하면
/// 예외를 던지고, 호출부는 해당 설정을 전달하지 않는다. 버튼이 보이면 누르는
/// 즉시 실패한다.
Widget _app() {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
      home: const LoginScreen(),
    ),
  );
}

/// `debugDefaultTargetPlatformOverride`는 테스트 본문이 끝나기 전에 되돌려야
/// 한다(testWidgets가 본문 종료 직후 foundation 디버그 변수를 검사한다).
Future<void> withPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  test('canStartAppleSignIn은 Apple 플랫폼에서만 true다', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(canStartAppleSignIn, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(canStartAppleSignIn, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(canStartAppleSignIn, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS: 로그인 화면에 Apple 버튼이 있다', (tester) async {
    await withPlatform(TargetPlatform.iOS, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Apple로 로그인'), findsOneWidget);
      expect(find.text('Google로 로그인'), findsOneWidget);
    });
  });

  testWidgets('Android: Apple 버튼을 노출하지 않고 나머지는 유지한다', (tester) async {
    await withPlatform(TargetPlatform.android, () async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.text('Apple로 로그인'), findsNothing);
      expect(find.text('Google로 로그인'), findsOneWidget);
      expect(find.text('이메일로 로그인'), findsOneWidget);
    });
  });
}
