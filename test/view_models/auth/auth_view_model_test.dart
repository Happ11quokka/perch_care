import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/notification.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/repositories/notification_repository.dart';
import 'package:perch_care/src/repositories/pet_repository.dart';
import 'package:perch_care/src/view_models/auth/auth_view_model.dart';
import 'package:perch_care/src/view_models/notification/notification_view_model.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';
import 'package:perch_care/src/view_models/pet/pet_list_view_model.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPetRepository extends Mock implements PetRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

Pet _pet(String id) => Pet(
      id: id,
      userId: 'u-$id',
      name: 'bird-$id',
      species: 'bird',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

AppNotification _notif(String id) => AppNotification(
      id: id,
      userId: 'u1',
      type: NotificationType.system,
      title: 'title-$id',
      message: 'message-$id',
      timestamp: DateTime(2026, 1, 1),
    );

/// 로그인 전/후 세션 provider 재조회 검증용 fixture.
///
/// - `signedIn == false` : 비로그인 — 활성 펫 null / 펫 목록·알림 빈 리스트
/// - `signedIn == true`  : 로그인 후 — 활성 펫 [pet] / 펫 목록 [pet] / 알림 [n1]
///
/// 세션 provider를 로그인 **전에** 먼저 구독해 두고(listen), 로그인 성공 후
/// pump()만으로 새 세션 값이 자동 재조회되는지 검사한다 (F03 회귀 방지).
class _SessionFixture {
  _SessionFixture() {
    when(() => petRepo.getActivePet(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => signedIn ? pet : null);
    when(() => petRepo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
        .thenAnswer((_) async => signedIn ? [pet] : const <Pet>[]);
    when(() => notifRepo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => notifRepo.fetch()).thenAnswer(
      (_) async => signedIn ? [_notif('n1')] : const <AppNotification>[],
    );

    container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      petRepositoryProvider.overrideWithValue(petRepo),
      notificationRepositoryProvider.overrideWithValue(notifRepo),
    ]);
    addTearDown(container.dispose);
  }

  final authRepo = MockAuthRepository();
  final petRepo = MockPetRepository();
  final notifRepo = MockNotificationRepository();
  final pet = _pet('p1');
  bool signedIn = false;
  late final ProviderContainer container;

  /// 로그인 전 상태로 세션 provider를 미리 생성·구독해 둔다.
  Future<AuthViewModel> primeBeforeLogin() async {
    for (final sub in [
      container.listen(activePetViewModelProvider, (_, __) {}),
      container.listen(petListViewModelProvider, (_, __) {}),
      container.listen(notificationViewModelProvider, (_, __) {}),
    ]) {
      addTearDown(sub.close);
    }
    expect(await container.read(activePetViewModelProvider.future), isNull);
    expect(await container.read(petListViewModelProvider.future), isEmpty);
    expect(
        await container.read(notificationViewModelProvider.future), isEmpty);
    await container.read(authViewModelProvider.future);
    return container.read(authViewModelProvider.notifier);
  }

  /// 로그인 성공 직후 — 프로브(F03)와 동일하게 `pump()` 1회만으로 펫 provider가
  /// 새 세션 값을 들고 있어야 한다. 알림은 lazy 무효화라 이벤트 루프를 더 돌린다.
  Future<void> expectSessionReloaded() async {
    await container.pump();
    expect(container.read(activePetViewModelProvider).valueOrNull?.id, pet.id);
    expect(
      container.read(petListViewModelProvider).valueOrNull?.map((p) => p.id),
      [pet.id],
    );
    await settle();
    expect(
      container.read(notificationViewModelProvider).valueOrNull?.map((n) => n.id),
      ['n1'],
    );
  }

  /// 스케줄러 재빌드 + mock future 완료까지 이벤트 루프를 흘려보낸다.
  Future<void> settle() async {
    await container.pump();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> expectSessionUntouched() async {
    await settle();
    expect(container.read(activePetViewModelProvider).valueOrNull, isNull);
    expect(container.read(petListViewModelProvider).valueOrNull, isEmpty);
    expect(container.read(notificationViewModelProvider).valueOrNull, isEmpty);
    verify(() => petRepo.getActivePet(
        forceRefresh: any(named: 'forceRefresh'))).called(1);
    verify(() => petRepo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
        .called(1);
    verify(() => notifRepo.fetch()).called(1);
  }
}

ProviderContainer _container(AuthRepository repo) {
  final container = ProviderContainer(overrides: [
    authRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  late MockAuthRepository repo;

  setUp(() {
    repo = MockAuthRepository();
  });

  group('AuthViewModel.signInWithEmail', () {
    test('Repository에 위임하고 결과(LoginOutcome)를 그대로 반환한다', () async {
      final outcome = LoginAuthenticated(true);
      when(() => repo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => outcome);

      final container = _container(repo);
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);

      final result = await vm.signInWithEmail(
        email: 'a@b.com',
        password: 'pw1234',
      );

      expect(result, same(outcome));
      verify(() => repo.signInWithEmail(
            email: 'a@b.com',
            password: 'pw1234',
          )).called(1);
      expect(container.read(authViewModelProvider).hasError, isFalse);
    });

    test('Repository에서 예외가 나면 AsyncError + rethrow', () async {
      when(() => repo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('invalid credentials'));

      final container = _container(repo);
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);

      await expectLater(
        vm.signInWithEmail(email: 'a@b.com', password: 'wrong'),
        throwsA(isA<Exception>()),
      );

      final state = container.read(authViewModelProvider);
      expect(state.hasError, isTrue);
    });
  });

  group('AuthViewModel.loginWithGoogle', () {
    test('사용자가 취소하면 null을 반환하고 에러 상태로 만들지 않는다', () async {
      when(() => repo.loginWithGoogle()).thenAnswer((_) async => null);

      final container = _container(repo);
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);

      final result = await vm.loginWithGoogle();

      expect(result, isNull);
      final state = container.read(authViewModelProvider);
      expect(state.hasError, isFalse);
      expect(state.hasValue, isTrue);
    });

    test('성공하면 LoginOutcome을 그대로 반환한다', () async {
      final outcome = LoginAuthenticated(false);
      when(() => repo.loginWithGoogle()).thenAnswer((_) async => outcome);

      final container = _container(repo);
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);

      final result = await vm.loginWithGoogle();

      expect(result, same(outcome));
      expect(container.read(authViewModelProvider).hasError, isFalse);
    });

    test('Repository에서 예외가 나면 AsyncError + rethrow', () async {
      when(() => repo.loginWithGoogle())
          .thenThrow(Exception('network error'));

      final container = _container(repo);
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);

      await expectLater(
        vm.loginWithGoogle(),
        throwsA(isA<Exception>()),
      );

      final state = container.read(authViewModelProvider);
      expect(state.hasError, isTrue);
    });
  });

  group('AuthViewModel.loginWithApple', () {
    test('사용자가 취소하면 null을 반환하고 에러 상태로 만들지 않는다', () async {
      when(() => repo.loginWithApple()).thenAnswer((_) async => null);

      final container = _container(repo);
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);

      final result = await vm.loginWithApple();

      expect(result, isNull);
      expect(container.read(authViewModelProvider).hasError, isFalse);
    });
  });

  group('AuthViewModel.logout', () {
    test('Repository.signOut()을 호출한다', () async {
      when(() => repo.signOut()).thenAnswer((_) async {});

      final container = _container(repo);
      await container.read(authViewModelProvider.future);
      final vm = container.read(authViewModelProvider.notifier);

      await vm.logout();

      verify(() => repo.signOut()).called(1);
      expect(container.read(authViewModelProvider).hasError, isFalse);
    });
  });

  group('AuthViewModel 세션 provider 무효화 (F03)', () {
    test('이메일 로그인 성공 → 로그인 전에 생성된 활성 펫/펫 목록/알림이 재조회된다',
        () async {
      final f = _SessionFixture();
      when(() => f.authRepo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {
        f.signedIn = true;
        return LoginAuthenticated(true);
      });
      final vm = await f.primeBeforeLogin();

      final outcome =
          await vm.signInWithEmail(email: 'a@b.com', password: 'pw1234');

      expect(outcome, isA<LoginAuthenticated>());
      await f.expectSessionReloaded();
    });

    test('Google 로그인 성공 → 세션 provider가 재조회된다', () async {
      final f = _SessionFixture();
      when(() => f.authRepo.loginWithGoogle()).thenAnswer((_) async {
        f.signedIn = true;
        return LoginAuthenticated(true);
      });
      final vm = await f.primeBeforeLogin();

      await vm.loginWithGoogle();

      await f.expectSessionReloaded();
    });

    test('Apple 로그인 성공 → 세션 provider가 재조회된다', () async {
      final f = _SessionFixture();
      when(() => f.authRepo.loginWithApple()).thenAnswer((_) async {
        f.signedIn = true;
        return LoginAuthenticated(true);
      });
      final vm = await f.primeBeforeLogin();

      await vm.loginWithApple();

      await f.expectSessionReloaded();
    });

    test('계정 전환 — 로그아웃 후 다른 계정 로그인 시 이전 계정 펫이 남지 않는다',
        () async {
      final f = _SessionFixture();
      final other = _pet('p2');
      when(() => f.authRepo.signOut()).thenAnswer((_) async {});
      when(() => f.authRepo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {
        f.signedIn = true;
        return LoginAuthenticated(true);
      });
      final vm = await f.primeBeforeLogin();

      // 1st account
      await vm.signInWithEmail(email: 'a@b.com', password: 'pw');
      await f.expectSessionReloaded();

      // logout → getActivePet은 null, 2nd account는 other 펫
      f.signedIn = false;
      await vm.logout();
      await f.settle();
      expect(f.container.read(activePetViewModelProvider).valueOrNull, isNull);

      when(() => f.petRepo.getActivePet(
              forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => f.signedIn ? other : null);
      when(() => f.petRepo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
          .thenAnswer((_) async => f.signedIn ? [other] : const <Pet>[]);
      await vm.signInWithEmail(email: 'c@d.com', password: 'pw');
      await f.container.pump();

      expect(
          f.container.read(activePetViewModelProvider).valueOrNull?.id, 'p2');
      expect(
        f.container.read(petListViewModelProvider).valueOrNull?.map((p) => p.id),
        ['p2'],
      );
    });

    test('소셜 로그인 취소(null) → 세션 provider를 건드리지 않는다', () async {
      final f = _SessionFixture();
      when(() => f.authRepo.loginWithGoogle()).thenAnswer((_) async => null);
      final vm = await f.primeBeforeLogin();

      await vm.loginWithGoogle();

      await f.expectSessionUntouched();
    });

    test('LoginSignupRequired → 세션이 바뀌지 않았으므로 무효화하지 않는다', () async {
      final f = _SessionFixture();
      when(() => f.authRepo.loginWithApple()).thenAnswer(
        (_) async => LoginSignupRequired(provider: 'apple'),
      );
      final vm = await f.primeBeforeLogin();

      await vm.loginWithApple();

      await f.expectSessionUntouched();
    });

    test('로그인 실패(예외) → 세션 provider를 건드리지 않는다', () async {
      final f = _SessionFixture();
      when(() => f.authRepo.signInWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('invalid credentials'));
      final vm = await f.primeBeforeLogin();

      await expectLater(
        vm.signInWithEmail(email: 'a@b.com', password: 'wrong'),
        throwsA(isA<Exception>()),
      );

      await f.expectSessionUntouched();
    });

    test('logout → 활성 펫/펫 목록/알림이 모두 무효화된다', () async {
      final f = _SessionFixture();
      f.signedIn = true;
      when(() => f.authRepo.signOut()).thenAnswer((_) async {});
      final subs = [
        f.container.listen(activePetViewModelProvider, (_, __) {}),
        f.container.listen(petListViewModelProvider, (_, __) {}),
        f.container.listen(notificationViewModelProvider, (_, __) {}),
      ];
      for (final s in subs) {
        addTearDown(s.close);
      }
      expect(
          (await f.container.read(activePetViewModelProvider.future))?.id, 'p1');
      await f.container.read(petListViewModelProvider.future);
      await f.container.read(notificationViewModelProvider.future);
      await f.container.read(authViewModelProvider.future);

      f.signedIn = false;
      await f.container.read(authViewModelProvider.notifier).logout();

      // lazy 무효화: listener가 있으므로 스케줄러가 다음 이벤트 루프에 재빌드한다.
      await f.settle();
      expect(f.container.read(activePetViewModelProvider).valueOrNull, isNull);
      expect(f.container.read(petListViewModelProvider).valueOrNull, isEmpty);
      expect(
          f.container.read(notificationViewModelProvider).valueOrNull, isEmpty);
      verify(() => f.petRepo.getActivePet(
          forceRefresh: any(named: 'forceRefresh'))).called(2);
      verify(() => f.petRepo.getMyPets(forceRefresh: any(named: 'forceRefresh')))
          .called(2);
      verify(() => f.notifRepo.fetch()).called(2);
    });

    test('logout 직후에는 즉시 재조회하지 않는다 (인증 없는 요청 방지)', () async {
      final f = _SessionFixture();
      f.signedIn = true;
      when(() => f.authRepo.signOut()).thenAnswer((_) async {});
      // listener 없이 생성만 해 둔다 → invalidate는 lazy여야 한다.
      expect(
          (await f.container.read(activePetViewModelProvider.future))?.id, 'p1');
      await f.container.read(petListViewModelProvider.future);
      await f.container.read(authViewModelProvider.future);
      clearInteractions(f.petRepo);

      await f.container.read(authViewModelProvider.notifier).logout();
      await f.settle();

      verifyNever(() => f.petRepo.getActivePet(
          forceRefresh: any(named: 'forceRefresh')));
      verifyNever(
          () => f.petRepo.getMyPets(forceRefresh: any(named: 'forceRefresh')));
    });
  });
}
