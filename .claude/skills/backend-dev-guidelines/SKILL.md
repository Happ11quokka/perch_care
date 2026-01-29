---
name: backend-dev-guidelines
description: |
  perch_care 프로젝트의 백엔드 연동 및 API 서비스 개발 가이드. 다음 작업 시 사용:
  - API 클라이언트/서비스 계층 수정
  - 인증/토큰 관리 (flutter_secure_storage)
  - FastAPI 엔드포인트 연동
  - 데이터 동기화 (로컬 캐시 ↔ 서버)
  - Codex 리뷰 결과의 백엔드/보안 관련 이슈 수정
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Backend Development Guidelines - perch_care

## Purpose

perch_care Flutter 앱의 백엔드 연동 및 API 서비스 계층 개발 가이드. FastAPI 백엔드와의 통신, 인증, 보안 스토리지, 데이터 동기화 패턴을 다룹니다.

## When to Use

- API 클라이언트(`ApiClient`) 수정 시
- 서비스 계층(`lib/src/services/`) 작업 시
- 인증/토큰 관리 수정 시
- 로컬 캐시 ↔ 서버 동기화 구현 시
- 보안 관련 수정 (토큰 저장, API 키 관리 등)
- Codex 코드 리뷰 결과 중 백엔드/보안 이슈 수정 시

## Architecture

```
Flutter App
  ↓
lib/src/services/
├── api/
│   ├── api_client.dart       # HTTP 클라이언트 (싱글턴)
│   └── token_service.dart    # JWT 토큰 관리 (flutter_secure_storage)
├── auth/
│   └── auth_service.dart     # 인증 (signup, login, OAuth, password reset)
├── pet/
│   ├── pet_service.dart      # 펫 CRUD (서버 API)
│   └── pet_local_cache_service.dart  # 펫 로컬 캐시
├── weight/
│   └── weight_service.dart   # 체중 기록 (서버 + 로컬)
├── schedule/
│   └── schedule_service.dart # 일정 관리
├── notification/
│   └── notification_service.dart # 알림 (폴링 + 백오프)
├── ai/
│   └── ai_encyclopedia_service.dart # AI 백과사전 (서버 프록시)
└── daily_record/
    └── daily_record_service.dart # 일일 기록
  ↓
FastAPI Backend (Environment.apiBaseUrl)
```

## Instructions

### 1. API 클라이언트 (`ApiClient`)

싱글턴 패턴의 HTTP 클라이언트. 자동 토큰 갱신을 지원합니다.

```dart
import '../../services/api/api_client.dart';

final _api = ApiClient.instance;

// 인증 필요 요청 (기본)
final data = await _api.get('/pets');
final pet = await _api.post('/pets', body: {'name': '사랑이'});
await _api.put('/pets/$id', body: {'name': '새이름'});
await _api.delete('/pets/$id');

// 인증 불필요 요청
await _api.post('/auth/login', body: {...}, auth: false);
```

**헤더 분리 규칙:**
- `auth: true` (기본) → `_authHeaders` (Authorization 포함)
- `auth: false` → `_headers` (Content-Type만, 토큰 미포함)

```dart
// _headers: 인증 불필요 (auth: false)
Map<String, String> get _headers {
  return {'Content-Type': 'application/json'};
}

// _authHeaders: 인증 필요 (기본)
Map<String, String> get _authHeaders {
  final token = _tokenService.accessToken;
  if (token == null) throw Exception('Not authenticated');
  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };
}
```

### 2. 토큰 관리 (`TokenService`)

**flutter_secure_storage** 사용하여 JWT 토큰을 암호화 저장합니다.

```dart
import '../../services/api/token_service.dart';

final _tokenService = TokenService.instance;

// 앱 시작 시 초기화 (main.dart)
await TokenService.instance.init();

// 토큰 저장 (로그인/갱신 시)
await _tokenService.saveTokens(
  accessToken: response['access_token'],
  refreshToken: response['refresh_token'],
);

// 토큰 삭제 (로그아웃)
await _tokenService.clearTokens();

// 사용자 ID 추출 (JWT payload)
final userId = _tokenService.userId;
```

**보안 규칙:**
- 토큰은 `SharedPreferences` 사용 금지 → `FlutterSecureStorage`만 사용
- API 키를 클라이언트에 직접 포함 금지 → 서버 프록시 패턴 사용

### 3. 인증 서비스 (`AuthService`)

```dart
import '../../services/auth/auth_service.dart';

final _authService = AuthService();

// 이메일 회원가입/로그인
await _authService.signUpWithEmail(email: e, password: p);
await _authService.signInWithEmailPassword(email: e, password: p);

// OAuth 로그인
await _authService.signInWithGoogle(idToken: token);
await _authService.signInWithApple(idToken: token);
await _authService.signInWithKakao(authorizationCode: code);

// 비밀번호 재설정 흐름
await _authService.resetPassword(email);          // 코드 전송
await _authService.verifyResetCode(email, code);   // 코드 검증
await _authService.updatePassword(                 // 새 비밀번호
  email: email, code: code, newPassword: newPw,
);

// 로그아웃
await _authService.signOut();
```

### 4. 서비스 계층 패턴

모든 서비스는 `ApiClient.instance`를 통해 백엔드와 통신합니다.

