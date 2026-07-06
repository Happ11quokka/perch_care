import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/chat_message.dart';
import 'package:perch_care/src/models/chat_session.dart';
import 'package:perch_care/src/repositories/chat_repository.dart';
import 'package:perch_care/src/services/ai/ai_encyclopedia_service.dart';
import 'package:perch_care/src/services/ai/ai_stream_service.dart';
import 'package:perch_care/src/services/chat/chat_api_service.dart';
import 'package:perch_care/src/services/storage/chat_storage_service.dart';

class MockAiStreamService extends Mock implements AiStreamService {}

class MockAiEncyclopediaService extends Mock implements AiEncyclopediaService {}

class MockChatStorageService extends Mock implements ChatStorageService {}

class MockChatApiService extends Mock implements ChatApiService {}

ChatMessage _message({MessageRole role = MessageRole.user, String text = 'hi'}) {
  return ChatMessage(role: role, text: text, timestamp: DateTime(2026, 7, 1));
}

ChatSession _session({String id = 'session-1', String? petId = 'pet-1'}) {
  return ChatSession(
    id: id,
    petId: petId,
    title: 'title',
    startedAt: DateTime(2026, 7, 1),
    lastMessageAt: DateTime(2026, 7, 1),
    messageCount: 1,
  );
}

