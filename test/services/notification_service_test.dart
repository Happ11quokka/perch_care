import 'package:flutter_test/flutter_test.dart';

import 'package:perch_care/src/models/notification.dart';
import 'package:perch_care/src/services/notification/notification_service.dart';

AppNotification _notif(String id, {bool isRead = false}) => AppNotification(
      id: id,
      userId: 'u1',
      type: NotificationType.system,
      title: 'title-$id',
      message: 'message-$id',
      timestamp: DateTime(2026, 1, 1),
      isRead: isRead,
    );

/// 폴링 루프의 `delay`를 가로채 요청된 간격을 기록하고 즉시 진행시킨다.
class _FakeClock {
  final intervals = <Duration>[];
  Future<void> delay(Duration d) async {
    intervals.add(d);
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('NotificationService.poll (F14)', () {
    test('fetch failure yields nothing; previous list is not replaced by []',
        () async {
      final clock = _FakeClock();
      var call = 0;
      final results = [
        [_notif('n1')],
        null, // 실패
        null, // 실패
        [_notif('n1'), _notif('n2')],
      ];
      Future<List<AppNotification>> fetch() async {
        final r = results[call++];
        if (r == null) throw Exception('network');
        return r;
      }

      final emitted = await NotificationService.poll(fetch, delay: clock.delay)
          .take(2)
          .toList();

      expect(emitted.map((l) => l.length), [1, 2]);
      expect(emitted.any((l) => l.isEmpty), isFalse);
      expect(call, 4, reason: '실패 2회는 emit 없이 건너뛰고 계속 폴링');
    });

    test('failure doubles the interval (capped at 120s); success with unread '
        'resets to 30s', () async {
      final clock = _FakeClock();
      var call = 0;
      Future<List<AppNotification>> fetch() async {
        call++;
        // 1~3회 실패, 4회 성공(미읽음 있음), 5회 성공
        if (call <= 3) throw Exception('network');
        return [_notif('n1')];
      }

      await NotificationService.poll(fetch, delay: clock.delay)
          .take(2)
          .toList();

      expect(
        clock.intervals.map((d) => d.inSeconds).toList(),
        [30, 60, 120, 120, 30],
      );
    });

    test('all-read success grows interval by 1.5x up to 120s', () async {
      final clock = _FakeClock();
      Future<List<AppNotification>> fetch() async =>
          [_notif('n1', isRead: true)];

      await NotificationService.poll(fetch, delay: clock.delay)
          .take(5)
          .toList();

      expect(
        clock.intervals.map((d) => d.inSeconds).toList(),
        [30, 45, 67, 100, 120],
      );
    });
  });
}
