// F04 회귀 테스트 — WaterRecordScreen 은 활성 펫을 initState 에서 1회 read 하지 않고
// provider 를 구독해야 한다: 늦은 확정 / 펫 전환 / 이전 펫 결과 폐기 / 펫 없음 저장.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/save_outcome.dart';
import 'package:perch_care/src/repositories/water_repository.dart';
import 'package:perch_care/src/screens/water/water_record_screen.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

import '../support/record_screen_harness.dart';

class MockWaterRepository extends Mock implements WaterRepository {}

typedef _Day = ({double totalMl, int count});

void main() {
  late MockWaterRepository repo;

  setUpAll(() => registerFallbackValue(DateTime(2026)));

  setUp(() {
    SharedPreferences.setMockInitialValues(coachMarksSeen());
    repo = MockWaterRepository();
    when(
      () => repo.loadByDate(petId: any(named: 'petId'), date: any(named: 'date')),
    ).thenAnswer((_) async => null);
    when(
      () => repo.save(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
        totalMl: any(named: 'totalMl'),
        targetMl: any(named: 'targetMl'),
        count: any(named: 'count'),
      ),
    ).thenAnswer((_) async => SaveOutcome.online);
  });

  ProviderContainer container(ControllableActivePet Function() active) {
    final c = ProviderContainer(overrides: [
      waterRepositoryProvider.overrideWithValue(repo),
      activePetViewModelProvider.overrideWith(active),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  ControllableActivePet notifierOf(ProviderContainer c) =>
      c.read(activePetViewModelProvider.notifier) as ControllableActivePet;

  Future<void> pumpScreen(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      recordTestApp(container: c, home: const WaterRecordScreen()),
    );
    await pumpFrames(tester);
  }

  Future<void> tapSave(WidgetTester tester) async {
    final save = find.text('저장');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await pumpFrames(tester);
  }

  testWidgets('펫 provider 가 마운트 이후 확정되면 그 펫으로 1회 로드한다', (tester) async {
    final pending = Completer<Pet?>();
    final c = container(() => ControllableActivePet(pending: pending.future));
    await pumpScreen(tester, c);

    verifyNever(
      () => repo.loadByDate(petId: any(named: 'petId'), date: any(named: 'date')),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget,
        reason: '펫 확정 전에는 로딩 상태');

    pending.complete(testPet('a'));
    await pumpFrames(tester);

    verify(() => repo.loadByDate(petId: 'a', date: any(named: 'date')))
        .called(1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('펫 전환 시 새 펫 id 로 재로드한다', (tester) async {
    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);
    verify(() => repo.loadByDate(petId: 'a', date: any(named: 'date')))
        .called(1);

    notifierOf(c).setPet(testPet('b'));
    await pumpFrames(tester);

    verify(() => repo.loadByDate(petId: 'b', date: any(named: 'date')))
        .called(1);
    verifyNever(() => repo.loadByDate(petId: 'a', date: any(named: 'date')));
  });

  testWidgets('이전 펫의 늦게 도착한 로드 결과는 폐기한다', (tester) async {
    final stale = Completer<_Day?>();
    when(() => repo.loadByDate(petId: 'a', date: any(named: 'date')))
        .thenAnswer((_) => stale.future);
    when(() => repo.loadByDate(petId: 'b', date: any(named: 'date')))
        .thenAnswer((_) async => (totalMl: 50.0, count: 2));

    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);

    notifierOf(c).setPet(testPet('b'));
    await pumpFrames(tester);
    expect(find.text('50ml'), findsOneWidget);

    stale.complete((totalMl: 999.0, count: 9));
    await pumpFrames(tester);

    expect(find.text('50ml'), findsOneWidget, reason: '펫 b 데이터 유지');
    expect(find.text('999ml'), findsNothing, reason: '펫 a 결과는 무시');
  });

  testWidgets('펫이 null 로 확정되면 로드 없이 로딩을 끝낸다', (tester) async {
    final pending = Completer<Pet?>();
    final c = container(() => ControllableActivePet(pending: pending.future));
    await pumpScreen(tester, c);

    pending.complete(null);
    await pumpFrames(tester);

    verifyNever(
      () => repo.loadByDate(petId: any(named: 'petId'), date: any(named: 'date')),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('활성 펫 없이 저장하면 성공 스낵바 대신 경고를 띄우고 저장하지 않는다', (tester) async {
    final c = container(() => ControllableActivePet(initial: null));
    await pumpScreen(tester, c);

    await tapSave(tester);

    expect(find.text('활성 펫을 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text('저장되었습니다.'), findsNothing);
    verifyNever(
      () => repo.save(
        petId: any(named: 'petId'),
        date: any(named: 'date'),
        totalMl: any(named: 'totalMl'),
        targetMl: any(named: 'targetMl'),
        count: any(named: 'count'),
      ),
    );
    await drainSnackBars(tester);
  });

  testWidgets('활성 펫이 있으면 그 펫 id 로 저장하고 성공 스낵바를 띄운다', (tester) async {
    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);

    await tapSave(tester);

    verify(
      () => repo.save(
        petId: 'a',
        date: any(named: 'date'),
        totalMl: any(named: 'totalMl'),
        targetMl: any(named: 'targetMl'),
        count: any(named: 'count'),
      ),
    ).called(1);
    expect(find.text('저장되었습니다.'), findsOneWidget);
    await drainSnackBars(tester);
  });
}
