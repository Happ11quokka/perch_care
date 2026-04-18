import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/weight_record.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/weight_repository.dart';
import 'package:perch_care/src/view_models/weight/weight_add_view_model.dart';

class MockWeightRepository extends Mock implements WeightRepository {}

class _WeightRecordFake extends Fake implements WeightRecord {}

WeightRecord _record({double weight = 72, int hour = 9, int minute = 0}) =>
    WeightRecord(
      petId: 'p1',
      date: DateTime(2026, 4, 18),
      weight: weight,
      recordedHour: hour,
      recordedMinute: minute,
    );

ProviderContainer _container(WeightRepository repo) {
  final container = ProviderContainer(overrides: [
    weightRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  late MockWeightRepository repo;

  setUpAll(() {
    registerFallbackValue(_WeightRecordFake());
  });

  setUp(() {
    repo = MockWeightRepository();
  });

  group('WeightAddViewModel', () {
    test('saveRecord()는 Repository.saveRecord를 호출하고 결과를 반환한다', () async {
      final saved = _record(weight: 70.5);
      when(() => repo.saveRecord(any())).thenAnswer((_) async => saved);

      final container = _container(repo);
      // 첫 build 완료 대기 (그렇지 않으면 saveRecord로 설정한 state가 build 완료 시 덮어쓰임)
      await container.read(weightAddViewModelProvider.future);
      final vm = container.read(weightAddViewModelProvider.notifier);

      final result = await vm.saveRecord(_record(weight: 70.5));

      expect(result.weight, 70.5);
      verify(() => repo.saveRecord(any())).called(1);
      expect(
        container.read(weightAddViewModelProvider).hasError,
        isFalse,
      );
    });

    test('Repository에서 예외가 나면 AsyncError + rethrow', () async {
      when(() => repo.saveRecord(any()))
          .thenThrow(Exception('local storage full'));

      final container = _container(repo);
      // 첫 build 완료 대기 (그렇지 않으면 saveRecord로 설정한 state가 build 완료 시 덮어쓰임)
      await container.read(weightAddViewModelProvider.future);
      final vm = container.read(weightAddViewModelProvider.notifier);

      await expectLater(
        vm.saveRecord(_record()),
        throwsA(isA<Exception>()),
      );
      final state = container.read(weightAddViewModelProvider);
      expect(state.hasError, isTrue);
    });
  });
}
