import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/screens/profile_setup/profile_setup_screen.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// 프로필 설정 화면은 저장 계약(`updateProfile`: nickname·avatarUrl)이 지원하는
/// 필드만 입력받아야 한다 — 감사 F07.
///
/// 이전에는 성별·국가코드·전화번호를 입력받았지만 저장하지 않아, 입력완료 후
/// 복귀하면 값이 조용히 사라졌다.
Widget _app(AuthRepository repo, {Locale locale = const Locale('ko')}) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
      home: const ProfileSetupScreen(isInitialSetup: false),
    ),
  );
}

/// `_handleComplete`는 저장 후 `context.pop()`하므로 되돌아갈 화면이 필요하다.
Widget _routedApp(AuthRepository repo) {
  final router = GoRouter(
    initialLocation: '/host',
    routes: [
      GoRoute(
        path: '/host',
        builder: (context, state) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => context.push('/setup'),
              child: const Text('OPEN_SETUP'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) =>
            const ProfileSetupScreen(isInitialSetup: false),
      ),
    ],
  );
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

  setUp(() {
    repo = MockAuthRepository();
    when(() => repo.updateProfile(
          nickname: any(named: 'nickname'),
          avatarUrl: any(named: 'avatarUrl'),
        )).thenAnswer((_) async {});
  });

  testWidgets('저장되지 않는 성별·전화번호 입력을 노출하지 않는다', (tester) async {
    when(() => repo.getProfile()).thenAnswer(
      (_) async => <String, dynamic>{
        'nickname': '동현',
        'email': 'owner@perch.test',
      },
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('성별을 선택하세요'), findsNothing);
    expect(find.text('전화번호를 입력해 주세요'), findsNothing);
    expect(find.text('국가를 선택하세요'), findsNothing);
    // 닉네임은 유일한 편집 가능 필드다.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('동현'), findsOneWidget);
  });

  testWidgets('계정 이메일은 읽기 전용으로 표시된다', (tester) async {
    when(() => repo.getProfile()).thenAnswer(
      (_) async => <String, dynamic>{
        'nickname': '동현',
        'email': 'owner@perch.test',
      },
    );

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('owner@perch.test'), findsOneWidget);
    // TextField는 닉네임 하나뿐이므로 이메일은 편집할 수 없다.
    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields.length, 1);
    expect(fields.single.controller?.text, '동현');
  });

  testWidgets('이메일 없는 계정(소셜 로그인)은 안내 문구를 보여준다', (tester) async {
    when(() => repo.getProfile())
        .thenAnswer((_) async => <String, dynamic>{'nickname': '동현'});

    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('등록된 이메일이 없습니다'), findsOneWidget);
  });

  testWidgets('입력완료는 닉네임만 전송한다', (tester) async {
    when(() => repo.getProfile()).thenAnswer(
      (_) async => <String, dynamic>{
        'nickname': '동현',
        'email': 'owner@perch.test',
      },
    );

    await tester.pumpWidget(_routedApp(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OPEN_SETUP'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '새이름');
    await tester.tap(find.text('입력완료'));
    await tester.pumpAndSettle();

    verify(() => repo.updateProfile(nickname: '새이름')).called(1);
    // 저장 후 이전 화면으로 복귀한다.
    expect(find.byType(ProfileSetupScreen), findsNothing);
  });
}
