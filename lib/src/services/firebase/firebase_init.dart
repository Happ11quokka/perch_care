import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../../firebase_options.dart';

/// Firebase 초기화를 수행하고 그 성공 여부를 앱 전역에 노출한다.
///
/// 초기화 실패는 **치명적 오류로 다루지 않는다.** 자격 파일 누락, 지원하지
/// 않는 플랫폼(web·macOS·Windows·Linux는 `DefaultFirebaseOptions`에서
/// `UnsupportedError`), 플러그인·네트워크 오류 중 어느 경우든 분석·푸시만
/// 비활성화하고 기록·AI 등 본 기능은 계속 동작해야 한다.
///
/// Firebase에 의존하는 코드는 `FirebaseMessaging.instance` 같은 접근 전에
/// [isAvailable]을 확인한다. 초기화되지 않은 상태에서 `.instance`에 접근하면
/// 예외가 발생하므로, 해당 필드는 생성자에서 미리 만들지 않고 지연 조회한다.
class FirebaseInit {
  FirebaseInit._();

  static bool _isAvailable = false;

  /// Firebase 앱이 초기화되어 분석·푸시를 사용할 수 있는지 여부.
  static bool get isAvailable => _isAvailable;

  /// 초기화를 시도한다. 실패해도 예외를 전파하지 않는다.
  static Future<void> ensureInitialized() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _isAvailable = true;
    } catch (e) {
      _isAvailable = false;
      debugPrint('[main] Firebase 초기화 실패 — 분석·푸시 비활성화: $e');
    }
  }

  @visibleForTesting
  static void setAvailableForTest({required bool value}) {
    _isAvailable = value;
  }
}
