import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:perch_care/src/models/notification.dart';
import 'package:perch_care/src/repositories/notification_repository.dart';
import 'package:perch_care/src/services/notification/notification_service.dart';

class MockNotificationService extends Mock implements NotificationService {}

AppNotification _notification({String id = 'n1', bool isRead = false}) =>
    AppNotification(
      id: id,
      userId: 'u1',
      type: NotificationType.reminder,
      title: 'title',
      message: 'message',
      timestamp: DateTime(2026, 4, 18, 9),
      isRead: isRead,
    );

void main() {
  late MockNotificationService service;
  late NotificationRepository repo;

  setUp(() {
    service = MockNotificationService();
    repo = NotificationRepositoryImpl(service: service);
  });

  test('fetch delegates to service with limit/unreadOnly', () async {
    when(() => service.fetchNotifications(
          limit: any(named: 'limit'),
          unreadOnly: any(named: 'unreadOnly'),
        )).thenAnswer((_) async => [_notification()]);

    final result = await repo.fetch(limit: 10, unreadOnly: true);

    expect(result, hasLength(1));
    verify(() => service.fetchNotifications(limit: 10, unreadOnly: true))
        .called(1);
  });

  test('markAsRead delegates to service', () async {
    when(() => service.markAsRead(any())).thenAnswer((_) async {});

    await repo.markAsRead('n1');

    verify(() => service.markAsRead('n1')).called(1);
  });

  test('markAllAsRead delegates to service', () async {
    when(() => service.markAllAsRead()).thenAnswer((_) async {});

    await repo.markAllAsRead();

    verify(() => service.markAllAsRead()).called(1);
  });

  test('delete delegates to service deleteNotification', () async {
    when(() => service.deleteNotification(any())).thenAnswer((_) async {});

    await repo.delete('n1');

    verify(() => service.deleteNotification('n1')).called(1);
  });

  test('subscribe returns the service stream', () async {
    final controller = Stream<List<AppNotification>>.value([_notification()]);
    when(() => service.subscribeToNotifications())
        .thenAnswer((_) => controller);

    final result = await repo.subscribe().first;

    expect(result, hasLength(1));
    verify(() => service.subscribeToNotifications()).called(1);
  });

  test('fetch propagates service error', () async {
    when(() => service.fetchNotifications(
          limit: any(named: 'limit'),
          unreadOnly: any(named: 'unreadOnly'),
        )).thenThrow(Exception('500'));

    await expectLater(repo.fetch(), throwsA(isA<Exception>()));
  });
}
