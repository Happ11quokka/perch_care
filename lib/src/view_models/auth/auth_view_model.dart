import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pet_providers.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/auth_repository.dart';

/// 인증 액션(로그인/로그아웃) ViewModel — 로그인 화면들이 공유한다.
///
/// - View: `LoginScreen` / 소셜 로그인 진입점 (Task 4)
/// - 상태: `AsyncValue<void>` — 진행 중/완료/에러만 표현. 로그인 결과(라우팅 정보)는
///   각 메서드가 반환하는 `LoginOutcome`(또는 취소 시 `null`)으로 전달한다.
/// - 규약: `WeightAddViewModel`과 동일한 명령형 패턴 —
///   `state = AsyncLoading()` → try 성공 시 `AsyncData(null)` / 실패 시 `AsyncError`+rethrow.
///   단, 소셜 로그인 취소(`null` 반환)는 실패가 아니라 정상 흐름이므로 `AsyncData(null)`로 마무리한다.
class AuthViewModel extends AsyncNotifier<void> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<void> build() async {}

  /// 이메일/비밀번호 로그인. 성공/실패 여부와 무관하게 결과(또는 예외)를 그대로 호출자에게 전달한다.
  Future<LoginOutcome> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading<void>();
    try {
      final outcome = await _repo.signInWithEmail(
        email: email,
        password: password,
      );
      state = const AsyncData(null);
      return outcome;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }

  /// Google 로그인. 사용자가 취소하면 `null`을 반환한다 — 이는 에러가 아니라 정상 흐름이다.
  Future<LoginOutcome?> loginWithGoogle() async {
    state = const AsyncLoading<void>();
    try {
      final outcome = await _repo.loginWithGoogle();
      state = const AsyncData(null);
      return outcome;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }

  /// Apple 로그인. 사용자가 취소하면 `null`을 반환한다 — 이는 에러가 아니라 정상 흐름이다.
  Future<LoginOutcome?> loginWithApple() async {
    state = const AsyncLoading<void>();
    try {
      final outcome = await _repo.loginWithApple();
      state = const AsyncData(null);
      return outcome;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }

  /// 로그아웃 — 세션 정리 후 펫 관련 ViewModel 상태를 무효화하여 다음 watch 시 재조회되게 한다.
  /// (BHI provider는 Stage 3에서 제거되어 invalidate 대상이 아니다.)
  Future<void> logout() async {
    state = const AsyncLoading<void>();
    try {
      await _repo.signOut();
      ref.invalidate(activePetViewModelProvider);
      ref.invalidate(petListViewModelProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }
}

final authViewModelProvider =
    AsyncNotifierProvider<AuthViewModel, void>(AuthViewModel.new);
