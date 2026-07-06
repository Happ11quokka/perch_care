import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/breed/breed_service.dart';
import '../services/storage/local_image_storage_service.dart';

/// Stateless 서비스 DI 래퍼 — 테스트에서 ProviderScope(overrides: [...])로 모킹 가능

final breedServiceProvider = Provider<BreedService>((ref) => BreedService.instance);
final localImageStorageServiceProvider =
    Provider<LocalImageStorageService>((ref) => LocalImageStorageService.instance);
