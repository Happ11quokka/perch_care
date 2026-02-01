# Perch Care

AI 기반 반려조 건강 관리 앱 - 체중, 사료, 음수량 데이터를 종합 분석하여 BHI(Bird Health Index) 건강 지수를 산출합니다.

---

## 📄 Project Overview

Perch Care는 반려조(앵무새 등) 보호자를 위한 헬스케어 앱입니다. 일일 건강 기록을 기반으로 자체 설계한 BHI 수학 모델을 통해 건강 상태를 정량화하고, AI 기반 상담 기능을 제공합니다.

### Key Features

- **BHI (Bird Health Index)** - 체중/사료/음수량 기반 건강 지수 산출 (0~100점)
- **체중 관리** - 주간/월간/연간 체중 변화 차트 시각화
- **일일 건강 기록** - 사료 섭취량, 음수량 일일 기록 및 추적
- **AI 백과사전** - OpenAI 기반 반려조 건강 상담
- **소셜 로그인** - Google, Apple, Kakao 로그인 지원

---

## 🧮 BHI (Bird Health Index) 수학 모델

BHI는 반려조의 건강 상태를 정량적으로 평가하기 위해 자체 설계한 복합 점수 모델입니다.

### 전체 구조

```
BHI = WeightScore + FoodScore + WaterScore
         (60점)       (25점)      (15점)     = 0 ~ 100점
```

| 항목 | 배점 | 비중 | 의미 |
|------|------|------|------|
| Weight Score | 60점 | 60% | 체중 변화율 기반 안정성 평가 |
| Food Score | 25점 | 25% | 목표 대비 사료 섭취 충족도 |
| Water Score | 15점 | 15% | 목표 대비 음수량 적정성 |

### Weight Score (0~60점)

성장 단계(growth_stage)에 따라 서로 다른 수식을 적용합니다.

#### 성체(Adult) 단계

7일 전 체중과 비교하여 체중 변화율(WCI)을 산출합니다.

```
WCI_7 = (W_t - W_{t-7}) / W_{t-7}
```

체중 증가와 감소 모두 감점:

```
WeightScore = 60 × (1 - clamp(|WCI_7| / 0.10, 0, 1))
```

- `W_t` : 측정일 체중
- `W_{t-7}` : 7일 전 체중 (±3일 탐색 허용)
- 임계값 0.10 = 10% 이상 변화 시 최저점

#### 후속 성장(Post-Growth) 단계

체중 감소만 감점, 증가는 허용:

```
WCI_7 = (W_t - W_{t-7}) / W_{t-7}
WeightScore = 60 × (1 - clamp(|min(WCI_7, 0)| / 0.10, 0, 1))
```

#### 빠른 성장(Rapid-Growth) 단계

1일 전 체중과 비교하며, 건강한 성장을 보상하는 방식:

```
WCI_1 = (W_t - W_{t-1}) / W_{t-1}
WeightScore = 60 × clamp(min(WCI_1, 0.10) / 0.10, 0, 1)
```

- 일일 10%까지의 성장을 최대 점수로 평가

### Food Score (0~25점)

목표 섭취량 대비 실제 섭취량의 부족분만 감점:

```
Δf = (f_t - f_0) / f_0
FoodScore = 25 × (1 - clamp(|min(Δf, 0)| / 0.30, 0, 1))
```

- `f_t` : 실제 일일 사료 섭취량 (g)
- `f_0` : 목표 일일 사료 섭취량 (g)
- 임계값 0.30 = 30% 이상 부족 시 최저점
- 초과 섭취는 감점하지 않음

### Water Score (0~15점)

목표 대비 과잉과 부족 모두 대칭적으로 감점:

```
Δd = (d_t - d_0) / d_0
WaterScore = 15 × (1 - clamp(|Δd| / 0.40, 0, 1))
```

- `d_t` : 실제 일일 음수량 (ml)
- `d_0` : 목표 일일 음수량 (ml)
- 임계값 0.40 = 40% 이상 벗어나면 최저점

### 임계값 요약

| 파라미터 | 값 | 설명 |
|----------|-----|------|
| 체중 임계값 (성체/후속성장) | 0.10 | 10% 변화 시 만점 → 0점 |
| 체중 임계값 (빠른성장) | 0.10 | 일일 10% 성장이 이상적 최대치 |
| 사료 임계값 | 0.30 | 30% 부족 허용 |
| 음수 임계값 | 0.40 | 40% 편차 허용 |
| 체중 비교 기간 (성체) | 7일 | 주간 체중 변화 추적 |
| 체중 비교 기간 (빠른성장) | 1일 | 일일 성장 추적 |
| 체중 탐색 윈도우 | ±3일 | 비교 체중 검색 허용 범위 |

### WCI Level 매핑

BHI 점수를 사용자 친화적인 5단계 레벨로 변환합니다.

| BHI 점수 | WCI Level | 상태 | 설명 |
|----------|-----------|------|------|
| 81 ~ 100 | 5 | 매우 좋음 | 전반적으로 건강한 상태 |
| 61 ~ 80 | 4 | 좋음 | 안정적인 상태 |
| 41 ~ 60 | 3 | 보통 | 관찰이 필요한 상태 |
| 21 ~ 40 | 2 | 주의 | 식사량/컨디션 점검 필요 |
| 1 ~ 20 | 1 | 위험 | 즉시 관리 필요 |
| 0 | 0 | - | 데이터 부족 |

