# 카카오 로그인 400 Bad Request 및 provider_id 불일치 수정

**날짜**: 2026-01-31
**수정 파일**:
- [backend/app/schemas/auth.py](../../backend/app/schemas/auth.py)
- [backend/app/schemas/user.py](../../backend/app/schemas/user.py)
- [backend/app/utils/security.py](../../backend/app/utils/security.py)
- [backend/app/routers/auth.py](../../backend/app/routers/auth.py)
- [backend/app/routers/users.py](../../backend/app/routers/users.py)
- [lib/src/services/auth/auth_service.dart](../../lib/src/services/auth/auth_service.dart)
- [lib/src/screens/profile/profile_screen.dart](../../lib/src/screens/profile/profile_screen.dart)

## 증상

카카오 로그인 시 백엔드에서 400 Bad Request 반환:

```
INFO: 172.18.0.1:58598 - "POST /api/v1/auth/oauth/kakao HTTP/1.1" 400 Bad Request
```

카카오 계정을 프로필에서 연동한 후에도 로그인 시 "회원가입 필요" (`signup_required`) 응답이 반환됨. Google 로그인은 정상 동작.

## 원인

두 가지 문제가 복합적으로 발생:

### 1. 필드명 불일치 (400 Bad Request)

Flutter 앱은 `access_token` 필드로 카카오 토큰을 전송하지만, 백엔드 `OAuthRequest` 스키마에는 해당 필드가 존재하지 않았음:

```dart
// Flutter (auth_service.dart) - access_token으로 전송
final response = await _api.post('/auth/oauth/kakao', body: {
  'access_token': accessToken,
}, auth: false);
```

```python
# 백엔드 (schemas/auth.py) - access_token 필드 없음
class OAuthRequest(BaseModel):
    id_token: str | None = None
    authorization_code: str | None = None  # ← access_token 필드 없음
    provider: str | None = None
    email: str | None = None
```

Pydantic이 `access_token`을 무시 → `id_token`과 `authorization_code` 모두 `None` → `provider_id`가 빈 문자열 → 400 "Missing provider credentials" 발생.

### 2. provider_id 불일치 (signup_required)

카카오 계정 연동 시 Flutter가 **액세스 토큰 문자열**을 `provider_id`로 저장:

```dart
// 수정 전 (profile_screen.dart)
await _authService.linkSocialAccount(
  provider: 'kakao',
  providerId: token.accessToken,  // 카카오 액세스 토큰 (랜덤 문자열)
);
```

DB에 저장된 값:
```
provider_id: VqPY7slwUTmyl43GIzlJ_cjuNN1mDQYbAAAAAQoXAVAAAAGcEwfBP6j01SImjvGc
```

반면 로그인 시에는 카카오 API를 호출하여 **실제 카카오 유저 ID(숫자)**를 `provider_id`로 조회해야 하므로, 저장된 값과 조회 값이 불일치하여 항상 `signup_required` 반환.

## 수정 내용

### 1. 카카오 access_token 서버 검증 함수 추가 (`security.py`)

카카오 사용자 정보 API(`https://kapi.kakao.com/v2/user/me`)를 호출하여 토큰을 검증하고 유저 고유 ID를 추출하는 함수 추가:

```python
import httpx

def verify_kakao_access_token(token: str) -> dict | None:
    try:
        resp = httpx.get(
            "https://kapi.kakao.com/v2/user/me",
            headers={"Authorization": f"Bearer {token}"},
            timeout=10,
        )
        if resp.status_code != 200:
            return None
        data = resp.json()
        user_id = str(data.get("id", ""))
        if not user_id:
            return None
        email = None
        kakao_account = data.get("kakao_account")
        if kakao_account and kakao_account.get("has_email"):
            email = kakao_account.get("email")
        return {"sub": user_id, "email": email}
    except Exception:
        return None
```

- Google의 `verify_google_id_token()`과 동일한 인터페이스 (`sub`, `email` 반환).
- `httpx`는 이미 `requirements.txt`에 포함되어 있으므로 추가 의존성 불필요.

### 2. OAuthRequest 스키마에 `access_token` 필드 추가 (`schemas/auth.py`)

```python
class OAuthRequest(BaseModel):
    id_token: str | None = None
    access_token: str | None = None     # 추가 (카카오용)
    authorization_code: str | None = None
    provider: str | None = None
    email: str | None = None
```

### 3. OAuth 로그인 엔드포인트에 카카오 분기 추가 (`routers/auth.py`)

