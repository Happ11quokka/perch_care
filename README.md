<p align="center">
  <a href="https://perch.ai.kr/ko"><img src="assets/images/p.e.r.c.h.svg" width="280" alt="p.e.r.c.h" /></a>
</p>

<h3 align="center">
  <a href="https://perch.ai.kr/ko">perch.ai.kr →</a>
</h3>

<p align="center">
  <b>우리 새의 건강을 숫자로, AI로, 매일의 기록으로.</b><br/>
  체중 · 식사 · 음수량을 기록하면 Bird Health Index가 건강 상태를 알려줍니다.
</p>

<p align="center">
  <a href="https://perch.ai.kr/ko"><img src="https://img.shields.io/badge/Homepage-perch.ai.kr-FF9A42?style=flat-square" alt="Website" /></a>
  <a href="https://apps.apple.com/br/app/%ED%8D%BC%EC%B9%98%EC%BC%80%EC%96%B4/id6758549078"><img src="https://img.shields.io/badge/App%20Store-Download-0D96F6?style=flat-square&logo=apple&logoColor=white" alt="App Store" /></a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.8-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.8-0175C2?style=flat-square&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Material_3-Design-757575?style=flat-square&logo=materialdesign&logoColor=white" alt="Material 3" />
  <img src="https://img.shields.io/badge/FastAPI-009688?style=flat-square&logo=fastapi&logoColor=white" alt="FastAPI" />
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/SQLAlchemy-D71F00?style=flat-square&logo=sqlalchemy&logoColor=white" alt="SQLAlchemy" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/OpenAI-412991?style=flat-square&logo=openai&logoColor=white" alt="OpenAI" />
  <img src="https://img.shields.io/badge/LangChain-1C3C3C?style=flat-square&logo=langchain&logoColor=white" alt="LangChain" />
  <img src="https://img.shields.io/badge/Firebase-DD2C00?style=flat-square&logo=firebase&logoColor=white" alt="Firebase" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=flat-square&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/Railway-0B0D0E?style=flat-square&logo=railway&logoColor=white" alt="Railway" />
  <img src="https://img.shields.io/badge/JWT-000000?style=flat-square&logo=jsonwebtokens&logoColor=white" alt="JWT" />
</p>

<br/>

<p align="center">
  <img src="assets/images/readme/01-hero.png" width="180" alt="Onboarding" />
  &nbsp;
  <img src="assets/images/readme/02-wci.png" width="180" alt="WCI Health Score" />
  &nbsp;
  <img src="assets/images/readme/03-chart.png" width="180" alt="Weight Chart" />
  &nbsp;
  <img src="assets/images/readme/04-chat.png" width="180" alt="AI Chatbot" />
</p>

<br/>

## Features

**Bird Health Index** — 체중(60%) · 식사(25%) · 음수(15%)를 조합한 건강 점수(0-100)를 산출합니다. 성장 단계별로 다른 수식을 적용해 성조와 유조를 구분합니다. [모델 상세 →](docs/BHI.md)

**AI 건강 상담** — OpenAI 기반 RAG 챗봇이 반려조 건강에 대한 질문에 답합니다. 한국어, 영어, 중국어를 지원합니다.

**AI 건강 검진** — 사진 한 장으로 전신, 부위별, 배설물, 먹이 안전성을 분석합니다.

**체중 기록 & 차트** — 하루에 여러 번 체중을 기록하고, 주간 · 월간 · 연간 추이를 차트로 확인합니다.

**식사 & 음수 기록** — 급여량과 섭취량을 구분해 기록하고, 섭취율을 계산합니다.

**푸시 알림** — 오후 5시, 오늘 기록이 없는 사용자에게 FCM 알림을 보냅니다.

**다국어** — 한국어 · English · 中文, 기기 언어에 맞춰 자동 전환됩니다.

<br/>

<p align="center">
  <img src="assets/images/readme/05-vision.png" width="240" alt="AI Health Check" />
</p>

<br/>

## Architecture

```
Flutter App
  Screens → Services → Models
                │
          ┌─────┴─────┐
          │  ApiClient │  LocalCache
          │  (JWT)     │  (SQLite / SharedPref)
          └─────┬─────┘
                │ HTTPS
FastAPI Backend
  Routers → Services → SQLAlchemy Models → PostgreSQL
                │
          OpenAI + LangChain (RAG)
          FCM Daily Reminder Cron
```

21개 서비스 모듈(26 파일)이 cache-first 전략(5분 TTL, 4단계 fallback)으로 동작하며, 21개 화면 모듈(33 파일)이 온보딩부터 건강 분석까지 전체 사용자 여정을 커버합니다.

<br/>

## Tech Stack

| | |
|---|---|
| **Frontend** | Flutter 3.8 · Dart · Material 3 · go_router · fl_chart · sqflite |
| **Backend** | FastAPI · SQLAlchemy · Alembic · PostgreSQL |
| **AI** | OpenAI API · LangChain · RAG |
| **Auth** | JWT (access + refresh) · Google Sign-In · Apple Sign-In |
| **Infra** | Docker · Railway · FCM · Firebase Analytics |

<br/>

## Getting Started

```bash
# Flutter
flutter pub get
cp .env.example .env       # API_BASE_URL 설정
flutter run

# Backend
cd backend
cp .env.example .env       # DATABASE_URL, JWT_SECRET, OPENAI_API_KEY 설정
docker compose up -d
```

OAuth 설정은 [Google Cloud Console](https://console.cloud.google.com)(Google)과 [Apple Developer](https://developer.apple.com)(Apple Sign-In)에서 진행합니다.

<br/>

## Project Structure

```
lib/src/
  ├── config/       환경 설정
  ├── models/       데이터 모델
  ├── router/       go_router 네비게이션
  ├── screens/      26개 화면
  ├── services/     20개 서비스
  ├── theme/        Material 3 디자인 시스템
  └── widgets/      재사용 컴포넌트

backend/app/
  ├── routers/      API 엔드포인트
  ├── services/     비즈니스 로직
  ├── models/       SQLAlchemy 모델
  └── jobs/         크론 작업
```

<br/>

## Download

<p align="center">
  <a href="https://apps.apple.com/br/app/%ED%8D%BC%EC%B9%98%EC%BC%80%EC%96%B4/id6758549078">
    <img src="https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg" width="180" alt="Download on the App Store" />
  </a>
</p>

---

<p align="center">
  <sub>Private project — All rights reserved.</sub>
</p>
