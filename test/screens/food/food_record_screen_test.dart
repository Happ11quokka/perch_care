// F04 회귀 테스트 — FoodRecordScreen 활성 펫 구독: 늦은 확정 / 펫 전환 / 펫 없음 저장.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/src/models/diet_entry.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/food_repository.dart';
import 'package:perch_care/src/repositories/save_outcome.dart';
import 'package:perch_care/src/screens/food/food_record_screen.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

import '../support/record_screen_harness.dart';

class MockFoodRepository extends Mock implements FoodRepository {}

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
    ).thenAnswer((_) async => <DietEntry>[]);
    when(
      () => repo.saveEntries(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
        entries: any(named: 'entries'),
        totalEaten: any(named: 'totalEaten'),
        totalServed: any(named: 'totalServed'),
      ),
    ).thenAnswer((_) async => SaveOutcome.online);
  });

  ProviderContainer container(ControllableActivePet Function() active) {
    final c = ProviderContainer(overrides: [
      foodRepositoryProvider.overrideWithValue(repo),
      activePetViewModelProvider.overrideWith(active),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  ControllableActivePet notifierOf(ProviderContainer c) =>
      c.read(activePetViewModelProvider.notifier) as ControllableActivePet;

  Future<void> pumpScreen(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      recordTestApp(container: c, home: const FoodRecordScreen()),
    );
    await pumpFrames(tester);
  }

  testWidgets('펫 provider 가 마운트 이후 확정되면 그 펫으로 1회 로드한다', (tester) async {
    final pending = Completer<Pet?>();
    final c = container(() => ControllableActivePet(pending: pending.future));
    await pumpScreen(tester, c);

    verifyNever(
      () => repo.loadEntriesByDate(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(testPet('a'));
    await pumpFrames(tester);

    verify(() => repo.loadEntriesByDate(petId: 'a', date: any(named: 'date')))
        .called(1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('펫 전환 시 새 펫 id 로 재로드한다', (tester) async {
    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);
    verify(() => repo.loadEntriesByDate(petId: 'a', date: any(named: 'date')))
        .called(1);

    notifierOf(c).setPet(testPet('b'));
    await pumpFrames(tester);

    verify(() => repo.loadEntriesByDate(petId: 'b', date: any(named: 'date')))
        .called(1);
    verifyNever(
      () => repo.loadEntriesByDate(petId: 'a', date: any(named: 'date')),
    );
  });

  testWidgets('이전 펫의 늦게 도착한 로드 결과는 폐기한다', (tester) async {
    final stale = Completer<List<DietEntry>>();
    when(() => repo.loadEntriesByDate(petId: 'a', date: any(named: 'date')))
        .thenAnswer((_) => stale.future);
    when(() => repo.loadEntriesByDate(petId: 'b', date: any(named: 'date')))
        .thenAnswer((_) async => [
              DietEntry(foodName: 'B-seed', type: DietType.serving, grams: 12),
            ]);

    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);

    notifierOf(c).setPet(testPet('b'));
    await pumpFrames(tester);
    expect(find.text('B-seed'), findsOneWidget);

    stale.complete([
      DietEntry(foodName: 'A-stale', type: DietType.serving, grams: 99),
    ]);
    await pumpFrames(tester);

    expect(find.text('B-seed'), findsOneWidget);
    expect(find.text('A-stale'), findsNothing);
  });

  testWidgets('활성 펫 없이 저장하면 성공 스낵바 대신 경고를 띄우고 저장하지 않는다', (tester) async {
    final c = container(() => ControllableActivePet(initial: null));
    await pumpScreen(tester, c);

    final save = find.text('저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await pumpFrames(tester);

    expect(find.text('활성 펫을 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text('저장되었습니다.'), findsNothing);
    verifyNever(
      () => repo.saveEntries(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
        entries: any(named: 'entries'),
        totalEaten: any(named: 'totalEaten'),
        totalServed: any(named: 'totalServed'),
      ),
    );
    await drainSnackBars(tester);
  });
}
