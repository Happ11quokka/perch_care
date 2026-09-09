import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/pet_providers.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/auth_repository.dart';
import '../notification/notification_view_model.dart';

/// 인증 액션(로그인/로그아웃) ViewModel — 로그인 화면들이 공유한다.
///
/// - View: `LoginScreen` / 소셜 로그인 진입점 (Task 4)
/// - 상태: `AsyncValue<void>` — 진행 중/완료/에러만 표현. 로그인 결과(라우팅 정보)는
///   각 메서드가 반환하는 `LoginOutcome`(또는 취소 시 `null`)으로 전달한다.
/// - 규약: `WeightAddViewModel`과 동일한 명령형 패턴 —
///   `state = AsyncLoading()` → try 성공 시 `AsyncData(null)` / 실패 시 `AsyncError`+rethrow.
///   단, 소셜 로그인 취소(`null` 반환)는 실패가 아니라 정상 흐름이므로 `AsyncData(null)`로 마무리한다.
/// - 세션 경계: 로그인 성공(`LoginAuthenticated`)과 로그아웃 모두
///   [_invalidateSessionProviders]를 거쳐 사용자 종속 provider를 무효화한다.
///   로그인 전에 생성된 provider(스플래시/로그인 화면에서 먼저 read된 활성 펫 등)가
///   비로그인 상태의 값(null/빈 목록)을 계속 들고 있는 것을 막는다.
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
      _onLoginOutcome(outcome);
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
      _onLoginOutcome(outcome);
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
      _onLoginOutcome(outcome);
      state = const AsyncData(null);
      return outcome;
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }

  /// 로그아웃 — 세션 정리 후 사용자 종속 ViewModel 상태를 무효화하여 다음 watch 시 재조회되게 한다.
  /// (BHI provider는 Stage 3에서 제거되어 invalidate 대상이 아니다.)
  Future<void> logout() async {
    state = const AsyncLoading<void>();
    try {
      await _repo.signOut();
      _invalidateSessionProviders();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError<void>(e, st);
      rethrow;
    }
  }

  /// 로그인 결과가 '인증 성공'일 때만 세션 provider를 갱신한다.
  ///
  /// - `LoginAuthenticated`: 토큰이 저장된 새 세션 → 이전 세션(또는 비로그인) 값을 버린다.
  /// - `LoginSignupRequired` / `null`(취소): 세션이 바뀌지 않았으므로 아무것도 하지 않는다.
  ///
  /// 결과가 확정된 뒤·호출자에게 반환하기 전에 호출해야, 호출자가 라우팅 직후
  /// watch하는 provider가 새 세션 기준으로 로드된다.
  void _onLoginOutcome(LoginOutcome? outcome) {
    if (outcome is LoginAuthenticated) _refreshSessionProviders();
  }

  /// 로그인 성공 — 사용자 종속 provider를 새 세션 기준으로 다시 로드한다.
  ///
  /// 활성 펫/펫 목록은 `invalidate`만 하지 않고 **즉시 재빌드를 시작**한다
  /// ([_refreshNow]). 이유:
  /// - `ref.invalidate`만으로는 재빌드가 다음 이벤트 루프(스케줄러)로 미뤄지고, 그마저도
  ///   listener가 있을 때만 수행된다. 로그인 화면은 펫 provider를 watch하지 않으므로
  ///   스플래시/로그인 단계에서 먼저 read되어 `null`로 굳은 활성 펫이 라우팅 직후까지
  ///   그대로 남는다 (F03).
  /// - 토큰은 이미 저장된 상태라 즉시 조회해도 안전하고, 홈이 곧바로 watch하므로 낭비도 없다.
  ///
  /// 알림 목록은 폴링 스트림을 여는 provider라 알림 화면이 watch할 때까지 lazy로 둔다.
  ///
  /// 홈/체중 상세/건강체크 히스토리 등 파생 ViewModel은 `activePetViewModelProvider`를
  /// select-watch 하므로 활성 펫 키(id 등)가 바뀌면 자동으로 재빌드된다 — 여기서 중복
  /// 무효화하면 활성 펫 로딩 중 1회 더 빌드되어 불필요한 조회가 생기므로 제외한다.
  ///
  /// `authViewModelProvider` 자신은 무효화하지 않는다 (진행 중인 호출의 state 전이가 끊긴다).
  void _refreshSessionProviders() {
    _refreshNow(activePetViewModelProvider);
    _refreshNow(petListViewModelProvider);
    ref.invalidate(notificationViewModelProvider);
  }

  /// 로그아웃 — 사용자 종속 provider를 **lazy**로 무효화한다.
  ///
  /// 로그인과 달리 즉시 재빌드하지 않는다: 토큰이 지워진 직후 활성 펫/펫 목록을 조회하면
  /// 인증 없는 요청이 나가 401 처리(세션 만료 안내 등)를 유발할 수 있다. 다음 로그인 성공 시
  /// [_refreshSessionProviders]가 다시 로드한다.
  void _invalidateSessionProviders() {
    ref.invalidate(activePetViewModelProvider);
    ref.invalidate(petListViewModelProvider);
    ref.invalidate(notificationViewModelProvider);
  }

  /// `ref.refresh`와 동일(invalidate + read)하되 반환값을 쓰지 않는다 — 재빌드를
  /// 스케줄러에 맡기지 않고 지금 바로 시작시키는 것이 목적이다.
  void _refreshNow<T>(ProviderBase<T> provider) {
    ref.invalidate(provider);
    ref.read(provider);
  }
}

final authViewModelProvider =
    AsyncNotifierProvider<AuthViewModel, void>(AuthViewModel.new);
