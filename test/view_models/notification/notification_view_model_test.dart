import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/notification.dart';
import 'package:perch_care/src/providers/repository_providers.dart';
import 'package:perch_care/src/repositories/notification_repository.dart';
import 'package:perch_care/src/view_models/notification/notification_view_model.dart';

class MockNotificationRepository extends Mock implements NotificationRepository {}

AppNotification _notif(String id, {bool isRead = false}) => AppNotification(
      id: id,
      userId: 'u1',
      type: NotificationType.system,
      title: 'title-$id',
      message: 'message-$id',
      timestamp: DateTime(2026, 1, 1),
      isRead: isRead,
    );

ProviderContainer _container(NotificationRepository repo) {
  final container = ProviderContainer(overrides: [
    notificationRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// 대기 중인 마이크로태스크/타이머(스트림 emit 등)를 흘려보낸다.
Future<void> _flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late MockNotificationRepository repo;

  setUp(() {
    repo = MockNotificationRepository();
  });

  test('build fetches initial list from repository', () async {
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
    when(() => repo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());

    final container = _container(repo);
    final state = await container.read(notificationViewModelProvider.future);

    expect(state, hasLength(2));
    verify(() => repo.fetch()).called(1);
  });

  test('markAsRead optimistically marks item read then persists', () async {
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
    when(() => repo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => repo.markAsRead('n1')).thenAnswer((_) async {});

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);
    final vm = container.read(notificationViewModelProvider.notifier);

    await vm.markAsRead('n1');

    final state = container.read(notificationViewModelProvider).value!;
    expect(state.firstWhere((n) => n.id == 'n1').isRead, isTrue);
    verify(() => repo.markAsRead('n1')).called(1);
  });

  test('markAsRead re-fetches on repository failure', () async {
    when(() => repo.fetch()).thenAnswer((_) async => [_notif('n1')]);
    when(() => repo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => repo.markAsRead('n1')).thenThrow(Exception('network'));

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);
    final vm = container.read(notificationViewModelProvider.notifier);

    // 재조회가 실제로 일어났음을 증명하기 위해 실패 이후 fetch 응답을 바꿔둔다.
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n3')]);

    await vm.markAsRead('n1');

    verify(() => repo.fetch()).called(2); // build 1회 + 실패 후 재조회 1회
    final state = container.read(notificationViewModelProvider).value!;
    expect(state.map((n) => n.id), containsAll(['n1', 'n3']));
  });

  test('markAllAsRead optimistically marks all read then persists', () async {
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
    when(() => repo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => repo.markAllAsRead()).thenAnswer((_) async {});

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);
    final vm = container.read(notificationViewModelProvider.notifier);

    await vm.markAllAsRead();

    final state = container.read(notificationViewModelProvider).value!;
    expect(state.every((n) => n.isRead), isTrue);
    verify(() => repo.markAllAsRead()).called(1);
  });

  test('markAllAsRead re-fetches and rethrows on repository failure '
      '(View shows error snackbar, matching legacy behavior)', () async {
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
    when(() => repo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => repo.markAllAsRead()).thenThrow(Exception('network'));

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);
    final vm = container.read(notificationViewModelProvider.notifier);

    await expectLater(vm.markAllAsRead(), throwsA(isA<Exception>()));

    verify(() => repo.fetch()).called(2); // build + failure re-fetch
    final state = container.read(notificationViewModelProvider).value!;
    // re-fetch restores server-truth (unread) state.
    expect(state.every((n) => !n.isRead), isTrue);
  });

  test('delete removes item from state then persists', () async {
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
    when(() => repo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => repo.delete('n1')).thenAnswer((_) async {});

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);
    final vm = container.read(notificationViewModelProvider.notifier);

    await vm.delete('n1');

    final state = container.read(notificationViewModelProvider).value!;
    expect(state.map((n) => n.id), ['n2']);
    verify(() => repo.delete('n1')).called(1);
  });

  test('delete re-fetches and rethrows on repository failure '
      '(View shows error snackbar, matching legacy behavior)', () async {
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
    when(() => repo.subscribe())
        .thenAnswer((_) => const Stream<List<AppNotification>>.empty());
    when(() => repo.delete('n1')).thenThrow(Exception('network'));

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);
    final vm = container.read(notificationViewModelProvider.notifier);

    await expectLater(vm.delete('n1'), throwsA(isA<Exception>()));

    verify(() => repo.fetch()).called(2); // build + failure re-fetch
    final state = container.read(notificationViewModelProvider).value!;
    // re-fetch restores server-truth (delete failed, so it's still present).
    expect(state.map((n) => n.id), containsAll(['n1', 'n2']));
  });

  // 실제 NotificationService.subscribeToNotifications()는 최소 30초 폴링 간격을
  // 가지므로 첫 emit은 항상 build()의 초기 fetch가 끝난 "이후"에 도착한다. 여기서도
  // StreamController를 써서 build 완료 이후에만 emit함으로써 그 계약을 재현한다.
  // (Stream.value처럼 구독 즉시 emit하는 스트림을 쓰면 emit이 build()의 반환
  // Future 완료보다 먼저 도착할 수 있어, Riverpod의 handleFuture가 build 완료 시
  // state를 초기 fetch 값으로 덮어써 버리는 - 즉 emit이 아예 무시되는 - 순수 테스트
  // 아티팩트성 레이스가 발생한다. 실서비스 폴링 간격에서는 재현되지 않는 레이스다.)
  test('subscribe stream emissions after initial build are reflected into state',
      () async {
    final controller = StreamController<List<AppNotification>>();
    when(() => repo.fetch()).thenAnswer((_) async => [_notif('n1')]);
    when(() => repo.subscribe()).thenAnswer((_) => controller.stream);

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);

    controller.add([_notif('n1'), _notif('n2')]);
    await _flush();

    final state = container.read(notificationViewModelProvider).value!;
    expect(state, hasLength(2));

    await controller.close();
  });

  test(
      'subscribe stream emitting empty list after initial build clears state '
      '(documents pre-existing NotificationService error-yields-empty behavior, preserved as-is)',
      () async {
    final controller = StreamController<List<AppNotification>>();
    when(() => repo.fetch())
        .thenAnswer((_) async => [_notif('n1'), _notif('n2')]);
    when(() => repo.subscribe()).thenAnswer((_) => controller.stream);

    final container = _container(repo);
    await container.read(notificationViewModelProvider.future);

    controller.add(<AppNotification>[]);
    await _flush();

    final state = container.read(notificationViewModelProvider).value!;
    expect(state, isEmpty);

    await controller.close();
  });
}
