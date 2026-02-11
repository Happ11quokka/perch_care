# 다국어 지원 (Localization/l10n) 구현

**날짜**: 2026-02-11
**작성자**: Claude Code
**상태**: 완료

## 개요

perch_care 앱에 한국어, 영어, 중국어 3개 언어 지원을 구현했습니다. Flutter의 공식 `gen_l10n` 방식을 사용하여 컴파일 타임에 타입 안전한 번역 코드를 자동 생성합니다.

## 구현 방식

### 1. Flutter 공식 l10n (gen_l10n) 사용

Flutter에서 권장하는 공식 국제화 방식으로, ARB(Application Resource Bundle) 파일을 기반으로 Dart 코드를 자동 생성합니다.

**장점:**
- 타입 안전성 (오타 시 컴파일 에러 발생)
- IDE 자동완성 지원
- placeholder 매개변수의 타입 체크
- Flutter 공식 지원으로 안정성 보장

## 파일 구조

```
lib/
├── l10n/
│   ├── app_ko.arb              # 한국어 (템플릿)
│   ├── app_en.arb              # 영어
│   ├── app_zh.arb              # 중국어
│   ├── app_localizations.dart  # 자동 생성 (메인 클래스)
│   ├── app_localizations_ko.dart  # 자동 생성
│   ├── app_localizations_en.dart  # 자동 생성
│   └── app_localizations_zh.dart  # 자동 생성
├── src/
│   └── providers/
│       └── locale_provider.dart  # 언어 설정 관리
└── main.dart                     # MaterialApp 설정
```

## 설정 파일

### l10n.yaml

프로젝트 루트에 위치한 l10n 코드 생성 설정 파일:

```yaml
arb-dir: lib/l10n                    # ARB 파일 위치
template-arb-file: app_ko.arb        # 기준이 되는 템플릿 파일 (한국어)
output-localization-file: app_localizations.dart  # 생성될 파일명
output-class: AppLocalizations       # 생성될 클래스명
output-dir: lib/l10n                 # 생성 파일 출력 위치
synthetic-package: false             # lib 폴더에 직접 생성
preferred-supported-locales:
  - ko                               # 기본 언어
nullable-getter: false               # non-nullable getter 사용
```

### pubspec.yaml

```yaml
dependencies:
  flutter_localizations:
    sdk: flutter

flutter:
  generate: true  # l10n 코드 자동 생성 활성화
```

## ARB 파일 형식

### 기본 문자열

```json
{
  "@@locale": "ko",
  "common_save": "저장",
  "common_cancel": "취소"
}
```

### Placeholder가 있는 문자열

```json
{
  "home_updatedAgo": "{minutes}분 전에 업데이트됨",
  "@home_updatedAgo": {
    "placeholders": {
      "minutes": {"type": "int"}
    }
  },

  "weightDetail_recordSummary": "{petName}의 몸무게 총 {days}일 기록 중",
  "@weightDetail_recordSummary": {
    "placeholders": {
      "petName": {"type": "String"},
      "days": {"type": "int"}
    }
  }
}
```

## 사용 방법

### 1. 문자열 접근

```dart
import 'package:perch_care/l10n/app_localizations.dart';

// 위젯에서 사용
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context);

  return Text(l10n.common_save);  // "저장" (한국어일 때)
}
```

### 2. Placeholder 사용

```dart
// int 타입 placeholder
Text(l10n.home_updatedAgo(5))  // "5분 전에 업데이트됨"

// 여러 개의 placeholder
Text(l10n.weightDetail_recordSummary('콩이', 30))
// "콩이의 몸무게 총 30일 기록 중"
```

### 3. 언어 변경

```dart
// 특정 언어로 변경
await LocaleProvider.instance.setLocale(Locale('en'));

// 기기 설정 따르기 (null로 설정)
await LocaleProvider.instance.setLocale(null);
```

## LocaleProvider

언어 설정을 관리하는 싱글톤 클래스:

```dart
class LocaleProvider extends ChangeNotifier {
  static final LocaleProvider _instance = LocaleProvider._internal();
  static LocaleProvider get instance => _instance;

  Locale? _locale;  // null이면 기기 설정 따름

  // 지원 언어 목록
  static const List<Locale> supportedLocales = [
    Locale('ko'),  // 한국어
    Locale('en'),  // 영어
    Locale('zh'),  // 중국어
  ];

  // SharedPreferences에 저장/로드
  Future<void> setLocale(Locale? locale) async { ... }
}
```

## MaterialApp 설정

```dart
MaterialApp.router(
  // Localization delegates
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  // 지원 언어 목록
  supportedLocales: const [
    Locale('ko'),  // 한국어 (기본)
    Locale('en'),  // 영어
    Locale('zh'),  // 중국어
  ],
  // 현재 선택된 언어 (null이면 기기 설정)
  locale: LocaleProvider.instance.locale,
)
```

## 새 번역 문자열 추가 방법

### 1. 템플릿 ARB 파일 수정 (app_ko.arb)

```json
{
  "new_key": "새 문자열",
  "@new_key": {
    "description": "이 문자열의 용도 설명"
  }
}
```

### 2. 다른 언어 ARB 파일에도 추가

**app_en.arb:**
```json
{
  "new_key": "New string"
}
```

**app_zh.arb:**
```json
{
  "new_key": "新字符串"
}
```

### 3. 코드 생성 실행

```bash
flutter pub get
# 또는
flutter gen-l10n
```

### 4. 코드에서 사용

```dart
Text(AppLocalizations.of(context).new_key)
```

## 네이밍 컨벤션

```
{screen}_{element}
{category}_{action/state}
```

**예시:**
- `login_title` - 로그인 화면 제목
- `common_save` - 공통 저장 버튼
- `error_loginFailed` - 로그인 실패 에러
- `validation_enterEmail` - 이메일 입력 검증
- `snackbar_saved` - 저장 완료 스낵바

## 지원 언어

| 코드 | 언어 | 파일 |
|------|------|------|
| `ko` | 한국어 | app_ko.arb |
| `en` | English | app_en.arb |
| `zh` | 中文 | app_zh.arb |

## 주의사항

1. **ARB 파일은 JSON 형식**이지만 마지막 항목 뒤에 쉼표가 없어야 합니다.

2. **모든 ARB 파일에 동일한 키가 존재**해야 합니다. 누락되면 빌드 시 에러가 발생합니다.

3. **Placeholder 타입 지정** 시 지원되는 타입:
   - `String`
   - `int`
   - `double`
   - `num`
   - `DateTime`

4. **코드 생성 파일은 수정하지 마세요** (`app_localizations*.dart`). ARB 파일만 수정하면 됩니다.

5. **Hot reload로는 번역이 적용되지 않습니다**. 새 번역 추가 후 앱을 재시작해야 합니다.

## 참고 자료

- [Flutter 공식 국제화 문서](https://docs.flutter.dev/ui/accessibility-and-localization/internationalization)
- [ARB 파일 형식](https://github.com/google/app-resource-bundle/wiki)
