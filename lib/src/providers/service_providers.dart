import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/food/food_record_service.dart';
import '../services/water/water_record_service.dart';
import '../services/daily_record/daily_record_service.dart';
import '../services/schedule/schedule_service.dart';
import '../services/notification/notification_service.dart';
import '../services/weight/weight_service.dart';
import '../services/breed/breed_service.dart';
import '../services/sync/sync_service.dart';
import '../services/auth/auth_service.dart';

/// Stateless 서비스 DI 래퍼 — 테스트에서 ProviderScope(overrides: [...])로 모킹 가능

final foodRecordServiceProvider = Provider<FoodRecordService>((ref) => FoodRecordService.instance);
final waterRecordServiceProvider = Provider<WaterRecordService>((ref) => WaterRecordService.instance);
final dailyRecordServiceProvider = Provider<DailyRecordService>((ref) => DailyRecordService.instance);
final scheduleServiceProvider = Provider<ScheduleService>((ref) => ScheduleService.instance);
final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService.instance);
final weightServiceProvider = Provider<WeightService>((ref) => WeightService.instance);
final breedServiceProvider = Provider<BreedService>((ref) => BreedService.instance);
final syncServiceProvider = Provider<SyncService>((ref) => SyncService.instance);
final authServiceProvider = Provider<AuthService>((ref) => AuthService.instance);