void main() {
  late MockAiStreamService stream;
  late MockAiEncyclopediaService ai;
  late MockChatStorageService storage;
  late MockChatApiService chatApi;
  late ChatRepository repo;

  setUpAll(() {
    registerFallbackValue(<ChatMessage>[]);
    registerFallbackValue(<Map<String, String>>[]);
  });

  setUp(() {
    stream = MockAiStreamService();
    ai = MockAiEncyclopediaService();
    storage = MockChatStorageService();
    chatApi = MockChatApiService();
    repo = ChatRepositoryImpl(
      stream: stream,
      ai: ai,
      storage: storage,
      chatApi: chatApi,
    );
  });

  group('loadConversation', () {
    test('server success with matching session mirrors to local and sets sessionId',
        () async {
      final session = _session(id: 'session-1', petId: 'pet-1');
      final serverMessages = [_message(text: 'from server')];
      when(() => chatApi.getUserSessions()).thenAnswer((_) async => [session]);
      when(() => chatApi.getSessionMessages('session-1'))
          .thenAnswer((_) async => serverMessages);
      when(() => storage.saveMessages(any(), any())).thenAnswer((_) async {});

      final result = await repo.loadConversation('pet-1');

      expect(result.messages, serverMessages);
      expect(result.sessionId, 'session-1');
      verify(() => storage.saveMessages('pet-1', serverMessages)).called(1);
      verifyNever(() => storage.loadMessages(any()));
    });

    test('server throws falls back to local, sessionId null', () async {
      when(() => chatApi.getUserSessions()).thenThrow(Exception('network'));
      final localMessages = [_message(text: 'from local')];
      when(() => storage.loadMessages('pet-1'))
          .thenAnswer((_) async => localMessages);

      final result = await repo.loadConversation('pet-1');

      expect(result.messages, localMessages);
      expect(result.sessionId, isNull);
      verifyNever(() => storage.saveMessages(any(), any()));
    });

    test('no matching session falls back to local, sessionId null', () async {
      final otherSession = _session(id: 'session-2', petId: 'other-pet');
      when(() => chatApi.getUserSessions())
          .thenAnswer((_) async => [otherSession]);
      final localMessages = [_message(text: 'from local')];
      when(() => storage.loadMessages('pet-1'))
          .thenAnswer((_) async => localMessages);

      final result = await repo.loadConversation('pet-1');

      expect(result.messages, localMessages);
      expect(result.sessionId, isNull);
      verifyNever(() => chatApi.getSessionMessages(any()));
      verifyNever(() => storage.saveMessages(any(), any()));
    });

    test(
        'matching session but messages fetch fails keeps sessionId (prevents '
        'duplicate server session) and falls back to local messages', () async {
      final session = _session(id: 'session-1', petId: 'pet-1');
      when(() => chatApi.getUserSessions()).thenAnswer((_) async => [session]);
      when(() => chatApi.getSessionMessages('session-1'))
          .thenThrow(Exception('messages timeout'));
      final localMessages = [_message(text: 'from local')];
      when(() => storage.loadMessages('pet-1'))
          .thenAnswer((_) async => localMessages);

      final result = await repo.loadConversation('pet-1');

      // The matched session must stay bound so the next send routes to it
      // instead of createSession() spawning a duplicate for the same pet.
      expect(result.sessionId, 'session-1');
      expect(result.messages, localMessages);
      verifyNever(() => storage.saveMessages(any(), any()));
    });
  });

  group('saveLocal', () {
    test('delegates to storage.saveMessages', () async {
      final messages = [_message()];
      when(() => storage.saveMessages('pet-1', messages))
          .thenAnswer((_) async {});

      await repo.saveLocal('pet-1', messages);

      verify(() => storage.saveMessages('pet-1', messages)).called(1);
    });
  });

  group('createSession', () {
    test('success returns session', () async {
      final session = _session();
      when(() => chatApi.createSession(
            petId: any(named: 'petId'),
            firstMessage: any(named: 'firstMessage'),
          )).thenAnswer((_) async => session);

      final result =
          await repo.createSession(petId: 'pet-1', firstMessage: 'hello');

      expect(result, session);
    });

    test('throws returns null (silent)', () async {
      when(() => chatApi.createSession(
            petId: any(named: 'petId'),
            firstMessage: any(named: 'firstMessage'),
          )).thenThrow(Exception('fail'));

      final result =
          await repo.createSession(petId: 'pet-1', firstMessage: 'hello');

      expect(result, isNull);
    });
  });

  group('saveMessageToServer', () {
    test('success calls addMessage', () async {
      when(() => chatApi.addMessage(
            sessionId: any(named: 'sessionId'),
            role: any(named: 'role'),
            content: any(named: 'content'),
          )).thenAnswer((_) async {});

      await repo.saveMessageToServer(
        sessionId: 'session-1',
        role: 'user',
        content: 'hi',
      );

      verify(() => chatApi.addMessage(
            sessionId: 'session-1',
            role: 'user',
            content: 'hi',
          )).called(1);
    });

    test('throws does not rethrow (swallowed)', () async {
      when(() => chatApi.addMessage(
            sessionId: any(named: 'sessionId'),
            role: any(named: 'role'),
            content: any(named: 'content'),
          )).thenThrow(Exception('fail'));

      await expectLater(
        repo.saveMessageToServer(
          sessionId: 'session-1',
          role: 'user',
          content: 'hi',
        ),
        completes,
      );
    });
  });

  group('clearConversation', () {
    test('without sessionId: clears local only', () async {
      when(() => storage.clearMessages('pet-1')).thenAnswer((_) async {});

      await repo.clearConversation(petId: 'pet-1');

      verify(() => storage.clearMessages('pet-1')).called(1);
      verifyNever(() => chatApi.deleteSession(any()));
    });

    test('with sessionId: clears local and deletes server session', () async {
      when(() => storage.clearMessages('pet-1')).thenAnswer((_) async {});
      when(() => chatApi.deleteSession('session-1')).thenAnswer((_) async {});

      await repo.clearConversation(petId: 'pet-1', sessionId: 'session-1');

      verify(() => storage.clearMessages('pet-1')).called(1);
      verify(() => chatApi.deleteSession('session-1')).called(1);
    });

    test('server delete failure is swallowed', () async {
      when(() => storage.clearMessages('pet-1')).thenAnswer((_) async {});
      when(() => chatApi.deleteSession('session-1'))
          .thenThrow(Exception('fail'));

      await expectLater(
        repo.clearConversation(petId: 'pet-1', sessionId: 'session-1'),
        completes,
      );
    });
  });

  group('streamAnswer', () {
    test('passes through the stream service stream', () async {
      when(() => stream.streamEncyclopedia(
            query: any(named: 'query'),
            history: any(named: 'history'),
            petId: any(named: 'petId'),
            petProfileContext: any(named: 'petProfileContext'),
          )).thenAnswer((_) => Stream.fromIterable(['a', 'b']));

      final result = await repo
          .streamAnswer(query: 'q', petId: 'pet-1')
          .toList();

      expect(result, ['a', 'b']);
    });

    test('propagates errors from the underlying stream', () async {
      when(() => stream.streamEncyclopedia(
            query: any(named: 'query'),
            history: any(named: 'history'),
            petId: any(named: 'petId'),
            petProfileContext: any(named: 'petProfileContext'),
          )).thenAnswer((_) => Stream.error(Exception('sse fail')));

      expect(
        repo.streamAnswer(query: 'q', petId: 'pet-1'),
        emitsError(isException),
      );
    });
  });

  group('askAnswer', () {
    test('delegates to ai.ask and returns its result', () async {
      when(() => ai.ask(
            query: any(named: 'query'),
            history: any(named: 'history'),
            petId: any(named: 'petId'),
            petProfileContext: any(named: 'petProfileContext'),
          )).thenAnswer((_) async => 'answer');

      final result = await repo.askAnswer(query: 'q', petId: 'pet-1');

      expect(result, 'answer');
    });

    test('propagates thrown exceptions', () async {
      when(() => ai.ask(
            query: any(named: 'query'),
            history: any(named: 'history'),
            petId: any(named: 'petId'),
            petProfileContext: any(named: 'petProfileContext'),
          )).thenThrow(Exception('ask fail'));

      await expectLater(
        repo.askAnswer(query: 'q', petId: 'pet-1'),
        throwsException,
      );
    });
  });
}
