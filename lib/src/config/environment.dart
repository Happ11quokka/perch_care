import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Key-value accessor for environment variables provided via `.env`.
class Environment {
  Environment._();

  static String get apiBaseUrl => _require('API_BASE_URL');

  /// 서버 루트 URL (API prefix 제거). 이미지 등 정적 파일 접근용.
  /// 예: https://perchcare-staging.up.railway.app
  static String get serverBaseUrl {
    final uri = Uri.parse(apiBaseUrl);
    return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
  }

  /// 서버 상대 경로를 절대 URL로 변환 (예: /uploads/... → https://server/uploads/...)
  static String resolveImageUrl(String relativePath) {
    return '$serverBaseUrl$relativePath';
  }

  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing `$key` in environment configuration.');
    }
    return value;
  }
}
