// F04 회귀 테스트 — WeightAddScreen 은 활성 펫을 initState 에서 1회 read 하지 않고
// 저장 시점의 provider 값을 사용해야 한다.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/models/weight_record.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/weight_repository.dart';
import 'package:perch_care/src/screens/weight/weight_add_screen.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';

import '../support/record_screen_harness.dart';

class MockWeightRepository extends Mock implements WeightRepository {}

class _WeightRecordFake extends Fake implements WeightRecord {}

void main() {
  late MockWeightRepository weight;

  setUpAll(() => registerFallbackValue(_WeightRecordFake()));

  setUp(() {
    weight = MockWeightRepository();
    when(() => weight.saveRecord(any())).thenAnswer((invocation) async =>
        invocation.positionalArguments.first as WeightRecord);
  });

  ProviderContainer container(ControllableActivePet Function() active) {
    final c = ProviderContainer(overrides: [
      weightRepositoryProvider.overrideWithValue(weight),
      activePetViewModelProvider.overrideWith(active),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  ControllableActivePet notifierOf(ProviderContainer c) =>
      c.read(activePetViewModelProvider.notifier) as ControllableActivePet;

  /// context.pop 이 동작하도록 '/' 아래 중첩 라우트로 진입한다.
  Future<void> pumpScreen(WidgetTester tester, ProviderContainer c) async {
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('home-placeholder')),
          routes: [
            GoRoute(
              path: 'add',
              builder: (_, __) => WeightAddScreen(date: DateTime(2026, 9, 9)),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      recordTestRouterApp(container: c, routerConfig: router),
    );
    await pumpFrames(tester);
  }

  Future<void> enterWeightAndSave(WidgetTester tester) async {
    final field = find.byType(TextFormField);
    await tester.ensureVisible(field);
    await tester.enterText(field, '70');
    await tester.pump();
    final save = find.text('저장하기');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await pumpFrames(tester);
  }

  testWidgets('저장 시점의 활성 펫 id 로 기록한다', (tester) async {
    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);

    await enterWeightAndSave(tester);

    final saved = verify(() => weight.saveRecord(captureAny())).captured.single
        as WeightRecord;
    expect(saved.petId, 'a');
    expect(saved.weight, 70);
    await drainSnackBars(tester);
  });

  testWidgets('마운트 이후 펫이 전환되면 새 펫 id 로 기록한다', (tester) async {
    final c = container(() => ControllableActivePet(initial: testPet('a')));
    await pumpScreen(tester, c);

    notifierOf(c).setPet(testPet('b'));
    await pumpFrames(tester);
    await enterWeightAndSave(tester);

    final saved = verify(() => weight.saveRecord(captureAny())).captured.single
        as WeightRecord;
    expect(saved.petId, 'b');
    await drainSnackBars(tester);
  });

  testWidgets('마운트 이후 늦게 확정된 펫으로 기록한다', (tester) async {
    final pending = Completer<Pet?>();
    final c = container(() => ControllableActivePet(pending: pending.future));
    await pumpScreen(tester, c);

    pending.complete(testPet('late'));
    await pumpFrames(tester);
    await enterWeightAndSave(tester);

    final saved = verify(() => weight.saveRecord(captureAny())).captured.single
        as WeightRecord;
    expect(saved.petId, 'late');
    await drainSnackBars(tester);
  });

  testWidgets('활성 펫 없이 저장하면 경고만 띄우고 기록하지 않는다', (tester) async {
    final c = container(() => ControllableActivePet(initial: null));
    await pumpScreen(tester, c);

    await enterWeightAndSave(tester);

    expect(find.text('활성 펫을 찾을 수 없습니다.'), findsOneWidget);
    expect(find.text('오늘의 체중이 기록되었습니다!'), findsNothing);
    verifyNever(() => weight.saveRecord(any()));
    expect(find.text('home-placeholder'), findsNothing, reason: 'pop 되지 않음');
    await drainSnackBars(tester);
  });

  testWidgets('활성 펫 로딩 중에는 저장 버튼이 동작하지 않는다', (tester) async {
    final pending = Completer<Pet?>();
    final c = container(() => ControllableActivePet(pending: pending.future));
    await pumpScreen(tester, c);

    await enterWeightAndSave(tester);

    verifyNever(() => weight.saveRecord(any()));
    expect(find.text('활성 펫을 찾을 수 없습니다.'), findsNothing);
    pending.complete(null);
    await pumpFrames(tester);
  });
}
