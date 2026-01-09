# Supabase Database Setup Guide

## 실행 순서

Supabase 대시보드 > SQL Editor에서 다음 순서대로 실행하세요:

```
1. migrations/001_create_tables.sql    - 테이블 생성
2. migrations/002_rls_policies.sql     - RLS 보안 정책
3. migrations/003_storage_buckets.sql  - 스토리지 버킷
4. migrations/004_functions.sql        - DB 함수
```

## 테이블 구조

### 1. profiles (사용자 프로필)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | auth.users와 연결 |
| nickname | VARCHAR(100) | 닉네임 |
| avatar_url | TEXT | 프로필 이미지 URL |
| country | VARCHAR(100) | 국가 |
| created_at | TIMESTAMPTZ | 생성일 |
| updated_at | TIMESTAMPTZ | 수정일 |

### 2. pets (반려동물)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| user_id | UUID (FK) | 소유자 |
| name | VARCHAR(100) | 이름 |
| species | VARCHAR(50) | 종류 (parrot, dog, cat) |
| breed | VARCHAR(100) | 품종 |
| birth_date | DATE | 생년월일 |
| gender | VARCHAR(20) | 성별 |
| profile_image_url | TEXT | 프로필 이미지 |
| is_active | BOOLEAN | 현재 선택된 펫 |

### 3. weight_records (체중 기록)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| pet_id | UUID (FK) | 펫 ID |
| recorded_date | DATE | 기록 날짜 |
| weight | DECIMAL | 체중 (그램) |
| memo | TEXT | 메모 |

### 4. daily_records (일일 건강 기록)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| pet_id | UUID (FK) | 펫 ID |
| recorded_date | DATE | 기록 날짜 |
| notes | TEXT | 노트 |
| mood | VARCHAR(20) | 기분 상태 |
| activity_level | INT | 활동량 (1-5) |

### 5. ai_health_checks (AI 건강 체크)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| pet_id | UUID (FK) | 펫 ID |
| check_type | VARCHAR(50) | 체크 타입 |
| image_url | TEXT | 이미지 URL |
| result | JSONB | AI 분석 결과 |
| confidence_score | DECIMAL | 신뢰도 (0-100) |
| status | VARCHAR(20) | 상태 |
| checked_at | TIMESTAMPTZ | 체크 시간 |

### 6. food_records (음식 기록)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| pet_id | UUID (FK) | 펫 ID |
| recorded_date | DATE | 기록 날짜 |
| recorded_time | TIME | 기록 시간 |
| meal_type | VARCHAR(20) | 식사 유형 |
| food_name | VARCHAR(200) | 음식 이름 |
| amount | DECIMAL | 양 (그램) |
| notes | TEXT | 메모 |

### 7. water_records (음수 기록)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| pet_id | UUID (FK) | 펫 ID |
| recorded_date | DATE | 기록 날짜 |
| recorded_time | TIME | 기록 시간 |
| amount | DECIMAL | 양 (ml) |
| notes | TEXT | 메모 |

### 8. schedules (일정)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| pet_id | UUID (FK) | 펫 ID |
| title | VARCHAR(200) | 제목 |
| description | TEXT | 설명 |
| start_time | TIMESTAMPTZ | 시작 시간 |
| end_time | TIMESTAMPTZ | 종료 시간 |
| color | VARCHAR(10) | 색상 (hex) |
| reminder_minutes | INT | 알림 (분 전) |

### 9. notifications (알림)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| user_id | UUID (FK) | 사용자 ID |
| pet_id | UUID (FK) | 펫 ID (선택) |
| type | VARCHAR(50) | 알림 타입 |
| title | VARCHAR(200) | 제목 |
| message | TEXT | 메시지 |
| is_read | BOOLEAN | 읽음 여부 |

### 10. wci_records (체형 지수)
| 컬럼 | 타입 | 설명 |
|------|------|------|
| id | UUID (PK) | |
| pet_id | UUID (FK) | 펫 ID |
| recorded_date | DATE | 기록 날짜 |
| wci_score | DECIMAL | 체형 지수 |
| status | VARCHAR(20) | 상태 |
| image_url | TEXT | 이미지 URL |
| notes | TEXT | 메모 |

## Storage 버킷

| 버킷 | 용도 | 크기 제한 |
|------|------|-----------|
| pet-images | 펫 프로필 이미지 | 5MB |
| health-check-images | AI 건강 체크 이미지 | 10MB |
| avatars | 사용자 프로필 이미지 | 2MB |
| wci-images | 체형 지수 이미지 | 10MB |

## DB 함수

| 함수 | 설명 |
|------|------|
| get_monthly_weight_averages | 월별 체중 평균 조회 |
| get_weekly_weight_data | 주간 체중 데이터 조회 |
| get_weight_change_rate | 체중 변화율 계산 |
| get_daily_summary | 일일 기록 요약 (캘린더용) |
| get_pet_health_stats | 펫 건강 통계 |
| get_unread_notification_count | 읽지 않은 알림 개수 |
| get_today_schedules | 오늘 일정 조회 |

## RLS 정책 요약

모든 테이블에 Row Level Security가 적용되어 있습니다:
- 사용자는 자신의 데이터만 조회/수정/삭제 가능
- 펫 관련 데이터는 펫의 소유자만 접근 가능
- Storage 파일은 자신의 폴더에만 업로드 가능
