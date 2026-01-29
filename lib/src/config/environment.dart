import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Key-value accessor for environment variables provided via `.env`.
class Environment {
  Environment._();

  static String get apiBaseUrl => _require('API_BASE_URL');

  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing `$key` in environment configuration.');
    }
    return value;
  }
}
