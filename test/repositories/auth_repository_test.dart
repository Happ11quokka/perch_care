import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/repositories/auth_repository.dart';
import 'package:perch_care/src/services/auth/auth_service.dart';
import 'package:perch_care/src/services/api/token_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockTokenService extends Mock implements TokenService {}

void main() {
  late MockAuthService service;
  late MockTokenService tokenService;
  late AuthRepository repo;

  setUp(() {
    service = MockAuthService();
    tokenService = MockTokenService();
    repo = AuthRepositoryImpl(service: service, tokenService: tokenService);
  });

  group('isLoggedIn', () {
    test('delegates to service', () {
      when(() => service.isLoggedIn).thenReturn(true);
      expect(repo.isLoggedIn, true);
      verify(() => service.isLoggedIn).called(1);
    });
  });

  group('signInWithEmail', () {
    test('calls service then returns LoginAuthenticated with hasPets', () async {
      when(() => service.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => service.hasPets()).thenAnswer((_) async => true);

      final result = await repo.signInWithEmail(
        email: 'a@b.com',
        password: 'pw',
      );

      verify(() => service.signInWithEmailPassword(
            email: 'a@b.com',
            password: 'pw',
          )).called(1);
      verify(() => service.hasPets()).called(1);
      expect(result, isA<LoginAuthenticated>());
      expect((result as LoginAuthenticated).hasPets, true);
    });

    test('propagates service error', () async {
      when(() => service.signInWithEmailPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('401'));

      await expectLater(
        repo.signInWithEmail(email: 'a@b.com', password: 'pw'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('signUpWithEmail', () {
    test('delegates to service', () async {
      when(() => service.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            nickname: any(named: 'nickname'),
            marketingAgreed: any(named: 'marketingAgreed'),
          )).thenAnswer((_) async {});

      await repo.signUpWithEmail(
        email: 'a@b.com',
        password: 'pw',
        nickname: 'nick',
        marketingAgreed: true,
      );

      verify(() => service.signUpWithEmail(
            email: 'a@b.com',
            password: 'pw',
            nickname: 'nick',
            marketingAgreed: true,
          )).called(1);
    });
  });

  group('discardSession', () {
    test('delegates to tokenService.clearTokens', () async {
      when(() => tokenService.clearTokens()).thenAnswer((_) async {});

      await repo.discardSession();

      verify(() => tokenService.clearTokens()).called(1);
      verifyNever(() => service.signOut());
    });
  });

  group('signInWithGoogle', () {
    test('signupRequired maps to LoginSignupRequired', () async {
      when(() => service.signInWithGoogle(idToken: any(named: 'idToken')))
          .thenAnswer((_) async => SocialLoginResult.signupNeeded(
                provider: 'google',
                providerId: 'gid-1',
                providerEmail: 'g@x.com',
              ));

      final result = await repo.signInWithGoogle(idToken: 'tok');

      expect(result, isA<LoginSignupRequired>());
      final signup = result as LoginSignupRequired;
      expect(signup.provider, 'google');
      expect(signup.providerId, 'gid-1');
      expect(signup.providerEmail, 'g@x.com');
    });

    test('authenticated maps to LoginAuthenticated', () async {
      when(() => service.signInWithGoogle(idToken: any(named: 'idToken')))
          .thenAnswer(
              (_) async => SocialLoginResult.authenticated(hasPets: true));

      final result = await repo.signInWithGoogle(idToken: 'tok');

      expect(result, isA<LoginAuthenticated>());
      expect((result as LoginAuthenticated).hasPets, true);
    });
  });

  group('signInWithApple', () {
    test('signupRequired maps to LoginSignupRequired', () async {
      when(() => service.signInWithApple(
            idToken: any(named: 'idToken'),
            userIdentifier: any(named: 'userIdentifier'),
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
          )).thenAnswer((_) async => SocialLoginResult.signupNeeded(
            provider: 'apple',
            providerId: 'aid-1',
            providerEmail: 'a@x.com',
          ));

      final result = await repo.signInWithApple(
        idToken: 'tok',
        userIdentifier: 'uid',
        fullName: 'Name',
        email: 'a@x.com',
      );

      expect(result, isA<LoginSignupRequired>());
      final signup = result as LoginSignupRequired;
      expect(signup.provider, 'apple');
      expect(signup.providerId, 'aid-1');
      expect(signup.providerEmail, 'a@x.com');
    });

    test('authenticated maps to LoginAuthenticated', () async {
      when(() => service.signInWithApple(
            idToken: any(named: 'idToken'),
            userIdentifier: any(named: 'userIdentifier'),
            fullName: any(named: 'fullName'),
            email: any(named: 'email'),
          )).thenAnswer(
              (_) async => SocialLoginResult.authenticated(hasPets: false));

      final result = await repo.signInWithApple(idToken: 'tok');

      expect(result, isA<LoginAuthenticated>());
      expect((result as LoginAuthenticated).hasPets, false);
    });
  });

  group('hasPets tri-state', () {
    test('true passes through unchanged', () async {
      when(() => service.hasPets()).thenAnswer((_) async => true);
      expect(await repo.hasPets(), true);
    });

    test('false passes through unchanged', () async {
      when(() => service.hasPets()).thenAnswer((_) async => false);
      expect(await repo.hasPets(), false);
    });

    test('null passes through unchanged', () async {
      when(() => service.hasPets()).thenAnswer((_) async => null);
      expect(await repo.hasPets(), null);
    });
  });

  group('simple delegations', () {
    test('signOut', () async {
      when(() => service.signOut()).thenAnswer((_) async {});
      await repo.signOut();
      verify(() => service.signOut()).called(1);
    });

    test('deleteAccount', () async {
      when(() => service.deleteAccount()).thenAnswer((_) async {});
      await repo.deleteAccount();
      verify(() => service.deleteAccount()).called(1);
    });

    test('resetPassword', () async {
      when(() => service.resetPassword(any())).thenAnswer((_) async {});
      await repo.resetPassword('a@b.com');
      verify(() => service.resetPassword('a@b.com')).called(1);
    });

    test('resetPasswordByPhone', () async {
      when(() => service.resetPasswordByPhone(any()))
          .thenAnswer((_) async {});
      await repo.resetPasswordByPhone('010-1234-5678');
      verify(() => service.resetPasswordByPhone('010-1234-5678')).called(1);
    });

    test('verifyResetCode', () async {
      when(() => service.verifyResetCode(any(), any(),
          method: any(named: 'method'))).thenAnswer((_) async {});
      await repo.verifyResetCode('a@b.com', '1234', method: 'email');
      verify(() => service.verifyResetCode('a@b.com', '1234', method: 'email'))
          .called(1);
    });

    test('updatePassword', () async {
      when(() => service.updatePassword(
            identifier: any(named: 'identifier'),
            code: any(named: 'code'),
            newPassword: any(named: 'newPassword'),
            method: any(named: 'method'),
          )).thenAnswer((_) async {});

      await repo.updatePassword(
        identifier: 'a@b.com',
        code: '1234',
        newPassword: 'newpw',
        method: 'email',
      );

      verify(() => service.updatePassword(
            identifier: 'a@b.com',
            code: '1234',
            newPassword: 'newpw',
            method: 'email',
          )).called(1);
    });

    test('getProfile', () async {
      when(() => service.getProfile())
          .thenAnswer((_) async => {'nickname': 'n'});
      final result = await repo.getProfile();
      expect(result, {'nickname': 'n'});
    });

    test('updateProfile', () async {
      when(() => service.updateProfile(
            nickname: any(named: 'nickname'),
            avatarUrl: any(named: 'avatarUrl'),
          )).thenAnswer((_) async {});

      await repo.updateProfile(nickname: 'nick', avatarUrl: 'url');

      verify(() => service.updateProfile(nickname: 'nick', avatarUrl: 'url'))
          .called(1);
    });

    test('linkSocialAccount', () async {
      when(() => service.linkSocialAccount(
            provider: any(named: 'provider'),
            idToken: any(named: 'idToken'),
            accessToken: any(named: 'accessToken'),
            providerId: any(named: 'providerId'),
            providerEmail: any(named: 'providerEmail'),
          )).thenAnswer((_) async {});

      await repo.linkSocialAccount(provider: 'google', idToken: 'tok');

      verify(() => service.linkSocialAccount(
            provider: 'google',
            idToken: 'tok',
            accessToken: null,
            providerId: null,
            providerEmail: null,
          )).called(1);
    });

    test('getSocialAccounts', () async {
      final accounts = [
        LinkedSocialAccount(
            provider: 'google', providerEmail: 'g@x.com', createdAt: 'now')
      ];
      when(() => service.getSocialAccounts()).thenAnswer((_) async => accounts);

      final result = await repo.getSocialAccounts();

      expect(result, accounts);
    });

    test('unlinkSocialAccount', () async {
      when(() => service.unlinkSocialAccount(any())).thenAnswer((_) async {});
      await repo.unlinkSocialAccount('google');
      verify(() => service.unlinkSocialAccount('google')).called(1);
    });
  });
}
