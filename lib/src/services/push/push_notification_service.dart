import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../api/api_client.dart';
import '../../providers/locale_provider.dart';

/// FCM 푸시 알림 서비스
class PushNotificationService {
  static PushNotificationService? _instance;
  static PushNotificationService get instance =>
      _instance ??= PushNotificationService._();

  PushNotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _api = ApiClient.instance;

  // 스트림 구독 관리
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _messageOpenedAppSub;

  /// 초기화: 권한 요청 + 토큰 등록 + 리스너 설정
  Future<void> initialize() async {
    // 1. 알림 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[Push] Notification permission denied');
      return;
    }

    // 2. FCM 토큰 발급 & 서버 전송
    final token = await _messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // 3. 토큰 갱신 리스너
    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_registerToken);

    // 4. 포그라운드 메시지 핸들링
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 5. 백그라운드에서 알림 탭 시
    _messageOpenedAppSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    debugPrint('[Push] PushNotificationService initialized');
  }

  /// 스트림 구독 해제
  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    await _messageOpenedAppSub?.cancel();
  }

  /// 서버에 FCM 토큰 등록
  Future<void> _registerToken(String token) async {
    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final lang = LocaleProvider.instance.currentLanguageCode
          ?? WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      // Normalize to supported languages
      final language = const ['ko', 'en', 'zh'].contains(lang) ? lang : 'zh';
      await _api.post('/users/me/device-token', body: {
        'token': token,
        'platform': platform,
        'language': language,
      });
      debugPrint('[Push] Token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[Push] Failed to register token: $e');
    }
  }

  /// 포그라운드 메시지 수신
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[Push] Foreground message: ${message.notification?.title}');
    // 인앱 알림은 기존 NotificationService polling으로 처리되므로
    // 여기서는 별도 UI 표시 불필요
  }

  /// 백그라운드에서 알림 탭으로 앱 열기
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('[Push] Opened from notification: ${message.data}');
    // 필요 시 특정 화면으로 네비게이션
  }
}

/// 백그라운드 메시지 핸들러 (top-level function 필수)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[Push] Background message: ${message.messageId}');
}
