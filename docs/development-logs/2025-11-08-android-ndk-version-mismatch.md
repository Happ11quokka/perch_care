# Android NDK 버전 불일치 오류 해결

**날짜**: 2025-11-08
**파일**:
- [android/app/build.gradle.kts](../../android/app/build.gradle.kts)

---

## 문제 정의

### 1. 오류 메시지

Flutter 프로젝트를 실행할 때 다음과 같은 경고 메시지가 발생:

```
Your project is configured with Android NDK 26.3.11579264, but the following plugin(s) depend on a different Android NDK version:
- app_links requires Android NDK 27.0.12077973
- path_provider_android requires Android NDK 27.0.12077973
- shared_preferences_android requires Android NDK 27.0.12077973
- url_launcher_android requires Android NDK 27.0.12077973

Fix this issue by using the highest Android NDK version (they are backward compatible).
Add the following to /Users/imdonghyeon/perch_care/android/app/build.gradle.kts:

    android {
        ndkVersion = "27.0.12077973"
        ...
    }
```

### 2. 근본 원인

**Flutter 3.29.0의 NDK 버전 정책 변경**:

1. **프로젝트 생성 시 기본 NDK**: 26.3.11579264
2. **최신 플러그인 요구 NDK**: 27.0.12077973
3. **불일치 발생**: 새 프로젝트도 구버전 NDK로 생성되는 문제

**발생 배경**:
- Flutter 3.29 이상에서 Android NDK 27을 최소 지원 버전으로 요구
- 그러나 `flutter create` 명령으로 생성된 프로젝트는 여전히 NDK 26 사용
- 대부분의 공식/서드파티 플러그인이 NDK 27로 업데이트됨
- 결과적으로 신규 프로젝트에서도 버전 불일치 경고 발생

