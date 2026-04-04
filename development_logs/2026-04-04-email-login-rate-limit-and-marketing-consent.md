# 이메�� 로그인 — Rate Limiting 수정 + 마케팅 동의 추가

> 구현일: 2026-04-04

## 1. TC-013 Rate Limiting 미작동 수정

### 문제
- TC-013: 잘못된 비밀번호로 10회 연속 로그인 시도 시에도 429가 반환되지 않음 (모두 401)
- `auth.py`에 `@limiter.limit("10/minute")` 데코레이터가 있었으나 실제로 작동하지 않음

### 원인
- `main.py`와 `auth.py`에 **Limiter 인스턴스가 2개** 별도 생성됨
- `main.py:107` → `app.state.limiter = Limiter(key_func=get_remote_address)` (앱에 등록)
- `auth.py:22` → `limiter = Limiter(key_func=_get_auth_rate_limit_key)` (앱에 미등록)
- slowapi는 `app.state.limiter`에 등록된 인스턴스만 동작하므로, `auth.py`의 데코레이터가 무시됨

### 해결
공유 Limiter 싱글턴 모듈 생성:

```python
# backend/app/limiter.py
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)
```

- `main.py` → `from app.limiter import limiter` 후 `app.state.limiter = limiter`
- `auth.py` → `from app.limiter import limiter` (별도 인스턴스 제거)
- 동일 인스턴스가 앱에 등록되고 데코레이터에서도 사용됨

### 수정 파일
- `backend/app/limiter.py` — 신규 생성, 공유 Limiter 인스턴스
- `backend/app/main.py` — 공유 limiter import로 변경
- `backend/app/routers/auth.py` — 별도 Limiter + key 함수 제거, 공유 limiter 사용

### 현재 Rate Limit 설정

| 엔드포인트 | 제한 |
|-----------|------|
| `POST /auth/signup` | 5/minute |
| `POST /auth/login` | 10/minute |
| `POST /auth/oauth/{provider}` | 10/minute |
| `POST /auth/reset-password` | 3/minute |
| `POST /auth/verify-reset-code` | 5/minute |
| `POST /auth/update-password` | 5/minute |

### 잔존 이슈
- `reports.py`, `premium.py`, `ai.py`, `health_checks.py`에도 동일한 별도 Limiter 인스턴스 문제 있음
- 해당 라우터들은 JWT 기반 사용자별 rate limit 키를 사용하므로 별도 검토 필요

---

## 2. 회원가입 마케팅 동의 항목 추가

### 배경
- 회원가입 시 `[선택] 마케팅 정보 수신 동의` 체크박스는 UI에 존재했으나:
  - 마케팅 약관 상세 내용이 없어 "보기" 링크 미제공
  - 동의 값(`marketingAgreed`)이 서버로 전송되지 않음

### 해결

**약관 내용 추가** (`terms_content.dart`):
- `TermsType.marketing` enum 값 추가
- 한국어/영어/중국어 마케팅 동의 약관 전문 작성
- 수집 목적, 수집 항목, 보유 기간, 수신 방법, 거부권 안내 포함

**UI 연결** (`terms_agreement_section.dart`):
- 마케팅 항목에 `termsType: TermsType.marketing` 추가 → "보기" 링크 활성화
- 약관 상세 화면에서 마케팅 내용 열람 가능

**서버 전송** (`signup_screen.dart` + `auth_service.dart`):
- `_marketingAgreed` 상태 변수 추가, 콜백에서 캡처
- `signUpWithEmail()`에 `marketingAgreed` 파라미터 추가
- API 요청 body에 `marketing_agreed` 필드 포함

### 수정 파일
- `lib/src/data/terms_content.dart` — `TermsType.marketing` + 3개 언어 약관 내용
- `lib/src/screens/terms/terms_detail_screen.dart` — marketing 타이틀 매핑
- `lib/src/widgets/terms_agreement_section.dart` — 마케팅 "보기" 링크 추가
- `lib/src/screens/signup/signup_screen.dart` — `_marketingAgreed` 캡처 + API 전달
- `lib/src/services/auth/auth_service.dart` — `marketing_agreed` body 필드 추가
- `lib/l10n/app_ko.arb`, `app_en.arb`, `app_zh.arb` — `terms_marketing` 키 추가