```dart
class PetService {
  final _api = ApiClient.instance;

  Future<Pet> createPet({
    required String name,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? gender,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      if (species != null) 'species': species,
      if (breed != null) 'breed': breed,
      if (birthDate != null) 'birth_date': birthDate.toIso8601String(),
      if (gender != null) 'gender': gender,
    };
    final response = await _api.post('/pets', body: body);
    return Pet.fromJson(response);
  }
}
```

### 5. 서버 프록시 패턴 (API 키 보호)

외부 API 키를 클라이언트에 포함하지 않고, 백엔드를 통해 호출합니다.

```dart
// 올바른 패턴: 서버 프록시
class AiEncyclopediaService {
  final _api = ApiClient.instance;

  Future<String> ask({required String query, ...}) async {
    final response = await _api.post('/ai/encyclopedia', body: {
      'query': query,
      ...
    });
    return response['answer'] as String;
  }
}

// 잘못된 패턴: 클라이언트에서 직접 호출
// final _apiKey = dotenv.get('PERPLEXITY_API_KEY'); // ← 금지
```

### 6. 데이터 동기화 패턴

로컬 캐시와 서버 데이터를 동기화합니다.

```dart
// 1. 서버에 저장
final savedPet = await _petService.createPet(name: name);

// 2. 로컬 캐시도 동기화
await _petCache.upsertPet(
  PetProfileCache(id: savedPet.id, name: savedPet.name),
  setActive: true,
);

// 편집 시: 기존 ID 유지, 서버 + 로컬 모두 업데이트
final petId = _existingPetId ?? _generateNewId();
```

### 7. 알림 폴링 패턴 (점진적 백오프)

```dart
// 점진적 백오프: 활동 시 30초, 비활동 시 최대 120초
Stream<List<AppNotification>> subscribeToNotifications() async* {
  int interval = 30;
  const maxInterval = 120;
  while (true) {
    await Future.delayed(Duration(seconds: interval));
    try {
      final notifications = await fetchNotifications(); // 전체 알림 (읽은 것 포함)
      yield notifications;
      if (notifications.any((n) => !n.isRead)) {
        interval = 30;  // 미읽음 있으면 빠르게
      } else {
        interval = (interval * 1.5).clamp(30, maxInterval).toInt();
      }
    } catch (_) {
      yield <AppNotification>[];
      interval = (interval * 2).clamp(30, maxInterval).toInt();
    }
  }
}
```

**주의:** `unreadOnly: true`로 폴링하면 읽은 알림이 목록에서 사라집니다. 전체 알림을 fetch하세요.

### 8. 에러 처리

```dart
try {
  await _api.post('/endpoint', body: data);
} on ApiException catch (e) {
  // 서버 에러 (statusCode, message 포함)
  if (e.statusCode == 401) {
    // 인증 만료 처리
  }
} catch (e) {
  // 네트워크 등 기타 에러
}
```

## API 엔드포인트 매핑

| 기능 | Method | Path | Auth |
|------|--------|------|------|
| 회원가입 | POST | `/auth/signup` | No |
| 로그인 | POST | `/auth/login` | No |
| 토큰 갱신 | POST | `/auth/refresh` | No |
| 비밀번호 재설정 | POST | `/auth/reset-password` | No |
| 코드 검증 | POST | `/auth/verify-reset-code` | No |
| 비밀번호 변경 | POST | `/auth/update-password` | No |
| OAuth | POST | `/auth/oauth/{provider}` | No |
| 프로필 조회 | GET | `/users/me/profile` | Yes |
| 프로필 수정 | PUT | `/users/me/profile` | Yes |
| 펫 CRUD | GET/POST/PUT/DELETE | `/pets`, `/pets/{id}` | Yes |
| 체중 기록 | GET/POST | `/pets/{id}/weights` | Yes |
| 일정 | GET/POST | `/pets/{id}/schedules` | Yes |
| AI 백과사전 | POST | `/ai/encyclopedia` | Yes |
| 알림 | GET | `/notifications` | Yes |

## Codex 리뷰에서 발견된 주요 패턴

| 패턴 | 올바른 방법 |
|------|------------|
| 토큰을 SharedPreferences에 저장 | `FlutterSecureStorage` 사용 |
| API 키를 클라이언트에 포함 | 서버 프록시 패턴 (`/ai/encyclopedia`) |
| `auth: false`에 토큰 포함 | `_headers` 게터에서 Authorization 제외 |
| 30초 고정 폴링 | 점진적 백오프 (30s ~ 120s) |
| 미읽음만 fetch | 전체 알림 fetch (읽은 알림 유지) |
| 로컬 캐시만 저장 | 서버 + 로컬 캐시 동시 업데이트 |
| HTTP 타임아웃 없음 | `http.Client` 타임아웃 설정 권장 |

## Best Practices

### DO
- 모든 민감 데이터는 `FlutterSecureStorage`에 저장
- 외부 API 호출은 서버 프록시를 통해
- 서버 저장 + 로컬 캐시 동시 업데이트
- `ApiException`으로 구조화된 에러 처리
- 네트워크 호출에 타임아웃 설정
- `auth: false` 요청에서 토큰 미포함 확인

### DON'T
- `SharedPreferences`에 토큰/건강 데이터 평문 저장
- 클라이언트에 API 키 직접 포함 (`dotenv.get('API_KEY')`)
- 로컬 캐시만 업데이트하고 서버 동기화 누락
- `unreadOnly: true`로 전체 목록 대체
- `process.env` / `Platform.environment` 직접 사용 (Environment 클래스 사용)
