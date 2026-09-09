// F17 회귀 테스트 — 펫 프로필 목록의 나이(년/개월/일)와 기본 닉네임이 l10n을 따른다.
// 이전에는 '$years년' 등이 하드코딩되어 en/zh 사용자도 한국어 단위를 봤다.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/screens/pet/pet_profile_screen.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

import '../support/record_screen_harness.dart';

class _FakePetRepository extends Fake implements PetRepository {
  _FakePetRepository(this.pets);
  final List<Pet> pets;

  @override
  Future<List<Pet>> getMyPets({bool forceRefresh = false}) async => pets;
}

class _FakeAuthRepository extends Fake implements AuthRepository {
  @override
  Future<Map<String, dynamic>?> getProfile() async => {'nickname': null};
}

Widget _app({required ProviderContainer container, required Locale locale}) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const PetProfileScreen(),
      ),
    );

void main() {
  // 오늘 기준 정확히 2년 전 — 같은 월/일이므로 개월/일 세그먼트는 0 → "2y" 만 표시.
  final now = DateTime.now();
  final twoYearsAgo = DateTime(now.year - 2, now.month, now.day);

  Future<void> pump(WidgetTester tester, Locale locale) async {
    final pet = testPet('a').copyWith(birthDate: twoYearsAgo);
    final c = ProviderContainer(overrides: [
      petRepositoryProvider.overrideWithValue(_FakePetRepository([pet])),
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      activePetViewModelProvider
          .overrideWith(() => ControllableActivePet(initial: pet)),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_app(container: c, locale: locale));
    await pumpFrames(tester);
  }

  testWidgets('en 로케일에서 펫 나이가 영어 단위로 표시된다', (tester) async {
    await pump(tester, const Locale('en'));

    expect(find.text('2y'), findsOneWidget);
    expect(find.textContaining('년'), findsNothing);
    // 닉네임 없음 → 기본 닉네임도 l10n(profile_user) 사용
    expect(find.text('User'), findsOneWidget);
    expect(find.text('사용자'), findsNothing);
  });

  testWidgets('ko 로케일에서는 기존처럼 한국어 단위로 표시된다', (tester) async {
    await pump(tester, const Locale('ko'));

    expect(find.text('2년'), findsOneWidget);
  });
}
