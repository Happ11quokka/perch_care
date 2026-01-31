import '../api/api_client.dart';

/// 서버 프록시를 통한 AI 백과사전 서비스
class AiEncyclopediaService {
  AiEncyclopediaService();

  final _api = ApiClient.instance;

  /// 질의에 대한 답변을 반환합니다.
  Future<String> ask({
    required String query,
    List<Map<String, String>> history = const [],
    String? petId,
    double temperature = 0.2,
    int maxTokens = 512,
    String? petProfileContext,
  }) async {
    final body = <String, dynamic>{
      'query': query,
      'history': history,
      if (petId != null) 'pet_id': petId,
      'temperature': temperature,
      'max_tokens': maxTokens,
      if (petProfileContext != null) 'pet_profile_context': petProfileContext,
    };

    final response = await _api.post('/ai/encyclopedia', body: body);
    return response['answer'] as String;
  }
}
