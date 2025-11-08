import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Key-value accessor for environment variables provided via `.env`.
class Environment {
  Environment._();

  static String get supabaseUrl => _require('SUPABASE_URL');
  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String _require(String key) {
    final value = dotenv.maybeGet(key);
    if (value == null || value.isEmpty) {
      throw StateError('Missing `$key` in environment configuration.');
    }
    return value;
  }
}
