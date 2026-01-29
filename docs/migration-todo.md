# Supabase → FastAPI 마이그레이션 TODO

## 개요
Supabase 기반 백엔드를 FastAPI + PostgreSQL로 마이그레이션한 후 남은 작업 목록입니다.

---

## 1. OAuth 네이티브 SDK 통합 (필수)

Supabase SDK가 처리하던 OAuth 로그인 흐름을 네이티브 SDK로 직접 구현해야 합니다.

### Google 로그인
- **파일**: [login_screen.dart:33](lib/src/screens/login/login_screen.dart#L33), [email_login_screen.dart:543](lib/src/screens/login/email_login_screen.dart#L543)
- **패키지**: `google_sign_in`
- **작업**: Google Sign-In SDK로 `idToken` 획득 → `authService.signInWithGoogle(idToken:)` 호출

### Apple 로그인
- **파일**: [login_screen.dart:50](lib/src/screens/login/login_screen.dart#L50), [email_login_screen.dart:560](lib/src/screens/login/email_login_screen.dart#L560)
- **패키지**: `sign_in_with_apple`
- **작업**: Apple Sign-In SDK로 `idToken` 획득 → `authService.signInWithApple(idToken:)` 호출

### Kakao 로그인
- **파일**: [login_screen.dart:67](lib/src/screens/login/login_screen.dart#L67), [email_login_screen.dart:577](lib/src/screens/login/email_login_screen.dart#L577)
- **패키지**: `kakao_flutter_sdk`
- **작업**: Kakao SDK로 `authorizationCode` 획득 → `authService.signInWithKakao(authorizationCode:)` 호출

### 필요한 pubspec.yaml 추가
```yaml
google_sign_in: ^6.2.1
sign_in_with_apple: ^6.1.1
kakao_flutter_sdk_user: ^1.9.5
```

---

## 2. 비밀번호 재설정 흐름 연동

### 인증 코드 검증
- **파일**: [forgot_password_code_screen.dart:309](lib/src/screens/forgot_password/forgot_password_code_screen.dart#L309)
- **작업**: 코드 검증 API 엔드포인트 연동 (`POST /auth/verify-code`)

### 코드 재전송
- **파일**: [forgot_password_code_screen.dart:316](lib/src/screens/forgot_password/forgot_password_code_screen.dart#L316)
- **작업**: 코드 재전송 API 호출

### 비밀번호 재설정
- **파일**: [forgot_password_reset_screen.dart:340](lib/src/screens/forgot_password/forgot_password_reset_screen.dart#L340)
- **작업**: 비밀번호 재설정 API 연동 (`POST /auth/reset-password/confirm`)

---

## 3. 프로필 관련

### 프로필 설정 화면
- **파일**: [profile_setup_screen.dart:485](lib/src/screens/profile_setup/profile_setup_screen.dart#L485)
- **작업**: 사진 선택 기능 구현 (카메라/갤러리)
- **파일**: [profile_setup_screen.dart:575](lib/src/screens/profile_setup/profile_setup_screen.dart#L575)
- **작업**: 프로필 데이터 저장 로직 → `authService.updateProfile()` 연동

### 프로필 화면 실제 데이터 연동
- **파일**: [profile_screen.dart:20](lib/src/screens/profile/profile_screen.dart#L20)
- **작업**: 하드코딩된 사용자 데이터를 `authService.getProfile()`로 대체
- **파일**: [profile_screen.dart:26](lib/src/screens/profile/profile_screen.dart#L26)
- **작업**: 하드코딩된 반려동물 데이터를 `petService`로 대체

### 반려동물 프로필 상세
- **파일**: [pet_profile_detail_screen.dart:20](lib/src/screens/profile/pet_profile_detail_screen.dart#L20)
- **작업**: 실제 데이터 연동
- **파일**: [pet_profile_detail_screen.dart:147](lib/src/screens/profile/pet_profile_detail_screen.dart#L147)
- **작업**: 이미지 업로드 기능 → `healthCheckService.uploadImage()` 패턴 참고

### 설정 화면 이동
- **파일**: [pet_profile_screen.dart:215](lib/src/screens/pet/pet_profile_screen.dart#L215)
- **작업**: 설정 화면 라우트 연결

---

## 4. 기타

### 이미지 선택 (펫 등록)
- **파일**: [pet_add_screen.dart:265](lib/src/screens/pet/pet_add_screen.dart#L265)
- **작업**: 이미지 선택 + 업로드 기능 구현

### 건강 신호 화면
- **파일**: [home_screen.dart:658](lib/src/screens/home/home_screen.dart#L658)
- **작업**: 건강 신호 화면 라우트 연결

---

## 5. 백엔드 배포 준비

### Docker Compose 배포
- [ ] VPS 서버 준비 (Ubuntu 22.04+ 권장)
- [ ] 도메인 설정 및 DNS 구성
- [ ] SSL 인증서 설정 (Let's Encrypt)
- [ ] `backend/.env` 실제 환경 변수 설정
- [ ] `docker compose up -d` 실행
- [ ] Alembic 마이그레이션 실행 확인

### Flutter .env 설정
- [ ] `.env` 파일에 실제 서버 URL 설정: `API_BASE_URL=https://your-domain.com/api/v1`

### OAuth 플랫폼 설정
- [ ] Google Cloud Console - OAuth 클라이언트 설정
- [ ] Apple Developer - Sign in with Apple 설정
- [ ] Kakao Developers - 앱 등록 및 Redirect URI 설정

---

## 6. 테스트

### 백엔드 (pytest)
- [ ] 인증 API 테스트 (signup, login, refresh, OAuth)
- [ ] Pets CRUD 테스트
- [ ] Weights CRUD + monthly-averages, weekly-data 테스트
- [ ] Daily Records CRUD 테스트
- [ ] Health Checks CRUD + 이미지 업로드 테스트
- [ ] Schedules CRUD 테스트
- [ ] Notifications CRUD + 읽음 처리 테스트

### Flutter
- [ ] ApiClient 단위 테스트
- [ ] TokenService 단위 테스트
- [ ] 각 서비스 mock 테스트
- [ ] 이메일 로그인/회원가입 E2E 테스트
- [ ] 전체 화면 수동 QA

---

## 우선순위

| 우선순위 | 항목 | 이유 |
|---------|------|------|
| P0 | 백엔드 배포 | 앱이 동작하려면 서버가 필요 |
| P0 | OAuth SDK 통합 | 소셜 로그인 필수 기능 |
| P1 | 비밀번호 재설정 흐름 | 사용자 계정 복구 |
| P1 | 프로필 데이터 연동 | 실제 데이터 표시 |
| P2 | 이미지 업로드 | 펫 프로필/건강검진 사진 |
| P2 | 백엔드 테스트 작성 | 안정성 확보 |
| P3 | 기타 화면 연결 | 부가 기능 |
