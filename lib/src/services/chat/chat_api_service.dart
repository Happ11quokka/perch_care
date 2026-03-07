import '../../models/chat_session.dart';
import '../../models/chat_message.dart';
import '../api/api_client.dart';

/// 채팅 세션 API 서비스 (서버 동기화)
class ChatApiService {
  static final ChatApiService instance = ChatApiService._();
  ChatApiService._();

  final _api = ApiClient.instance;

  /// 첫 번째 메시지와 함께 새 채팅 세션 생성
  Future<ChatSession> createSession({
    String? petId,
    required String firstMessage,
  }) async {
    final body = <String, dynamic>{
      'first_message': firstMessage,
    };
    if (petId != null) body['pet_id'] = petId;
    final data = await _api.post('/chat/sessions', body: body);
    return ChatSession.fromJson(data as Map<String, dynamic>);
  }

  /// 사용자의 채팅 세션 목록 조회
  Future<List<ChatSession>> getUserSessions() async {
    final data = await _api.get('/chat/sessions');
    final list = data as List<dynamic>;
    return list
        .map((e) => ChatSession.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 특정 세션의 메시지 목록 조회
  Future<List<ChatMessage>> getSessionMessages(String sessionId) async {
    final data = await _api.get('/chat/sessions/$sessionId/messages');
    final list = data as List<dynamic>;
    return list.map((e) {
      final json = e as Map<String, dynamic>;
      return ChatMessage(
        id: json['id'] as String,
        sessionId: json['session_id'] as String,
        role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        text: json['content'] as String,
        timestamp: DateTime.parse(json['created_at'] as String),
      );
    }).toList();
  }

  /// 세션에 메시지 추가
  Future<void> addMessage({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    await _api.post('/chat/sessions/$sessionId/messages', body: {
      'role': role,
      'content': content,
    });
  }

  /// 세션 삭제
  Future<void> deleteSession(String sessionId) async {
    await _api.delete('/chat/sessions/$sessionId');
  }
}
