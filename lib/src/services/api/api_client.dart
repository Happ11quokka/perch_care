import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../config/environment.dart';
import 'token_service.dart';

/// FastAPI 백엔드와 통신하는 HTTP 클라이언트
class ApiClient {
  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  ApiClient._();

  static void initialize() {
    _instance = ApiClient._();
  }

  String get _baseUrl => Environment.apiBaseUrl;
  final _tokenService = TokenService.instance;

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
    };
  }

  Map<String, String> get _authHeaders {
    final token = _tokenService.accessToken;
    if (token == null) throw Exception('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// GET 요청
  Future<dynamic> get(String path, {Map<String, String>? queryParams}) async {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    final response = await _makeRequest(() => http.get(uri, headers: _authHeaders));
    return _handleResponse(response);
  }

  /// POST 요청
  Future<dynamic> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final headers = auth ? _authHeaders : _headers;
    final response = await _makeRequest(
      () => http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null),
    );
    return _handleResponse(response);
  }

  /// PUT 요청
  Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _makeRequest(
      () => http.put(uri, headers: _authHeaders, body: body != null ? jsonEncode(body) : null),
    );
    return _handleResponse(response);
  }

  /// DELETE 요청
  Future<void> delete(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await _makeRequest(() => http.delete(uri, headers: _authHeaders));
    if (response.statusCode != 204 && response.statusCode != 200) {
      _handleError(response);
    }
  }

  /// 멀티파트 파일 업로드
  Future<dynamic> uploadFile(String path, Uint8List fileBytes, String fileName) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer ${_tokenService.accessToken}';
    request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  /// 토큰 갱신이 포함된 요청 래퍼
  Future<http.Response> _makeRequest(Future<http.Response> Function() request) async {
    var response = await request();

    // 401이면 토큰 갱신 시도
    if (response.statusCode == 401 && _tokenService.refreshToken != null) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        response = await request();
      }
    }

    return response;
  }

  /// 토큰 갱신
  Future<bool> _refreshToken() async {
    try {
      final uri = Uri.parse('$_baseUrl/auth/refresh');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _tokenService.refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _tokenService.saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
        );
        return true;
      }
    } catch (_) {}

    // 갱신 실패 시 토큰 삭제
    await _tokenService.clearTokens();
    return false;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }
    _handleError(response);
  }

  Never _handleError(http.Response response) {
    String message;
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] ?? 'Unknown error';
    } catch (_) {
      message = response.body;
    }
    throw ApiException(statusCode: response.statusCode, message: message);
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException({required this.statusCode, required this.message});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
