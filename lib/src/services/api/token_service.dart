import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT 토큰 관리 서비스
class TokenService {
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  static TokenService? _instance;
  static TokenService get instance => _instance ??= TokenService._();

  TokenService._();

  final _secureStorage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  String? _accessToken;
  String? _refreshToken;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const maxRetries = 3;
    for (var i = 0; i < maxRetries; i++) {
      try {
        _accessToken = await _secureStorage.read(key: _accessTokenKey);
        _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
        debugPrint('TokenService init success: hasAccessToken=${_accessToken != null}');
        _initialized = true;
        return;
      } catch (e, stackTrace) {
        debugPrint('TokenService init attempt ${i + 1} error: $e');
        if (i == maxRetries - 1) {
          debugPrint('TokenService stackTrace: $stackTrace');
          _accessToken = null;
          _refreshToken = null;
        } else {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
        }
      }
    }
    _initialized = true;
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isInitialized => _initialized;
  bool get isLoggedIn => _initialized && _accessToken != null;

  /// 토큰에서 사용자 ID 추출
  String? get userId {
    if (_accessToken == null) return null;
    try {
      final parts = _accessToken!.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final map = jsonDecode(payload) as Map<String, dynamic>;
      return map['sub'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    await _secureStorage.write(key: _accessTokenKey, value: accessToken);
    await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }
}
