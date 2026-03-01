import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/environment.dart';
import '../api/api_client.dart';
import '../api/token_service.dart';

/// SSE 스트리밍 방식의 AI 백과사전 클라이언트.
///
/// 백엔드 `POST /ai/encyclopedia/stream` 엔드포인트에 연결하여
/// 토큰 단위로 응답을 수신한다. 실패 시 호출측에서 동기 API로 fallback.
class AiStreamService {
  AiStreamService();

  static const _timeout = Duration(seconds: 30);

  /// SSE 스트리밍으로 AI 응답을 토큰 단위로 수신한다.
  ///
  /// 각 yield는 하나의 토큰 문자열이며, 스트림이 정상 완료되면 종료된다.
  /// HTTP 에러 또는 SSE 에러 이벤트 수신 시 [Exception]을 throw한다.
  /// 401 응답 시 토큰 갱신 후 1회 재시도한다.
  Stream<String> streamEncyclopedia({
    required String query,
    List<Map<String, String>> history = const [],
    String? petId,
    double temperature = 0.2,
    int maxTokens = 512,
    String? petProfileContext,
  }) async* {
    yield* _tryStream(
      query: query,
      history: history,
      petId: petId,
      temperature: temperature,
      maxTokens: maxTokens,
      petProfileContext: petProfileContext,
      isRetry: false,
    );
  }

  Stream<String> _tryStream({
    required String query,
    required List<Map<String, String>> history,
    String? petId,
    required double temperature,
    required int maxTokens,
    String? petProfileContext,
    required bool isRetry,
  }) async* {
    final token = TokenService.instance.accessToken;
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Not authenticated');
    }

    final uri = Uri.parse('${Environment.apiBaseUrl}/ai/encyclopedia/stream');
    final request = http.Request('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'query': query,
      'history': history,
      if (petId != null) 'pet_id': petId,
      'temperature': temperature,
      'max_tokens': maxTokens,
      if (petProfileContext != null) 'pet_profile_context': petProfileContext,
    });

    final client = http.Client();
    try {
      final response = await client.send(request).timeout(_timeout);

      // P1: 401 시 토큰 갱신 후 1회 재시도
      if (response.statusCode == 401 && !isRetry) {
        client.close();
        // ApiClient의 토큰 갱신 로직 활용을 위해 간단한 GET으로 갱신 유도
        // 또는 직접 refresh 시도
        final refreshed = await _refreshTokenIfNeeded();
        if (refreshed) {
          yield* _tryStream(
            query: query,
            history: history,
            petId: petId,
            temperature: temperature,
            maxTokens: maxTokens,
            petProfileContext: petProfileContext,
            isRetry: true,
          );
          return;
        }
      }

      if (response.statusCode != 200) {
        // P2: 서버 에러 body를 사용자에게 그대로 노출하지 않음
        final body = await response.stream.bytesToString().timeout(_timeout);
        if (kDebugMode) {
          debugPrint('[AiStreamService] SSE error ${response.statusCode}: $body');
        }
        throw ApiException(
          statusCode: response.statusCode,
          message: 'SSE 연결에 실패했습니다 (${response.statusCode})',
        );
      }

      // SSE 파싱: 청크 경계에서 줄이 잘릴 수 있으므로 버퍼링 처리
      final buffer = StringBuffer();

      await for (final chunk
          in response.stream.transform(utf8.decoder).timeout(_timeout)) {
        buffer.write(chunk);
        final buffered = buffer.toString();
        final lines = buffered.split('\n');

        // 마지막 요소는 아직 완성되지 않은 줄일 수 있으므로 버퍼에 유지
        buffer.clear();
        buffer.write(lines.last);

        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6);
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;

              if (data.containsKey('token')) {
                yield data['token'] as String;
              } else if (data['done'] == true) {
                return;
              } else if (data.containsKey('error')) {
                throw Exception(data['error'] as String);
              }
            } on FormatException catch (e) {
              // P2: JSON 파싱 에러는 FormatException으로 명시적 처리
              if (kDebugMode) {
                debugPrint('[AiStreamService] JSON parse error: $e');
              }
              // 불완전한 청크일 수 있으므로 무시하고 계속
            }
          }
        }
      }
    } finally {
      client.close();
    }
  }

  /// 토큰 갱신 시도. ApiClient의 refresh 엔드포인트를 직접 호출.
  Future<bool> _refreshTokenIfNeeded() async {
    final refreshToken = TokenService.instance.refreshToken;
    if (refreshToken == null) return false;

    try {
      final uri = Uri.parse('${Environment.apiBaseUrl}/auth/refresh');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await TokenService.instance.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AiStreamService] Token refresh failed: $e');
      }
    }
    return false;
  }
}
