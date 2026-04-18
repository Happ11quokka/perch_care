import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/food_repository.dart';
import '../repositories/home_repository.dart';
import '../repositories/pet_repository.dart';
import '../repositories/water_repository.dart';
import '../repositories/weight_repository.dart';

/// Repository 레이어 DI — ViewModel은 이 provider만 `ref.read()` 하여 데이터 접근.
///
/// 테스트에서는 `ProviderScope(overrides: [petRepositoryProvider.overrideWithValue(FakePetRepository())])`
/// 로 Repository를 교체하여 ViewModel을 단위 테스트할 수 있다.

final petRepositoryProvider = Provider<PetRepository>(
  (ref) => PetRepositoryImpl(),
);

final homeRepositoryProvider = Provider<HomeRepository>(
  (ref) => HomeRepositoryImpl(),
);

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => WeightRepositoryImpl(),
);

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => FoodRepositoryImpl(),
);

final waterRepositoryProvider = Provider<WaterRepository>(
  (ref) => WaterRepositoryImpl(),
);
