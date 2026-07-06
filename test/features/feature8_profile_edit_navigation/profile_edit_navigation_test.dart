import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/router/route_names.dart';
import 'package:perch_care/src/screens/profile_setup/profile_setup_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// ProfileSetupScreen을 온보딩(true)/수정(false) 모드로 진입시키는 최소 라우터.
/// app_router의 profile/setup 라우트 파싱을 동일하게 미러링한다.
GoRouter _router({required bool isInitialSetup}) {
  return GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.pushNamed(
                RouteNames.profileSetup,
                extra: {'isInitialSetup': isInitialSetup},
              ),
              child: const Text('OPEN_SETUP'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/setup',
        name: RouteNames.profileSetup,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map<String, dynamic> ? extra : null;
          return ProfileSetupScreen(
            isInitialSetup: map?['isInitialSetup'] as bool? ?? true,
          );
        },
      ),
      GoRoute(
        path: '/petadd',
        name: RouteNames.petAdd,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('PET_ADD_MARKER'))),
      ),
    ],
  );
}

Widget _app(GoRouter router, AuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('ko'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
    ),
  );
}

void main() {
  late MockAuthRepository repo;

  setUpAll(() {
    registerFallbackValue('');
  });

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.getProfile())
        .thenAnswer((_) async => <String, dynamic>{'nickname': 'old'});
    when(() => repo.updateProfile(
          nickname: any(named: 'nickname'),
          avatarUrl: any(named: 'avatarUrl'),
        )).thenAnswer((_) async {});
  });

  group('프로필 수정 네비게이션 (기존 버그 회귀 방지)', () {
    testWidgets('수정 모드: 입력완료 → 닉네임 저장 후 프로필로 복귀(펫 등록으로 진행하지 않음)',
        (tester) async {
      await tester.pumpWidget(_app(_router(isInitialSetup: false), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN_SETUP'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileSetupScreen), findsOneWidget);

      await tester.tap(find.text('입력완료'));
      await tester.pumpAndSettle();

      // 저장은 호출되고
      verify(() => repo.updateProfile(
            nickname: any(named: 'nickname'),
            avatarUrl: any(named: 'avatarUrl'),
          )).called(1);
      // 프로필 설정 화면은 사라지며, 초기 설정용 펫 등록 화면으로 튕기지 않고 host로 복귀
      expect(find.byType(ProfileSetupScreen), findsNothing);
      expect(find.text('PET_ADD_MARKER'), findsNothing);
      expect(find.text('OPEN_SETUP'), findsOneWidget);
    });

    testWidgets('수정 모드: 나중에 하기 → 저장 없이 프로필로 복귀', (tester) async {
      await tester.pumpWidget(_app(_router(isInitialSetup: false), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN_SETUP'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('나중에 하기'));
      await tester.pumpAndSettle();

      // 취소이므로 저장 없음, 펫 등록으로도 가지 않고 복귀
      verifyNever(() => repo.updateProfile(
            nickname: any(named: 'nickname'),
            avatarUrl: any(named: 'avatarUrl'),
          ));
      expect(find.byType(ProfileSetupScreen), findsNothing);
      expect(find.text('PET_ADD_MARKER'), findsNothing);
      expect(find.text('OPEN_SETUP'), findsOneWidget);
    });

    testWidgets('초기 설정 모드: 입력완료 → 펫 등록 화면으로 진행 (기존 동작 유지)',
        (tester) async {
      await tester.pumpWidget(_app(_router(isInitialSetup: true), repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN_SETUP'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('입력완료'));
      await tester.pumpAndSettle();

      // 온보딩 플로우는 그대로 펫 등록 화면으로 진행해야 함
      expect(find.text('PET_ADD_MARKER'), findsOneWidget);
      expect(find.byType(ProfileSetupScreen), findsNothing);
    });
  });
}
