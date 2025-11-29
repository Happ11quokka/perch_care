import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Perplexity 호스티드 API를 통해 챗봇 답변을 가져오는 서비스
class AiEncyclopediaService {
  // Perplexity 모델 목록 참고: https://docs.perplexity.ai/getting-started/models
  static const String _defaultModel = 'sonar-reasoning';

  AiEncyclopediaService({
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _apiKey = dotenv.maybeGet('PERPLEXITY_API_KEY') ?? '',
        _baseUrl =
            dotenv.maybeGet('PERPLEXITY_API_BASE') ?? 'https://api.perplexity.ai';

  final http.Client _client;
  final String _apiKey;
  final String _baseUrl;

  /// 질의에 대한 답변을 반환합니다.
  ///
  /// [history]는 직전 메시지 목록으로, role(user/assistant), content 필드를 포함합니다.
  Future<String> ask({
    required String query,
    List<Map<String, String>> history = const [],
    String? model,
    double temperature = 0.2,
    int maxTokens = 512,
  }) async {
    if (_apiKey.isEmpty) {
      throw Exception('PERPLEXITY_API_KEY가 설정되지 않았습니다.');
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content':
            '너는 앵무새 케어 전문가야. 근거가 불확실하면 짧게 말하고 수의사 상담을 권장해. 5줄 이내로 답변해.',
      },
      ...history,
      {'role': 'user', 'content': query},
    ];

    final uri = Uri.parse('$_baseUrl/chat/completions');
    // 기본값: 온라인 검색 포함 소형 모델. 필요 시 PERPLEXITY_MODEL로 덮어쓰기.
    final selectedModel =
        model ?? dotenv.maybeGet('PERPLEXITY_MODEL') ?? _defaultModel;
    final res = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': selectedModel,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Perplexity 오류(${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final answer = data['choices']?[0]?['message']?['content'] as String?;
    if (answer == null || answer.isEmpty) {
      throw Exception('빈 응답을 받았습니다.');
    }
    return answer;
  }
}
