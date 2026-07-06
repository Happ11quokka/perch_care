import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/view_models/auth/auth_view_model.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

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
}
