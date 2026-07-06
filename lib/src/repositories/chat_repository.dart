import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/chat_session.dart';
import '../services/ai/ai_encyclopedia_service.dart';
import '../services/ai/ai_stream_service.dart';
import '../services/chat/chat_api_service.dart';
import '../services/storage/chat_storage_service.dart';

/// [ChatRepository.loadConversation] 결과 — 메시지 + 채택된 서버 세션 id(없으면 null).
class ConversationLoad {
  const ConversationLoad({required this.messages, this.sessionId});

  final List<ChatMessage> messages;
  final String? sessionId;
}

/// AI 백과사전 챗봇 Repository.
///
/// 서버/로컬 병합 정책(서버 우선 + 로컬 미러 + 폴백), 세션 CRUD, SSE/동기 fallback
/// 통과를 캡슐화한다. View는 이 인터페이스만 의존하고 4개 서비스 싱글턴을 직접
/// 호출하지 않는다.
abstract class ChatRepository {
  /// 서버 우선(getUserSessions→petId 매칭 첫 세션→getSessionMessages)+로컬 미러,
  /// 서버 실패 또는 매칭 세션 없음 시 로컬 폴백.
  Future<ConversationLoad> loadConversation(String? petId);

  /// 대화 내역 로컬 저장.
  Future<void> saveLocal(String? petId, List<ChatMessage> messages);

  /// 서버 세션 생성 — 실패 시 null(무음, 대화는 계속 진행).
  Future<ChatSession?> createSession({
    String? petId,
    required String firstMessage,
  });

  /// 메시지 서버 저장 — fire-and-forget(실패 삼킴, 절대 throw하지 않음).
  Future<void> saveMessageToServer({
    required String sessionId,
    required String role,
    required String content,
  });

  /// 대화 삭제 — 로컬 clear + (sessionId 있으면) 서버 세션 삭제(무음).
  Future<void> clearConversation({String? petId, String? sessionId});

  /// SSE 토큰 스트림 통과 — ApiException(429 등)은 그대로 전파(View가 처리).
  Stream<String> streamAnswer({
    required String query,
    List<Map<String, String>> history,
    String? petId,
    String? petProfileContext,
  });

  /// 동기 fallback — 문자열 반환, ApiException 전파.
  Future<String> askAnswer({
    required String query,
    List<Map<String, String>> history,
    String? petId,
    String? petProfileContext,
  });
}

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    AiStreamService? stream,
    AiEncyclopediaService? ai,
    ChatStorageService? storage,
    ChatApiService? chatApi,
  })  : _stream = stream ?? AiStreamService.instance,
        _ai = ai ?? AiEncyclopediaService.instance,
        _storage = storage ?? ChatStorageService.instance,
        _chatApi = chatApi ?? ChatApiService.instance;

  final AiStreamService _stream;
  final AiEncyclopediaService _ai;
  final ChatStorageService _storage;
  final ChatApiService _chatApi;

  @override
  Future<ConversationLoad> loadConversation(String? petId) async {
    try {
      // 서버에서 세션 목록 로드 시도
      final sessions = await _chatApi.getUserSessions();
      final matching = sessions.where((s) => s.petId == petId).toList();
      if (matching.isNotEmpty) {
        final session = matching.first;
        final serverMessages = await _chatApi.getSessionMessages(session.id);
        // 로컬 캐시 업데이트(미러)
        await _storage.saveMessages(petId, serverMessages);
        return ConversationLoad(
          messages: serverMessages,
          sessionId: session.id,
        );
      }
    } catch (e) {
      debugPrint('[ChatRepository] Server load failed, using local: $e');
    }

    // 로컬 폴백
    final messages = await _storage.loadMessages(petId);
    return ConversationLoad(messages: messages, sessionId: null);
  }

  @override
  Future<void> saveLocal(String? petId, List<ChatMessage> messages) {
    return _storage.saveMessages(petId, messages);
  }

  @override
  Future<ChatSession?> createSession({
    String? petId,
    required String firstMessage,
  }) async {
    try {
      return await _chatApi.createSession(
        petId: petId,
        firstMessage: firstMessage,
      );
    } catch (e) {
      debugPrint('[ChatRepository] Session creation failed: $e');
      return null;
    }
  }

  @override
  Future<void> saveMessageToServer({
    required String sessionId,
    required String role,
    required String content,
  }) async {
    try {
      await _chatApi.addMessage(
        sessionId: sessionId,
        role: role,
        content: content,
      );
    } catch (e) {
      debugPrint('[ChatRepository] Message save failed: $e');
    }
  }

  @override
  Future<void> clearConversation({String? petId, String? sessionId}) async {
    await _storage.clearMessages(petId);
    if (sessionId != null) {
      try {
        await _chatApi.deleteSession(sessionId);
      } catch (e) {
        debugPrint('[ChatRepository] Session delete failed: $e');
      }
    }
  }

  @override
  Stream<String> streamAnswer({
    required String query,
    List<Map<String, String>> history = const [],
    String? petId,
    String? petProfileContext,
  }) {
    return _stream.streamEncyclopedia(
      query: query,
      history: history,
      petId: petId,
      petProfileContext: petProfileContext,
    );
  }

  @override
  Future<String> askAnswer({
    required String query,
    List<Map<String, String>> history = const [],
    String? petId,
    String? petProfileContext,
  }) async {
    return _ai.ask(
      query: query,
      history: history,
      petId: petId,
      petProfileContext: petProfileContext,
    );
  }
}
