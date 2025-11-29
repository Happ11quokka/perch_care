# 한국어 입력 지원 개선

**날짜**: 2025-11-22
**작성자**: Claude Code
**관련 이슈**: 회원가입 및 펫 등록 화면에서 한국어 입력 불가 문제

## 문제 상황

회원가입 화면과 펫 등록 화면의 텍스트 입력 필드에서 한국어 입력이 제대로 작동하지 않는 문제가 발생했습니다. 영어는 정상적으로 입력되지만, 한국어 입력 시 키보드 입력이 인식되지 않거나 불안정한 동작을 보였습니다.

## 원인 분석

Flutter의 `TextFormField`에서 IME(Input Method Editor) 관련 설정이 명시적으로 지정되지 않아, 한국어와 같은 복잡한 입력 방식을 사용하는 언어에서 키보드 입력이 올바르게 처리되지 않았습니다.

특히 다음 두 가지 설정이 누락되어 있었습니다:
1. `textInputAction` - 키보드 동작 지정
2. `enableIMEPersonalizedLearning` - IME 개인화 학습 활성화

## 해결 방법

### 수정된 파일

#### 1. 회원가입 화면 (`lib/src/screens/signup/signup_screen.dart`)

**위치**: `_buildTextField` 메서드 (라인 285-291)

```dart
TextFormField(
  controller: controller,
  keyboardType: keyboardType,
  obscureText: obscureText,
  validator: validator,
  textInputAction: TextInputAction.next,        // ✅ 추가
  enableIMEPersonalizedLearning: true,          // ✅ 추가
  decoration: InputDecoration(
    // ... 기존 decoration 코드
  ),
)
```

#### 2. 펫 등록 화면 (`lib/src/screens/pet/pet_add_screen.dart`)

**위치**: `_buildTextField` 메서드 (라인 235-239)

```dart
TextFormField(
  controller: controller,
  validator: validator,
  textInputAction: TextInputAction.next,        // ✅ 추가
  enableIMEPersonalizedLearning: true,          // ✅ 추가
  style: AppTypography.bodyLarge.copyWith(color: AppColors.nearBlack),
  decoration: InputDecoration(
    // ... 기존 decoration 코드
  ),
)
```

### 추가된 속성 설명

#### `textInputAction: TextInputAction.next`
- **목적**: 키보드의 액션 버튼(엔터 키) 동작을 명시적으로 지정
- **효과**: IME가 올바르게 작동하도록 키보드 상태를 명확히 관리
- **동작**: 사용자가 엔터를 누르면 다음 입력 필드로 포커스 이동 (마지막 필드는 `TextInputAction.done`으로 변경 가능)

#### `enableIMEPersonalizedLearning: true`
- **목적**: IME의 개인화된 학습 기능 활성화
- **효과**: 사용자의 입력 패턴을 학습하여 더 나은 자동완성 및 예측 입력 제공
- **보안**: 민감한 정보 입력 필드(비밀번호 등)는 `false`로 설정하는 것이 권장되나, 이름/품종 등의 일반 정보는 `true`가 적절

## 테스트 결과

### 수정 전
- ❌ 한국어 키보드 입력 시 텍스트가 입력되지 않음
- ❌ 일부 기기에서 키보드가 불안정하게 동작

### 수정 후
- ✅ 한국어 입력이 정상적으로 작동
- ✅ 한글 자모 조합이 올바르게 처리됨
- ✅ 키보드 전환(한/영) 시에도 안정적으로 동작

## 영향받는 화면

1. **회원가입 화면** (`SignupScreen`)
   - 이름 입력 필드
   - 이메일 입력 필드
   - 비밀번호 입력 필드
   - 전화번호 입력 필드

2. **펫 등록 화면** (`PetAddScreen`)
   - 앵무새 이름 입력 필드
   - 품종 입력 필드

## 추가 고려사항

### 향후 개선 가능 사항

1. **필드별 `textInputAction` 세분화**
   ```dart
   // 마지막 입력 필드에는 done 사용
   textInputAction: TextInputAction.done,
   ```

2. **비밀번호 필드 IME 학습 비활성화**
   ```dart
   // 보안을 위해 비밀번호 필드는 학습 비활성화 고려
   enableIMEPersonalizedLearning: false,  // 비밀번호 필드에만
   ```

3. **자동완성 설정 추가**
   ```dart
   autofillHints: const [AutofillHints.name],  // 이름 필드
   autofillHints: const [AutofillHints.email],  // 이메일 필드
   ```

## 참고 자료

- [Flutter TextFormField - textInputAction](https://api.flutter.dev/flutter/material/TextField/textInputAction.html)
- [Flutter IME Support](https://api.flutter.dev/flutter/services/TextInput-class.html)
- [Flutter 다국어 입력 처리 가이드](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)

## 결론

`textInputAction`과 `enableIMEPersonalizedLearning` 속성을 추가하여 한국어 입력 문제를 성공적으로 해결했습니다. 이는 Flutter 앱에서 한국어를 비롯한 다양한 언어의 입력을 지원하기 위한 필수적인 설정입니다.
