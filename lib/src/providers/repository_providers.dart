import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/daily_record_repository.dart';
import '../repositories/food_repository.dart';
import '../repositories/health_check_repository.dart';
import '../repositories/home_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/pet_repository.dart';
import '../repositories/report_share_repository.dart';
import '../repositories/schedule_repository.dart';
import '../repositories/water_repository.dart';
import '../repositories/weight_repository.dart';

/// Repository 레이어 DI — ViewModel은 이 provider만 `ref.read()` 하여 데이터 접근.
///
/// 테스트에서는 `ProviderScope(overrides: [petRepositoryProvider.overrideWithValue(FakePetRepository())])`
/// 로 Repository를 교체하여 ViewModel을 단위 테스트할 수 있다.

final petRepositoryProvider = Provider<PetRepository>(
  (ref) => PetRepositoryImpl(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(),
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

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepositoryImpl(),
);

final dailyRecordRepositoryProvider = Provider<DailyRecordRepository>(
  (ref) => DailyRecordRepositoryImpl(),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepositoryImpl(),
);

final reportShareRepositoryProvider = Provider<ReportShareRepository>(
  (ref) => ReportShareRepositoryImpl(),
);

final healthCheckRepositoryProvider = Provider<HealthCheckRepository>(
  (ref) => HealthCheckRepositoryImpl(),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(),
);