### Fallback 로직

- 측정일에 데이터가 없으면 가장 최근 기록 날짜로 자동 대체
- 비교 체중이 없으면 ±3일 범위에서 가장 가까운 기록 사용
- 목표값이 0이면 해당 항목 점수 0 처리 (0 나누기 방지)
- 성장 단계 미설정 시 `adult`로 기본 적용

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────┐
│                Flutter App                   │
│  ┌─────────┐ ┌──────────┐ ┌──────────────┐  │
│  │ Screens │ │ Services │ │   Models     │  │
│  │ (UI)    │→│ (API)    │→│ (Data)       │  │
│  └─────────┘ └──────────┘ └──────────────┘  │
└──────────────────┬──────────────────────────┘
                   │ HTTP (JWT)
┌──────────────────▼──────────────────────────┐
│              FastAPI Backend                  │
│  ┌─────────┐ ┌──────────┐ ┌──────────────┐  │
│  │ Routers │→│ Services │→│   Models     │  │
│  │ (API)   │ │ (Logic)  │ │ (SQLAlchemy) │  │
│  └─────────┘ └──────────┘ └──────┬───────┘  │
│                                  │           │
│  ┌───────────────────────────────▼────────┐  │
│  │            PostgreSQL                  │  │
│  └────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### System Workflow

1. 사용자가 앱에서 체중/사료/음수량 데이터를 기록
2. Flutter 앱이 JWT 인증과 함께 FastAPI 백엔드로 데이터 전송
3. 백엔드에서 PostgreSQL에 데이터 저장
4. BHI 요청 시 `bhi_service`가 성장 단계별 수식으로 점수 산출
5. WCI Level로 변환하여 앱에 시각적으로 표시
6. AI 백과사전에서 OpenAI API를 통한 건강 상담 제공

---

## 📁 Project Structure

```
perch_care/
├── lib/
│   ├── main.dart                   # 앱 엔트리포인트
│   └── src/
│       ├── config/                 # 환경 설정
│       ├── models/                 # 데이터 모델
│       ├── router/                 # go_router 네비게이션
│       ├── screens/                # UI 화면
│       │   ├── splash/             #   스플래시
│       │   ├── login/              #   로그인
│       │   ├── signup/             #   회원가입
│       │   ├── home/               #   홈 대시보드
│       │   ├── weight/             #   체중 관리
│       │   ├── food/               #   사료 기록
│       │   ├── water/              #   음수량 기록
│       │   ├── bhi/                #   BHI 건강 지수
│       │   ├── ai_encyclopedia/    #   AI 백과사전
│       │   ├── profile/            #   프로필
│       │   └── ...
│       ├── services/               # API 서비스 계층
│       └── theme/                  # Material 3 테마 시스템
├── backend/
│   ├── app/
│   │   ├── main.py                 # FastAPI 엔트리포인트
│   │   ├── models/                 # SQLAlchemy 모델
│   │   ├── routers/                # API 엔드포인트
│   │   ├── schemas/                # Pydantic 스키마
│   │   └── services/               # 비즈니스 로직 (BHI 산출 등)
│   ├── alembic/                    # DB 마이그레이션
│   ├── Dockerfile
│   └── docker-compose.yml
├── assets/images/                  # 앱 리소스
└── docs/                           # 문서
```

---

## ⚙️ Tech Stack

| 분류 | 기술 |
|------|------|
| **Client** | Flutter (Dart ^3.8.1), Material 3, go_router, fl_chart |
| **Backend** | FastAPI (Python), Alembic |
| **Database** | PostgreSQL, SQLAlchemy, sqflite (로컬) |
| **AI** | OpenAI API, LangChain |
| **Auth** | JWT, Google Sign-In, Apple Sign-In, Kakao SDK |
| **Infra** | Docker, Railway, Nginx |

---

## 🚀 Getting Started

### 요구사항

- Flutter SDK ^3.8.1
- Docker & Docker Compose
- PostgreSQL

### Flutter 앱

```bash
flutter pub get
cp .env.example .env
# .env에서 API_BASE_URL 설정
flutter run
```

### Backend

```bash
cd backend
cp .env.example .env
# .env에서 DATABASE_URL, JWT_SECRET 등 설정
docker compose up -d
```

### OAuth 설정

| 플랫폼 | 설정 위치 |
|--------|----------|
| Google | Google Cloud Console → OAuth 클라이언트 |
| Apple | Apple Developer → Sign in with Apple |
| Kakao | Kakao Developers → 네이티브 앱 키 |

---

## 🧑‍💻 Development

| 명령어 | 설명 |
|--------|------|
| `flutter pub get` | 의존성 설치 |
| `flutter run` | 디버그 모드 실행 |
| `flutter analyze` | 정적 분석 |
| `flutter test` | 테스트 실행 |
| `flutter build apk` | Android APK 빌드 |
| `flutter build ios` | iOS 빌드 |

---

## 📜 License

Private project - All rights reserved
