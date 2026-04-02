# Production 서버 봇 스캔 트래픽 분석

> 날짜: 2026-03-30
> 환경: Railway production (`perchcare-production.up.railway.app`)
> 배포: `d1f5b782` (2026-03-10 빌드, us-west2)

---

## 발견 경위

Railway Deploy Logs 확인 중 정상 API 트래픽 사이에 다수의 404 요청 발견.

## 정상 트래픽 패턴

앱 사용자들의 일반적인 API 호출. 모두 `/api/v1/` 경로 하위에서 발생:

```
GET  /api/v1/pets/                          → 200
GET  /api/v1/pets/{id}/bhi/?target_date=... → 200
POST /api/v1/pets/{id}/weights/             → 201
POST /api/v1/auth/oauth/apple               → 200
GET  /api/v1/pets/active                    → 200 (간혹 401 → refresh → 200)
POST /api/v1/ai/encyclopedia                → 200
```

- 401 → `POST /auth/refresh` → 200 흐름은 JWT 토큰 만료 후 자동 갱신하는 정상 패턴
- 간헐적으로 refresh도 401 반환 → Apple OAuth 재인증으로 복구되는 케이스 확인

## 봇 스캔 트래픽 (404 응답)

아래 요청들은 **앱과 무관한 자동화 봇/스캐너**의 무차별 탐색 요청:

### 관리자 페이지 탐색
```
GET /admin                              → 404
GET /wap/                               → 404
GET /app/                               → 404
GET /mobile                             → 404
```

### PHP 기반 웹앱 취약점 스캔
```
GET /system.php?act=payments            → 404
GET /leftDao.php?callback=jQuery...     → 404
GET /index.php/sign                     → 404
```

### 중국 쇼핑몰/도박/거래소 플랫폼 패턴
```
GET /Home/Get/getJnd28                  → 404  (도박 사이트)
GET /api/currency/quotation_new         → 404  (거래소)
GET /api/chat/fish_init                 → 404  (피싱/챗봇)
GET /api/product/getAll                 → 404  (쇼핑몰)
GET /api/message/webInfo                → 404  (메시징)
GET /api/site/getInfo.do                → 404  (Java 웹앱)
```

### 정적 리소스 탐색 (웹 프레임워크 핑거프린팅)
```
GET /static/index/js/lk/order.js        → 404
GET /static/wap/js/order.js             → 404
GET /static/wap/css/trade-history.css   → 404
GET /static/guide/ab.css                → 404
GET /static/common/js/common.js         → 404
GET /static/admincp/js/common.js        → 404
GET /static/css/style.css               → 404
GET /Public/home/wap/css/qdgame.css     → 404
GET /Public/home/common/js/index.js     → 404
GET /public/css/style.css               → 404
GET /public/img/cz1.png                 → 404
GET /css/style.css                      → 404
GET /css/main.css                       → 404
GET /js/base1.js                        → 404
GET /assets/js/main.js                  → 404
GET /images/step-3.webp                 → 404
GET /Content/favicon.ico                → 404
```

## 분석 결과

| 항목 | 내용 |
|------|------|
| **유형** | 자동화 봇의 무차별 경로 스캔 (공격 아님) |
| **목적** | 서버에 알려진 취약 웹앱이 있는지 탐색 |
| **대상** | PHP, Java, 중국 플랫폼 등 다양 → 특정 타겟팅 아님 |
| **출처 IP** | 모두 `100.64.0.x` (Railway 내부 프록시 — 실제 IP 확인 불가) |
| **피해** | 없음. 전부 404 응답으로 종료 |
| **빈도** | 인터넷 공개 서버에서 일상적으로 발생 (하루 수십~수백 건) |

## 공격 vs 스캔 구분

- **스캔 (현재 상황):** 존재하지 않는 경로를 무차별로 요청하여 서버 종류 파악 시도. 모두 404로 끝남.
- **공격:** 실제 존재하는 엔드포인트에 SQL injection, 인증 우회, 파라미터 변조 등을 시도. 현재 로그에서는 관찰되지 않음.

## 현재 상태 및 조치

**당장 조치 불필요.** FastAPI 서버는 `/api/v1/` 하위 경로만 라우팅하므로 봇이 찾는 PHP/정적 파일 경로는 존재하지 않음.

### 추후 고려 사항 (필요시)
- Railway 또는 Cloudflare 프록시에서 rate limiting 설정
- `/api/v1/` 외 경로 일괄 차단 미들웨어 추가
- 봇 IP 대역 차단 (Railway 프록시 뒤라 효과 제한적)
- `GET /` 요청에 대한 health check 엔드포인트 추가 (현재 404 반환)
