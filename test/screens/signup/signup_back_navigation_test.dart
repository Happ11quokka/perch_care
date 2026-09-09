import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/router/route_paths.dart';
import 'package:perch_care/src/screens/signup/signup_screen.dart';

/// F15 회귀 테스트: 딥링크/재시작 등으로 `/signup`에 **직접 진입**한 뒤 뒤로가기를
/// 누르면 `GoError: There is nothing to pop`이 나던 문제.
/// 실제 `AppRouter`는 Firebase 등 네이티브 부트가 필요하므로, 동일한 경로 상수로
/// 최소 라우터를 구성해 SignupScreen의 back 핸들러만 검증한다.
Widget _app(GoRouter router) => ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );

GoRouter _router({required String initialLocation}) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.login,
          builder: (_, __) => const Scaffold(
            body: Text('login-placeholder'),
          ),
        ),
        GoRoute(
          path: RoutePaths.signup,
          builder: (_, __) => const SignupScreen(),
        ),
      ],
    );

void main() {
  testWidgets('direct entry to /signup: back arrow falls back to /login '
      'without throwing', (tester) async {
    final router = _router(initialLocation: RoutePaths.signup);
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(router.canPop(), isFalse, reason: '직접 진입이므로 스택에 pop할 페이지가 없다');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('login-placeholder'), findsOneWidget);
    expect(router.routerDelegate.currentConfiguration.uri.path, RoutePaths.login);
  });

  testWidgets('pushed from /login: back arrow pops back to the previous page',
      (tester) async {
    final router = _router(initialLocation: RoutePaths.login);
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    router.push(RoutePaths.signup);
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('login-placeholder'), findsOneWidget);
  });
}
