# 회원가입/로그인 폼 아이콘 및 입력 배경 수정

**날짜**: 2026-01-05  
**파일**:

- [lib/src/screens/signup/signup_screen.dart](../../lib/src/screens/signup/signup_screen.dart)
- [lib/src/screens/login/email_login_screen.dart](../../lib/src/screens/login/email_login_screen.dart)
- [pubspec.yaml](../../pubspec.yaml)

## 구현 목표

- Figma에서 제공한 `signup_vector` 아이콘을 실제 앱 입력 필드에 반영
- 테마 기본 InputDecoration 배경을 제거해 투명 배경 유지
- 아이콘이 번들에 포함되어 정상 표시되도록 에셋 등록

## 주요 변경 사항

### 1. 아이콘 자원 교체

- 입력 필드 아이콘 경로를 `signup_vector/name|email|password.svg`로 변경
- 아이콘 크기 20px로 조정해 폼 안에서 여백 균형 맞춤

### 2. 입력 배경 제거

- `TextFormField`/`TextField`의 `filled`/`fillColor`를 해제해 회색 배경 제거
- 외곽선, 타이포 등 기존 스타일은 유지

### 3. 에셋 등록

- `pubspec.yaml`에 `assets/images/signup_vector/`를 추가 등록하여 SVG 번들 누락 문제 해결

## 결과 및 영향

- 회원가입/이메일 로그인 화면에 아이콘이 정상 표시되고, 입력창 배경이 투명하게 노출됨
- 추가 런타임 의존성 없음; 빌드 시 에셋만 새로 포함하면 됨