**참고 이슈**:
- [Flutter GitHub Issue #163945](https://github.com/flutter/flutter/issues/163945)
- [Flutter GitHub Issue #139427](https://github.com/flutter/flutter/issues/139427)

### 3. 영향 범위

- **빌드 실패**: 일부 경우 컴파일 오류 발생 가능
- **경고 메시지**: 대부분은 경고만 표시되지만 혼란 야기
- **향후 호환성**: 새 플러그인 추가 시 계속 문제 발생

---

## 문제 해결

### 방법 1: NDK 버전 명시적 지정 (권장)

**android/app/build.gradle.kts** 파일 수정:

```kotlin
android {
    namespace = "com.perch.perch_care"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"  // ← 이 줄 수정

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    // ...
}
```

**변경 전**:
```kotlin
ndkVersion = flutter.ndkVersion  // 기본값 (26.3.11579264)
```

**변경 후**:
```kotlin
ndkVersion = "27.0.12077973"  // 명시적 최신 버전 지정
```

### 방법 2: Android Studio에서 NDK 설치 확인

1. **Android Studio 열기**
2. **Tools → SDK Manager**
3. **SDK Tools 탭**
4. **"Show Package Details" 체크**
5. **NDK (Side by side)** 항목에서 `27.0.12077973` 설치 확인
6. 미설치 시 체크박스 선택 후 Apply

### 방법 3: Flutter 전역 NDK 버전 변경 (고급)

**flutter.groovy 파일 수정** (권장하지 않음):

위치: `$FLUTTER_HOME/packages/flutter_tools/gradle/src/main/groovy/flutter.groovy`

```groovy
class FlutterExtension {
    String ndkVersion = "27.0.12077973"  // 기본값 변경
    // ...
}
```

⚠️ **주의**: Flutter 업데이트 시 초기화되므로 비권장

---

## 해결 확인

### 1. 빌드 재실행

```bash
flutter clean
flutter pub get
flutter run
```

### 2. 경고 메시지 사라짐 확인

이전:
```
Your project is configured with Android NDK 26.3.11579264...
```

이후:
```
Running Gradle task 'assembleDebug'...
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

### 3. 정상 빌드 확인

```bash
flutter analyze
# No issues found!
```

---

## 주의점

### 1. **NDK 버전 호환성**

✅ **후방 호환성 보장**:
- Android NDK는 **후방 호환** (Backward Compatible)
- 높은 버전 NDK가 낮은 버전 요구사항을 모두 충족
- **항상 가장 높은 NDK 버전 사용 권장**

**예시**:
```
NDK 27.0.12077973 사용 시
→ NDK 26 요구 플러그인 ✅ 작동
→ NDK 27 요구 플러그인 ✅ 작동
```

### 2. **빌드 캐시 초기화 필요**

NDK 버전 변경 후 반드시 클린 빌드:

```bash
flutter clean
cd android && ./gradlew clean && cd ..
flutter pub get
flutter run
```

**이유**:
- Gradle 캐시에 이전 NDK 버전 정보 남아있음
- `flutter clean`으로 `build/` 디렉토리 삭제 필요

### 3. **프로젝트별 독립 설정**

각 프로젝트마다 `build.gradle.kts`에서 개별 설정:

```
Project A → NDK 27.0.12077973
Project B → NDK 26.3.11579264
Project C → NDK 27.0.12077973
```

- 프로젝트별로 다른 NDK 버전 사용 가능
- 하나의 변경이 다른 프로젝트에 영향 없음

### 4. **Flutter 버전별 권장 NDK**

| Flutter 버전 | 권장 NDK 버전 | 비고 |
|-------------|-------------|------|
| 3.27.x | 26.3.11579264 | 기본값 |
| 3.29.x | **27.0.12077973** | 최소 요구 |
| 3.30.x 이상 | **27.0.12077973+** | 최신 버전 |

⚠️ **Flutter 3.29 이상에서는 NDK 27 필수**

### 5. **CI/CD 환경 설정**

GitHub Actions, Jenkins 등에서도 NDK 버전 지정:

```yaml
# .github/workflows/build.yml
- name: Setup Android SDK
  uses: android-actions/setup-android@v2
  with:
    ndk-version: '27.0.12077973'
```

### 6. **플러그인 추가 시 확인 사항**

새 플러그인 설치 후:

```bash
flutter pub add [package_name]
flutter run
```

NDK 버전 경고 재발생 시:
1. 플러그인이 요구하는 NDK 버전 확인
2. `build.gradle.kts`의 `ndkVersion`을 더 높은 버전으로 업데이트

### 7. **멀티 모듈 프로젝트**

Flutter 모듈을 Android 앱에 통합 시:

**호스트 Android 앱의 build.gradle**:
```kotlin
android {
    ndkVersion = "27.0.12077973"  // Flutter 모듈과 동일하게
}
```

- Flutter 모듈과 호스트 앱의 NDK 버전 일치 필수

### 8. **문법 주의사항**

**올바른 문법**:
```kotlin
ndkVersion = "27.0.12077973"  // ✅ 등호 사용
```

**잘못된 문법**:
```kotlin
ndkVersion "27.0.12077973"  // ❌ Groovy 스타일 (build.gradle)
```

- **build.gradle.kts** (Kotlin DSL): `=` 필수
- **build.gradle** (Groovy): `=` 생략 가능

---

## 베스트 프랙티스

### 1. **신규 프로젝트 생성 시**

```bash
flutter create my_app
cd my_app
```

즉시 `android/app/build.gradle.kts` 수정:
```kotlin
ndkVersion = "27.0.12077973"
```

### 2. **팀 협업 시**

**README.md에 명시**:
```markdown
## 개발 환경 설정

### Android NDK 버전
- 요구 버전: 27.0.12077973
- Android Studio → SDK Manager → SDK Tools에서 설치
```

**프로젝트 문서화**:
```
docs/
└── setup/
    └── android-ndk-setup.md  # NDK 설정 가이드
```

### 3. **버전 관리**

**build.gradle.kts**에 주석 추가:
```kotlin
android {
    namespace = "com.perch.perch_care"
    compileSdk = flutter.compileSdkVersion

    // Flutter 3.29+ 요구사항: NDK 27 이상 필수
    // 플러그인 호환성: app_links, path_provider_android 등
    ndkVersion = "27.0.12077973"

    // ...
}
```

### 4. **정기적인 NDK 업데이트**

**분기별 체크리스트**:
- [ ] Flutter SDK 업데이트 확인
- [ ] Android NDK 최신 버전 확인
- [ ] 플러그인 호환성 테스트
- [ ] `build.gradle.kts` 업데이트

---

## 참고 자료

### 공식 문서
- [Android NDK Downloads](https://developer.android.com/ndk/downloads)
- [Flutter Android Build Configuration](https://docs.flutter.dev/deployment/android)

### 관련 이슈
- [Flutter Issue #163945 - NDK version for new projects](https://github.com/flutter/flutter/issues/163945)
- [Flutter Issue #139427 - Use default NDK from AGP](https://github.com/flutter/flutter/issues/139427)

### Stack Overflow
- [Flutter Android: One or more plugins require higher NDK](https://stackoverflow.com/questions/73032815/)
- [Flutter build NDK version mismatch after upgrade](https://stackoverflow.com/questions/60392680/)

---

## 결론

✅ **NDK 버전 명시적 지정으로 해결**
✅ **후방 호환성으로 안전한 업데이트**
✅ **Flutter 3.29+에서는 NDK 27 필수**
✅ **프로젝트별 독립 설정 가능**
✅ **CI/CD 환경도 동일하게 설정**

**핵심 요약**:
```kotlin
// android/app/build.gradle.kts
android {
    ndkVersion = "27.0.12077973"
}
```

이 한 줄로 Flutter 3.29+ 프로젝트의 NDK 버전 불일치 문제를 근본적으로 해결할 수 있습니다. 🎯
