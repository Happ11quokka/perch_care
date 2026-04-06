# M-7: FCM 포그라운드 핸들러 — 의도적 미구현 결정

> 결정일: 2026-03-21

## 배경

코드 리뷰(2026-03-20)에서 `push_notification_service.dart:90-94`의 포그라운드 메시지 핸들러가 빈 상태임을 발견.

```dart
void _handleForegroundMessage(RemoteMessage message) {
  if (kDebugMode) debugPrint('[Push] Foreground message: ${message.notification?.title}');
  // 인앱 알림은 기존 NotificationService polling으로 처리되므로
  // 여기서는 별도 UI 표시 불필요
}
```

## 현재 구조

앱이 포그라운드에 있을 때 알림 수신 경로:

```
서버 이벤트 발생
  ├─ FCM push → _handleForegroundMessage() → 로그만 출력 (UI 미표시)
  └─ NotificationService polling → 서버 API 조회 → 앱 내 알림 목록 갱신
```

## 미구현 결정 이유

1. **중복 방지**: NotificationService가 이미 polling으로 새 알림을 가져와 화면에 표시. FCM 포그라운드 팝업을 추가하면 같은 알림이 두 번 표시될 수 있음.

2. **UX 일관성**: 앱이 열려있을 때는 앱 내 UI(알림 화면)에서 확인하는 것이 자연스러움. 시스템 알림 배너가 앱 위에 뜨면 오히려 방해.

3. **구현 비용 대비 효과**: `flutter_local_notifications` 추가 의존성 + 채널 설정 + 중복 제거 로직 필요. 현재 polling 방식으로 충분히 작동 중.

## FCM 포그라운드 vs Polling 비교

| 항목 | FCM 포그라운드 알림 | Polling (현재) |
|------|-------------------|---------------|
| 즉시성 | 실시간 (서버 push 즉시) | 폴링 주기만큼 지연 |
| 시스템 알림 | 상단 배너/소리/진동 가능 | 앱 내 UI만 |
| 사용자 인지 | 바로 인지 | 화면 확인 시 인지 |
| 중복 위험 | 있음 (polling과 이중 표시) | 없음 |
| 추가 의존성 | flutter_local_notifications | 없음 |

## 결론

현재 앱 규모와 사용 패턴에서 polling 방식이 충분. FCM 포그라운드 핸들러는 의도적으로 빈 상태를 유지.

향후 실시간성이 중요한 기능(채팅 알림 등)이 추가되면 재검토.
