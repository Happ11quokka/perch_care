import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/notification.dart';
import '../../providers/repository_providers.dart';
import '../../repositories/notification_repository.dart';

/// 알림 화면(notification_screen.dart)용 ViewModel.
///
/// build()에서 초기 목록을 `repo.fetch()`로 가져오고, 동시에 `repo.subscribe()`
/// (폴링 스트림)를 구독해 이후 값 변경을 state에 그대로 반영한다. 구독은
/// `ref.onDispose`로 해제한다.
///
/// **폴링 실패 시 목록 유지 (F14):**
/// `NotificationService.subscribeToNotifications()`는 폴링 실패 시 아무것도
/// yield하지 않는다(빈 리스트를 흘리지 않음). 방어적으로 스트림 에러가 오더라도
/// `AsyncError.copyWithPrevious`로 마지막 목록을 유지한다 — 화면은
/// `valueOrNull`로 목록을 그리므로 일시적 네트워크 에러에 목록이 비워지지 않는다.
class NotificationViewModel extends AsyncNotifier<List<AppNotification>> {
  NotificationRepository get _repo => ref.read(notificationRepositoryProvider);

  @override
  Future<List<AppNotification>> build() async {
    final repo = _repo;

    // 구독은 build() 동기 구간에서 등록하되, 콜백에서의 state 대입은 build()의
    // 반환 Future가 완료된 "이후"에만 일어난다(폴링 간격이 최소 30초이므로 실제
    // 런타임에서는 항상 그렇다). onDispose로 재빌드/폐기 시 해제한다.
    final sub = repo.subscribe().listen(
      (list) {
        state = AsyncData(list);
      },
      onError: (Object error, StackTrace stackTrace) {
        // 이전 목록을 유지한 채 에러만 표시(View는 스낵바 1회, 목록은 그대로).
        state = AsyncError<List<AppNotification>>(error, stackTrace)
            .copyWithPrevious(state);
      },
    );
    ref.onDispose(sub.cancel);

    return repo.fetch();
  }

  /// 실패 시 롤백 대신 서버 최신 상태로 재조회.
  ///
  /// 재조회 자체도 실패하면(예: 네트워크 단절) 호출자에게 throw하지 않고
  /// 낙관적 갱신 이전 스냅샷(`fallback`)으로 되돌린다 — 화면 콜백이
  /// 2차 예외로 죽거나 목록이 비워지지 않게 한다.
  Future<void> _refetch(List<AppNotification> fallback) async {
    try {
      state = AsyncData(await _repo.fetch());
    } catch (_) {
      state = AsyncData(fallback);
    }
  }

  /// 낙관적 읽음 처리 — 실패 시 재조회.
  Future<void> markAsRead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final n in current)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ]);
    try {
      await _repo.markAsRead(id);
    } catch (_) {
      await _refetch(current);
    }
  }

  /// 낙관적 전체 읽음 처리 — 실패 시 재조회 후 rethrow(View 스낵바).
  ///
  /// 기존 화면은 `markAllAsRead()` 서버 호출 실패 시 스낵바를 띄웠다(재조회는
  /// 하지 않았음). 낙관적 갱신 구조로 전환하면서 실패 시 서버 최신 상태로
  /// 재조회하되, 에러는 rethrow해 View가 동일하게 스낵바를 띄울 수 있게 한다
  /// (WeightDetailViewModel.deleteSchedule과 동일한 컨벤션).
  Future<void> markAllAsRead() async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final n in current) n.copyWith(isRead: true),
    ]);
    try {
      await _repo.markAllAsRead();
    } catch (e) {
      await _refetch(current);
      rethrow;
    }
  }

  /// 낙관적 삭제 — 실패 시 재조회 후 rethrow(View 스낵바).
  ///
  /// 기존 화면은 `deleteNotification()` 실패 시 스낵바를 띄웠다(로컬 상태는
  /// 되돌리지 않았음, 즉 서버가 실패했으므로 목록엔 그대로 남아 있었음). 낙관적
  /// 갱신 구조로 전환하면서 실패 시 서버 최신 상태로 재조회(사실상 롤백)하되,
  /// 에러는 rethrow해 View가 동일하게 스낵바를 띄울 수 있게 한다.
  Future<void> delete(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData(current.where((n) => n.id != id).toList());
    try {
      await _repo.delete(id);
    } catch (e) {
      await _refetch(current);
      rethrow;
    }
  }
}

final notificationViewModelProvider =
    AsyncNotifierProvider<NotificationViewModel, List<AppNotification>>(
        NotificationViewModel.new);
