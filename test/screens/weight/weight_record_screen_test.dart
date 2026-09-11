// F04 회귀 테스트 — WeightRecordScreen 활성 펫 구독: 늦은 확정 / 펫 전환 / 에러 시 캐시 폴백 / 펫 없음 저장.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/models/weight_record.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/repositories/weight_repository.dart';
import 'package:perch_care/src/screens/weight/weight_record_screen.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

import '../support/record_screen_harness.dart';

class MockWeightRepository extends Mock implements WeightRepository {}

class MockPetRepository extends Mock implements PetRepository {}

class _WeightRecordFake extends Fake implements WeightRecord {}

void main() {
  late MockWeightRepository weight;
  late MockPetRepository pets;

  setUpAll(() => registerFallbackValue(_WeightRecordFake()));

  setUp(() {
    SharedPreferences.setMockInitialValues(coachMarksSeen());
    weight = MockWeightRepository();
    pets = MockPetRepository();
    when(() => weight.fetchLocal(petId: any(named: 'petId')))
        .thenAnswer((_) async => <WeightRecord>[]);
    when(() => weight.saveRecord(any()))
        .thenAnswer((invocation) async =>
            invocation.positionalArguments.first as WeightRecord);
    when(() => pets.getActivePetFromLocalCache()).thenAnswer((_) async => null);
  });

  ProviderContainer container(ControllableActivePet Function() active) {
    final c = ProviderContainer(overrides: [
      weightRepositoryProvider.overrideWithValue(weight),
      petRepositoryProvider.overrideWithValue(pets),
      activePetViewModelProvider.overrideWith(active),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  ControllableActivePet notifierOf(ProviderContainer c) =>
      c.read(activePetViewModelProvider.notifier) as ControllableActivePet;

  Future<void> pumpScreen(WidgetTester tester, ProviderContainer c) async {
    await tester.pumpWidget(
      recordTestApp(container: c, home: const WeightRecordScreen()),
    );
    await pumpFrames(tester);
  }

  testWidgets('펫 provider 가 마운트 이후 확정되면 그 펫으로 1회 로드한다', (tester) async {
    final pending = Completer<Pet?>();
    final c = container(() => ControllableActivePet(pending: pending.future));
    await pumpScreen(tester, c);

    verifyNever(() => weight.fetchLocal(petId: any(named: 'petId')));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    pending.complete(testPet('a'));
    await pumpFrames(tester);

    verify(() => weight.fetchLocal(petId: 'a')).called(1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('펫 전환 시 새 펫 id 로 재로드한다', (tester) async {
    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);
    verify(() => weight.fetchLocal(petId: 'a')).called(1);

    notifierOf(c).setPet(testPet('b'));
    await pumpFrames(tester);

    verify(() => weight.fetchLocal(petId: 'b')).called(1);
    verifyNever(() => weight.fetchLocal(petId: 'a'));
  });

  testWidgets('펫 provider 에러(값 없음) 시 로컬 캐시 펫으로 폴백한다', (tester) async {
    when(() => pets.getActivePetFromLocalCache())
        .thenAnswer((_) async => testPet('cached'));
    final failing = Completer<Pet?>();
    final c = container(() => ControllableActivePet(pending: failing.future));
    await pumpScreen(tester, c);

    failing.completeError(Exception('offline'));
    await pumpFrames(tester);

    verify(() => weight.fetchLocal(petId: 'cached')).called(1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
    verifyNever(() => weight.saveRecord(any()));
    await drainSnackBars(tester);
  });
}
