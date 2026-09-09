// F04(AI) 회귀 테스트 — 유지되는 탭인 AI 백과사전 화면은 활성 펫이 바뀌면 새 펫의
// 대화를 다시 로드하고, 이전 펫으로 시작한 비동기 결과는 버려야 한다.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:perch_care/l10n/app_localizations.dart';
import 'package:perch_care/src/models/chat_message.dart';
import 'package:perch_care/src/models/pet.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/providers/service_providers.dart';
import 'package:perch_care/src/repositories/chat_repository.dart';
import 'package:perch_care/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart';
import 'package:perch_care/src/services/storage/local_image_storage_service.dart';
import 'package:perch_care/src/view_models/pet/active_pet_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ChatMock extends Mock implements ChatRepository {}

class _ImageMock extends Mock implements LocalImageStorageService {}

Pet _pet(String id) => Pet(
      id: id,
      userId: 'test-user',
      name: 'Bird $id',
      species: 'bird',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

/// 초기값을 동기로 주고, 테스트가 [setPet]으로 활성 펫을 바꿀 수 있는 픽스처.
class _ActiveFixture extends ActivePetViewModel {
  _ActiveFixture(this.initial);
  final Pet? initial;

  @override
  Future<Pet?> build() => SynchronousFuture(initial);

  void setPet(Pet? value) => state = AsyncData(value);
}

Pet? _defaultPet() => _pet('a');

ChatMessage _userMessage(String text) => ChatMessage(
      role: MessageRole.user,
      text: text,
      timestamp: DateTime(2026),
    );

class _Harness {
  _Harness({Pet? Function() initialPet = _defaultPet}) {
    when(
      () => images.getImage(
        ownerType: any(named: 'ownerType'),
        ownerId: any(named: 'ownerId'),
      ),
    ).thenAnswer((_) async => null);
    when(() => chat.loadConversation(any()))
        .thenAnswer((_) async => const ConversationLoad(messages: []));
    when(() => chat.saveLocal(any(), any())).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        chatRepositoryProvider.overrideWithValue(chat),
        localImageStorageServiceProvider.overrideWithValue(images),
        activePetViewModelProvider.overrideWith(
          () => _ActiveFixture(initialPet()),
        ),
      ],
    );
  }

  final chat = _ChatMock();
  final images = _ImageMock();
  late final ProviderContainer container;

  _ActiveFixture get active =>
      container.read(activePetViewModelProvider.notifier) as _ActiveFixture;

  Widget get app => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en'), Locale('zh')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AIEncyclopediaScreen(),
        ),
      );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(<ChatMessage>[]);
  });

  setUp(() {
    // 코치마크는 이미 본 상태로 두어 대화 로드 동작만 검증한다.
    SharedPreferences.setMockInitialValues({'coach_mark_seen_chatbot': true});
  });

  testWidgets('reloads the conversation when the active pet changes', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);
    verify(() => h.chat.loadConversation('a')).called(1);

    h.active.setPet(_pet('b'));
    await _settle(tester);

    verify(() => h.chat.loadConversation('b')).called(1);
    verifyNever(() => h.chat.loadConversation('a'));
    await h.dispose(tester);
  });

  testWidgets('does not reload when the same pet is re-emitted', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.app);
    await _settle(tester);
    verify(() => h.chat.loadConversation('a')).called(1);

    h.active.setPet(_pet('a'));
    await _settle(tester);

    verifyNever(() => h.chat.loadConversation(any()));
    await h.dispose(tester);
  });

  testWidgets('loads the pet conversation once initial provider loading finishes', (
    tester,
  ) async {
    final h = _Harness(initialPet: () => null);
    await tester.pumpWidget(h.app);
    await _settle(tester);
    verify(() => h.chat.loadConversation(null)).called(1);

    h.active.setPet(_pet('a'));
    await _settle(tester);

    verify(() => h.chat.loadConversation('a')).called(1);
    await h.dispose(tester);
  });

  testWidgets('discards an in-flight load for the previous pet', (
    tester,
  ) async {
    final h = _Harness();
    final pendingA = Completer<ConversationLoad>();
    when(() => h.chat.loadConversation('a')).thenAnswer((_) => pendingA.future);
    when(() => h.chat.loadConversation('b')).thenAnswer(
      (_) async => ConversationLoad(messages: [_userMessage('hello from b')]),
    );

    await tester.pumpWidget(h.app);
    await _settle(tester);

    h.active.setPet(_pet('b'));
    await _settle(tester);
    expect(find.text('hello from b'), findsOneWidget);

    // 이전 펫의 늦은 응답은 화면에 반영되면 안 된다.
    pendingA.complete(
      ConversationLoad(messages: [_userMessage('stale from a')]),
    );
    await _settle(tester);

    expect(find.text('stale from a'), findsNothing);
    expect(find.text('hello from b'), findsOneWidget);
    await h.dispose(tester);
  });
}
