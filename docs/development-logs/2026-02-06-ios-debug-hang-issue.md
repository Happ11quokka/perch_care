# iOS 실제 기기 디버그 모드에서 앱 재시작 시 Hang 발생

**날짜**: 2026-02-06
**관련 파일**:
- [lib/src/services/api/token_service.dart](../../lib/src/services/api/token_service.dart)
- [lib/src/screens/splash/splash_screen.dart](../../lib/src/screens/splash/splash_screen.dart)
- [lib/main.dart](../../lib/main.dart)

## 증상

iOS 실제 기기에서 디버그 모드로 앱 실행 시:
1. **첫 실행**: 정상 작동
2. **앱 슬라이드 종료 후 재실행**: 앱이 열리지 않고 hang 발생

Xcode 콘솔 로그:
```
App is being debugged, do not track this hang
Hang detected: 2.46s (debugger attached, not reporting)
```

모든 초기화 로그는 정상 출력됨:
```
flutter: [Splash] 1. dotenv loaded
flutter: [Splash] 2. KakaoSdk initialized
flutter: [Splash] 3. TokenService initialized
flutter: [Splash] 4. ApiClient initialized
flutter: [Splash] 5. GoogleSignIn initialized
flutter: [Splash] 6. LocalImageStorageService initialized
flutter: [Splash] All services initialized, navigating...
flutter: [HomeScreen] initState called
flutter: [HomeScreen] getActivePet() returned: 사랑이
Hang detected: 2.46s (debugger attached, not reporting)
```

## 원인

**Flutter/iOS LLDB 디버거 호환성 이슈** ([GitHub Flutter #179496](https://github.com/flutter/flutter/issues/179496))

| 환경 | 결과 |
|------|------|
| 시뮬레이터 + 디버그 | ✅ 정상 |
| 실제 기기 + 디버그 | ❌ Hang 발생 |
| 실제 기기 + 릴리즈 | ✅ 정상 |

LLDB 디버거가 실제 iOS 기기에 연결된 상태에서 앱을 종료 후 재시작하면, 디버거와 Flutter 엔진 간의 **동기화 문제**로 hang이 발생한다.

GitHub 이슈에서 보고된 특징:
- LLDB 디버깅을 비활성화하면 hang이 발생하지 않음
- 앱을 완전히 삭제 후 재설치하면 정상 작동
- iOS 버전 및 기기별로 발생 빈도가 다름

## 영향 범위

| 배포 환경 | 영향 |
|----------|------|
| App Store 배포 | **영향 없음** (릴리즈 빌드) |
| TestFlight | **영향 없음** |
| 개발 중 디버그 테스트 | 불편함 발생 |

**결론**: 실제 사용자에게 배포되는 앱에는 영향 없음. 개발 중 테스트 시에만 불편함 발생.

## 임시 해결 방법

### 1. 릴리즈 모드로 테스트

```bash
flutter run --release -d <device_id>
```

### 2. Xcode에서 Debug executable 비활성화

1. `Product` → `Scheme` → `Edit Scheme...`
2. 왼쪽에서 `Run` 선택
3. `Build Configuration`을 `Release`로 변경
4. **`Debug executable` 체크 해제** (핵심)

### 3. 앱 삭제 후 재설치

디버그 모드에서 테스트 시 매번 앱을 삭제하고 재설치.

## 조사 과정에서 적용한 개선 사항

문제 조사 중 발견된 잠재적 이슈들을 함께 수정함:

### 1. TokenService Keychain 접근성 개선

```dart
// 수정 전
final _secureStorage = const FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  ),
);

// 수정 후
final _secureStorage = const FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);
```

- `first_unlock_this_device`: 기기에 바인딩되어 더 안정적
- 토큰은 iCloud 동기화할 필요 없으므로 적합

### 2. TokenService 초기화 재시도 로직 추가

```dart
Future<void> init() async {
  if (_initialized) return;

  const maxRetries = 3;
  for (var i = 0; i < maxRetries; i++) {
    try {
      _accessToken = await _secureStorage.read(key: _accessTokenKey);
      _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
      _initialized = true;
      return;
    } catch (e) {
      if (i < maxRetries - 1) {
        await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
      }
    }
  }
  _initialized = true;
}
```

### 3. SplashScreen lifecycle 관리 개선

```dart
bool _disposed = false;

void _onAnimationStatus(AnimationStatus status) {
  if (status == AnimationStatus.completed) {
    _animationCompleted = true;
    _tryNavigate();
  }
}

@override
void dispose() {
  _disposed = true;
  _controller.removeStatusListener(_onAnimationStatus);
  _controller.dispose();
  super.dispose();
}

void _tryNavigate() {
  if (_animationCompleted && _servicesInitialized && mounted && !_disposed) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && !_disposed) {
        _navigateToInitialRoute();
      }
    });
  }
}
```

- `_disposed` 플래그 추가
- AnimationController status listener 명시적 제거
- `mounted && !_disposed` 이중 체크

### 4. main.dart 초기화 안정화

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS에서 앱 재시작 시 초기화 문제 방지
  await Future.delayed(const Duration(milliseconds: 50));

  runApp(const MyApp());
}
```

## 관련 리소스

- [Flutter GitHub Issue #179496](https://github.com/flutter/flutter/issues/179496) - iOS 26 flutter run hangs
- [Flutter GitHub Issue #161466](https://github.com/flutter/flutter/issues/161466) - Hot restart issues (Fixed)
- [flutter_secure_storage Issue #794](https://github.com/juliansteenbakker/flutter_secure_storage/issues/794) - iOS 18 crash

## 핵심 교훈

- iOS 실제 기기에서 **디버그 모드 hang은 Flutter/LLDB 호환성 이슈**일 수 있음
- 시뮬레이터에서는 정상인데 실제 기기에서만 문제 발생 시, **릴리즈 모드 테스트** 먼저 시도
- `Hang detected` 메시지가 나오면 **디버거 연결 문제**를 의심
- 앱스토어 배포에는 영향이 없으므로, 개발 중에는 임시 해결책 사용