```python
if provider == "google" and request.id_token:
    google_info = verify_google_id_token(request.id_token)
    ...
elif provider == "kakao" and request.access_token:       # 추가
    kakao_info = verify_kakao_access_token(request.access_token)
    if not kakao_info:
        raise HTTPException(status_code=401, detail="Invalid Kakao access token")
    provider_id = kakao_info["sub"]   # 카카오 유저 고유 ID (숫자)
    email = email or kakao_info.get("email")
else:
    provider_id = request.authorization_code or ""
```

### 4. 소셜 계정 연동 엔드포인트에도 카카오 검증 추가 (`routers/users.py`, `schemas/user.py`)

`SocialAccountLinkRequest`에 `access_token` 필드 추가:

```python
class SocialAccountLinkRequest(BaseModel):
    provider: str
    id_token: str | None = None
    access_token: str | None = None     # 추가 (카카오용)
    provider_id: str | None = None
    provider_email: str | None = None
```

연동 라우터에서도 동일한 검증 추가:

```python
elif request.provider == "kakao" and request.access_token:
    kakao_info = verify_kakao_access_token(request.access_token)
    if not kakao_info:
        raise HTTPException(status_code=401, detail="Invalid Kakao access token")
    provider_id = kakao_info["sub"]
    provider_email = provider_email or kakao_info.get("email")
```

### 5. Flutter 클라이언트 수정

**`auth_service.dart`** - `linkSocialAccount`에 `accessToken` 파라미터 추가:

```dart
Future<void> linkSocialAccount({
  required String provider,
  String? idToken,
  String? accessToken,    // 추가
  String? providerId,
  String? providerEmail,
}) async {
  await _api.post('/users/me/social-accounts', body: {
    'provider': provider,
    if (idToken != null) 'id_token': idToken,
    if (accessToken != null) 'access_token': accessToken,    // 추가
    if (providerId != null) 'provider_id': providerId,
    if (providerEmail != null) 'provider_email': providerEmail,
  });
}
```

**`profile_screen.dart`** - 카카오 연동 시 `accessToken`으로 전송:

```dart
// 수정 후
await _authService.linkSocialAccount(
  provider: 'kakao',
  accessToken: token.accessToken,  // providerId → accessToken
);
```

### 6. 기존 잘못된 DB 데이터 정리

기존에 액세스 토큰 문자열로 저장된 카카오 소셜 계정 레코드를 수동 삭제:

```sql
DELETE FROM social_accounts
WHERE provider = 'kakao'
AND provider_id LIKE 'VqP%';
```

사용자에게 카카오 연동 해제 → 재연동을 안내.

## 데이터 흐름 (수정 후)

```
Flutter App                          FastAPI Backend
─────────────────────────────────────────────────────
Kakao SDK → accessToken (OAuth)
                    ──access_token──▶  verify_kakao_access_token()
                                       ├─ GET kapi.kakao.com/v2/user/me
                                       │   (Authorization: Bearer {token})
                                       ├─ 응답에서 id 추출 (숫자)
                                       └─ kakao_account.email 추출
                                              │
                                       provider_id = "3941234567"
                                              │
                                       INSERT INTO social_accounts
                                       (provider_id = "3941234567") ✅

[로그인 시]
                    ──access_token──▶  verify_kakao_access_token()
                                       └─ provider_id = "3941234567"
                                              │
                                       SELECT FROM social_accounts
                                       WHERE provider='kakao'
                                       AND provider_id='3941234567' ✅ 매칭
                                              │
                    ◀── JWT 발급 ───────  authenticated
```

## Provider별 토큰 검증 방식 비교

| Provider | 토큰 타입 | 검증 방식 | provider_id 원본 |
|----------|-----------|-----------|------------------|
| Google | `id_token` (JWT) | `google.oauth2.id_token.verify_oauth2_token()` | JWT `sub` claim |
| Apple | `id_token` (JWT) | 미구현 (향후 추가 필요) | - |
| Kakao | `access_token` (OAuth) | `GET kapi.kakao.com/v2/user/me` | 응답 `id` 필드 |

## 핵심 교훈

- OAuth provider마다 **토큰 타입과 검증 방식이 다르다**: Google/Apple은 `id_token`(JWT, 자체 검증 가능), Kakao는 `access_token`(서버 API 호출로 검증).
- 백엔드 스키마와 Flutter 클라이언트가 보내는 **필드명이 정확히 일치**해야 한다. Pydantic의 기본 설정은 알 수 없는 필드를 조용히 무시하므로 에러를 찾기 어렵다.
- `provider_id`에는 항상 **provider가 발급한 유저 고유 식별자**를 저장해야 하며, 토큰 자체를 저장하면 안 된다 (토큰은 만료/갱신되므로 식별자로 부적합).
- Flutter 코드 변경 후에는 **앱 재시작(hot restart)**이 필요하다. 백엔드는 `--reload`로 자동 반영되지만, 모바일 앱은 수동 재시작해야 변경이 적용된다.
