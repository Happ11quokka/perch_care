# L-6: 이메일 존재 여부 노출 방지

> 구현일: 2026-03-22

## 문제

signup API에서 이미 가입된 이메일로 회원가입 시도 시:
```
HTTP 409 { "detail": "Email already registered" }
```
공격자가 이 응답으로 가입된 이메일 목록을 열거(enumeration)할 수 있음.

## 해결

`backend/app/services/auth_service.py` line 20:
```python
# Before
raise HTTPException(status_code=409, detail="Email already registered")

# After
raise HTTPException(status_code=409, detail="Signup failed")
```

- 409 상태 코드는 유지 (프론트엔드가 상태 코드로 판단하여 UX 메시지 표시)
- 응답 body에서 이메일 존재를 직접 알려주는 문구 제거

## 프론트엔드 영향

변경 없음. `error_handler.dart`에서 409 상태 코드로 `error_signupEmailExists` 메시지를 표시하는 로직은 유지. 사용자 UX는 동일하지만 API 직접 호출 시 이메일 존재 여부를 추론할 수 없음.

## 참고: 비밀번호 재설정은 이미 안전

```python
# auth_service.py line 160, 175
return {"message": "If that email exists, a reset code has been sent."}
```
비밀번호 재설정 API는 이미 이메일 존재 여부를 노출하지 않는 패턴 적용됨.
