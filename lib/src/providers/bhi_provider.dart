import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bhi_result.dart';
import '../services/bhi/bhi_service.dart';
import 'pet_providers.dart';

/// BHI — activePet 변경 시 자동 재fetch (ref.watch 체인)
final bhiProvider = FutureProvider.autoDispose<BhiResult?>((ref) async {
  final pet = ref.watch(activePetProvider).valueOrNull;
  if (pet == null) return null;
  return await BhiService.instance.getBhi(pet.id);
});

/// 특정 날짜 BHI (HomeScreen 기간 선택용)
final bhiByDateProvider =
    FutureProvider.autoDispose.family<BhiResult?, DateTime>((ref, targetDate) async {
  final pet = ref.watch(activePetProvider).valueOrNull;
  if (pet == null) return null;
  return await BhiService.instance.getBhi(pet.id, targetDate: targetDate);
});
