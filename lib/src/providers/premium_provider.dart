import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/premium/premium_service.dart';

/// 프리미엄 상태 SSOT
final premiumStatusProvider =
    AsyncNotifierProvider<PremiumStatusNotifier, PremiumStatus>(
  PremiumStatusNotifier.new,
);

class PremiumStatusNotifier extends AsyncNotifier<PremiumStatus> {
  @override
  Future<PremiumStatus> build() async {
    return await PremiumService.instance.getTier();
  }

  Future<void> refresh() async {
    state = const AsyncLoading<PremiumStatus>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      return await PremiumService.instance.getTier(forceRefresh: true);
    });
  }

  Future<PremiumStatus> refreshAndGet() async {
    await refresh();
    return state.requireValue;
  }

  Future<PremiumActivationResult> activateCode(String code) async {
    final result = await PremiumService.instance.activateCode(code);
    if (result.success) await refresh();
    return result;
  }
}
