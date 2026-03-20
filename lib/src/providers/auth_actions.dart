import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth/auth_service.dart';
import 'pet_providers.dart';
import 'premium_provider.dart';
import 'bhi_provider.dart';

/// 로그아웃 시 Riverpod 상태 일괄 리셋
Future<void> performLogout(WidgetRef ref) async {
  await AuthService.instance.signOut();
  ref.invalidate(activePetProvider);
  ref.invalidate(petListProvider);
  ref.invalidate(premiumStatusProvider);
  ref.invalidate(bhiProvider);
}
