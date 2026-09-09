// F17 회귀 테스트 — 사료 기록 카드의 식사 시간 라벨(오전/오후)이 l10n을 따른다.
// 이전에는 모델/화면에 '오전'/'오후'가 하드코딩되어 en/zh 사용자도 한국어를 봤다.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/models/diet_entry.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/food_repository.dart';
import 'package:perch_care/src/screens/food/food_record_screen.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

import '../support/record_screen_harness.dart';

class MockFoodRepository extends Mock implements FoodRepository {}

const _entries = [
  DietEntry(
    foodName: 'Seed mix',
    type: DietType.serving,
    grams: 10,
    recordedHour: 8,
    recordedMinute: 5,
  ),
  DietEntry(
    foodName: 'Pellets',
    type: DietType.serving,
    grams: 12,
    recordedHour: 14,
    recordedMinute: 30,
  ),
];

Widget _appWithLocale({
  required ProviderContainer container,
  required Locale locale,
}) =>
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
        home: const FoodRecordScreen(),
      ),
    );

void main() {
  late MockFoodRepository repo;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    SharedPreferences.setMockInitialValues(coachMarksSeen());
    repo = MockFoodRepository();
    when(
      () => repo.loadEntriesByDate(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
      ),
    ).thenAnswer((_) async => _entries);
  });

  Future<void> pump(WidgetTester tester, Locale locale) async {
    final c = ProviderContainer(overrides: [
      foodRepositoryProvider.overrideWithValue(repo),
      activePetViewModelProvider
          .overrideWith(() => ControllableActivePet(initial: testPet('a'))),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_appWithLocale(container: c, locale: locale));
    await pumpFrames(tester);
  }

  testWidgets('en 로케일에서 식사 시간이 AM/PM 으로 표시된다', (tester) async {
    await pump(tester, const Locale('en'));

    expect(find.text('AM 8:05'), findsOneWidget);
    expect(find.text('PM 2:30'), findsOneWidget);
    expect(find.textContaining('오전'), findsNothing);
    expect(find.textContaining('오후'), findsNothing);
  });

  testWidgets('ko 로케일에서는 기존처럼 오전/오후로 표시된다', (tester) async {
    await pump(tester, const Locale('ko'));

    expect(find.text('오전 8:05'), findsOneWidget);
    expect(find.text('오후 2:30'), findsOneWidget);
  });
}
