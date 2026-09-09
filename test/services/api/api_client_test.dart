// ApiClient 토큰 갱신/재시도 회귀 테스트 (2026-09-09 감사 F01/F02)
//
// - F01: 401 → refresh 성공 → 재시도 요청은 반드시 갱신된 access token을 사용
// - F02: refresh 중 일시적 실패(네트워크/타임아웃/5xx)는 세션을 지우지 않고,
//        명시적 거부(401/403)만 토큰을 삭제
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:perch_care/src/services/api/api_client.dart';
import 'package:perch_care/src/services/api/token_service.dart';

/// MockClient를 ApiClient 내부 http.Client로 주입한다.
/// ApiClient.initialize()가 http.Client()를 생성하므로 runWithClient 안에서 호출.
void _installClient(MockClient mock) {
  http.runWithClient(ApiClient.initialize, () => mock);
}

http.Response _refreshOk({String access = 'new', String refresh = 'next'}) =>
    http.Response(
      jsonEncode({'access_token': access, 'refresh_token': refresh}),
      200,
    );

http.Response _expired() => http.Response('{"detail":"expired"}', 401);

bool _isRefresh(http.Request r) => r.url.path.endsWith('/auth/refresh');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenService.instance.init();
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://audit.invalid/api/v1');
  });

  setUp(() async {
    await TokenService.instance.saveTokens(
      accessToken: 'old',
      refreshToken: 'refresh',
    );
  });

  group('F01 — retry after refresh uses the new access token', () {
    for (final method in ['GET', 'POST', 'PUT', 'DELETE', 'POST_AI']) {
      test('$method retries with Bearer new', () async {
        final seen = <String?>[];
        _installClient(MockClient((request) async {
          if (_isRefresh(request)) return _refreshOk();
          seen.add(request.headers['Authorization']);
          return request.headers['Authorization'] == 'Bearer new'
              ? http.Response('{}', 200)
              : _expired();
        }));

        final api = ApiClient.instance;
        switch (method) {
          case 'GET':
            await api.get('/pets/');
          case 'POST':
            await api.post('/pets/', body: {'name': 'test'});
          case 'PUT':
            await api.put('/pets/1', body: {'name': 'test'});
          case 'DELETE':
            await api.delete('/pets/1');
          case 'POST_AI':
            await api.postAI('/ai/x', body: {'q': 'test'});
        }

        expect(seen, ['Bearer old', 'Bearer new']);
        expect(TokenService.instance.accessToken, 'new');
        expect(TokenService.instance.refreshToken, 'next');
      });
    }

    test('multipart upload retries with Bearer new', () async {
      final seen = <String?>[];
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) return _refreshOk();
        seen.add(request.headers['Authorization']);
        return request.headers['Authorization'] == 'Bearer new'
            ? http.Response('{}', 200)
            : _expired();
      }));

      await ApiClient.instance.uploadMultipart(
        '/upload',
        fields: {'a': 'b'},
        fileBytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'x.png',
      );

      expect(seen, ['Bearer old', 'Bearer new']);
    });

    test('concurrent 401s trigger a single refresh call', () async {
      var refreshCalls = 0;
      final firstRefresh = Completer<void>();
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) {
          refreshCalls++;
          await firstRefresh.future;
          return _refreshOk();
        }
        return request.headers['Authorization'] == 'Bearer new'
            ? http.Response('{}', 200)
            : _expired();
      }));

      final api = ApiClient.instance;
      final futures = [
        api.get('/a'),
        api.post('/b', body: {}),
        api.put('/c', body: {}),
      ];
      // 세 요청 모두 401을 받고 refresh 대기 중이 되도록 이벤트 루프를 돌린다
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      firstRefresh.complete();
      await Future.wait(futures);

      expect(refreshCalls, 1);
      expect(TokenService.instance.accessToken, 'new');
    });
  });

  group('F02 — transient refresh failure keeps the session', () {
    test('refresh ClientException keeps tokens and surfaces the error',
        () async {
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) throw http.ClientException('offline');
        return _expired();
      }));

      await expectLater(
        ApiClient.instance.get('/pets/'),
        throwsA(isA<http.ClientException>()),
      );

      expect(TokenService.instance.accessToken, 'old');
      expect(TokenService.instance.refreshToken, 'refresh');
    });

    test('refresh timeout keeps tokens', () async {
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) {
          // ApiClient의 _refreshTimeout(5s)보다 길게 지연 → TimeoutException
          await Future<void>.delayed(const Duration(seconds: 6));
          return _refreshOk();
        }
        return _expired();
      }));

      await expectLater(
        ApiClient.instance.get('/pets/'),
        throwsA(isA<TimeoutException>()),
      );

      expect(TokenService.instance.refreshToken, 'refresh');
    });

    test('refresh 5xx keeps tokens and throws ApiException(5xx)', () async {
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) {
          return http.Response('{"detail":"db down"}', 503);
        }
        return _expired();
      }));

      await expectLater(
        ApiClient.instance.post('/pets/', body: {}),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 503),
        ),
      );

      expect(TokenService.instance.accessToken, 'old');
      expect(TokenService.instance.refreshToken, 'refresh');
    });

    test('tryRefreshToken returns false on network failure without clearing',
        () async {
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) throw http.ClientException('offline');
        return _expired();
      }));

      expect(await ApiClient.instance.tryRefreshToken(), isFalse);
      expect(TokenService.instance.refreshToken, 'refresh');
    });

    test('a failed single-flight refresh does not poison the next attempt',
        () async {
      var refreshCalls = 0;
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) {
          refreshCalls++;
          if (refreshCalls == 1) throw http.ClientException('offline');
          return _refreshOk();
        }
        return request.headers['Authorization'] == 'Bearer new'
            ? http.Response('{}', 200)
            : _expired();
      }));

      await expectLater(
        ApiClient.instance.get('/pets/'),
        throwsA(isA<http.ClientException>()),
      );
      // 두 번째 시도는 정상 갱신 후 성공해야 한다
      await ApiClient.instance.get('/pets/');

      expect(refreshCalls, 2);
      expect(TokenService.instance.accessToken, 'new');
    });
  });

  group('F02 — explicit rejection clears the session', () {
    for (final code in [401, 403]) {
      test('refresh $code clears tokens and original 401 is surfaced',
          () async {
        _installClient(MockClient((request) async {
          if (_isRefresh(request)) {
            return http.Response('{"detail":"Invalid refresh token"}', code);
          }
          return _expired();
        }));

        await expectLater(
          ApiClient.instance.get('/pets/'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
          ),
        );

        expect(TokenService.instance.accessToken, isNull);
        expect(TokenService.instance.refreshToken, isNull);
      });
    }

    test('refresh 422 whose body says the refresh token is invalid clears',
        () async {
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) {
          return http.Response('{"detail":"Refresh token expired"}', 422);
        }
        return _expired();
      }));

      try {
        await ApiClient.instance.get('/pets/');
      } catch (_) {}

      expect(TokenService.instance.refreshToken, isNull);
    });

    test('refresh 422 with unrelated body keeps tokens', () async {
      _installClient(MockClient((request) async {
        if (_isRefresh(request)) {
          return http.Response('{"detail":"validation error"}', 422);
        }
        return _expired();
      }));

      try {
        await ApiClient.instance.get('/pets/');
      } catch (_) {}

      expect(TokenService.instance.refreshToken, 'refresh');
    });
  });
}
