# Perch Care 프로젝트 전체 분석 보고서

**작성일**: 2026-01-08
**프로젝트 버전**: 현재 개발 중
**분석 도구**: Claude Code

---

## 목차

1. [프로젝트 개요](#1-프로젝트-개요)
2. [프로젝트 구조](#2-프로젝트-구조)
3. [모델 분석](#3-모델-분석)
4. [서비스 분석](#4-서비스-분석)
5. [라우터 분석](#5-라우터-분석)
6. [스크린 분석](#6-스크린-분석)
7. [위젯 분석](#7-위젯-분석)
8. [데이터베이스 연동 현황](#8-데이터베이스-연동-현황)
9. [발견된 문제점](#9-발견된-문제점)
10. [개선 로드맵](#10-개선-로드맵)
11. [프로젝트 건강도 점수](#11-프로젝트-건강도-점수)

---

## 1. 프로젝트 개요

### 1.1 프로젝트 설명

**Perch Care**는 반려동물(특히 앵무새) 건강 관리를 위한 Flutter 애플리케이션입니다. AI 기반 건강 체크, 체중 추적, 식이/음수 기록, 일정 관리 등의 기능을 제공합니다.

### 1.2 기술 스택

| 구분 | 기술 |
|------|------|
| **Framework** | Flutter 3.x |
| **Language** | Dart |
| **Backend** | Supabase (Auth, Database, Storage) |
| **State Management** | setState (기본) |
| **Navigation** | go_router ^14.6.2 |
| **Charts** | fl_chart ^0.68.0 |
| **AI API** | Perplexity API |

### 1.3 주요 기능

- 사용자 인증 (이메일/OAuth)
- 반려동물 프로필 관리
- 체중 기록 및 차트 시각화
- 식이/음수 기록
- AI 건강 체크 (이미지 분석)
- AI 백과사전 (챗봇)
- 일정 관리
- 알림 시스템

---

## 2. 프로젝트 구조

### 2.1 디렉토리 구조

```
lib/
├── main.dart                          # 앱 진입점
└── src/
    ├── config/                        # 환경 설정 (2 files)
    │   ├── app_config.dart           # 앱 설정 상수
    │   └── environment.dart          # 환경변수 접근자
    │
    ├── models/                        # 데이터 모델 (6 files)
    │   ├── pet.dart                  # 반려동물 모델
    │   ├── weight_record.dart        # 체중 기록 모델
    │   ├── daily_record.dart         # 일일 기록 모델
    │   ├── ai_health_check.dart      # AI 건강 체크 모델
    │   ├── notification.dart         # 알림 모델
    │   └── schedule_record.dart      # 일정 모델
    │
    ├── router/                        # 라우팅 (3 files)
    │   ├── app_router.dart           # GoRouter 설정
    │   ├── route_names.dart          # 라우트 이름 상수
    │   └── route_paths.dart          # 라우트 경로 상수
    │
    ├── screens/                       # UI 화면 (23 screens)
    │   ├── splash/                   # 스플래시
    │   ├── onboarding/               # 온보딩
    │   ├── login/                    # 로그인
    │   ├── signup/                   # 회원가입
    │   ├── forgot_password/          # 비밀번호 찾기 (3 screens)
    │   ├── home/                     # 홈
    │   ├── pet/                      # 펫 관리 (2 screens)
    │   ├── weight/                   # 체중 관리 (4 screens)
    │   ├── food/                     # 식이 기록
    │   ├── water/                    # 음수 기록
    │   ├── wci/                      # 체형 지수
    │   ├── notification/             # 알림
    │   ├── profile/                  # 프로필 (2 screens)
    │   ├── profile_setup/            # 프로필 설정 (2 screens)
    │   └── ai_encyclopedia/          # AI 백과사전
    │
    ├── services/                      # 비즈니스 로직 (7 files)
    │   ├── auth/
    │   │   └── auth_service.dart     # 인증 서비스
    │   ├── pet/
    │   │   ├── pet_service.dart      # 펫 CRUD 서비스
    │   │   └── pet_local_cache_service.dart  # 펫 로컬 캐시
    │   ├── weight/
    │   │   └── weight_service.dart   # 체중 서비스
    │   ├── daily_record/
    │   │   └── daily_record_service.dart  # 일일 기록 서비스
    │   ├── health_check/
    │   │   └── health_check_service.dart  # 건강 체크 서비스
    │   └── ai_encyclopedia/
    │       └── ai_encyclopedia_service.dart  # AI 백과사전 서비스
    │
    ├── theme/                         # 디자인 시스템 (7 files)
    │   ├── app_theme.dart            # 테마 설정
    │   ├── colors.dart               # 색상 팔레트
    │   ├── typography.dart           # 타이포그래피
    │   ├── spacing.dart              # 간격
    │   ├── radius.dart               # 테두리 반경
    │   ├── shadows.dart              # 그림자
    │   └── icons.dart                # 아이콘
    │
    └── widgets/                       # 재사용 위젯 (5 files)
        ├── bottom_nav_bar.dart       # 하단 네비게이션
        ├── add_schedule_bottom_sheet.dart  # 일정 추가 시트
        ├── analog_time_picker.dart   # 아날로그 시간 선택
        ├── progress_ring.dart        # 진행률 링
        └── dashed_border.dart        # 점선 테두리
```

### 2.2 파일 통계

| 디렉토리 | 파일 수 | 설명 |
|----------|---------|------|
| models/ | 6 | 데이터 모델 |
| services/ | 7 | 비즈니스 로직 |
| screens/ | 23 | UI 화면 |
| widgets/ | 5 | 재사용 위젯 |
| router/ | 3 | 라우팅 설정 |
| theme/ | 7 | 디자인 시스템 |
| config/ | 2 | 환경 설정 |
| **총계** | **53** | - |

---

## 3. 모델 분석

### 3.1 모델 구현 현황

| 모델 | 파일 | fromJson | toJson | toInsertJson | copyWith | DB 연동 |
|------|------|:--------:|:------:|:------------:|:--------:|:-------:|
| Pet | `pet.dart` | ✅ | ✅ | ✅ | ✅ | ✅ |
| WeightRecord | `weight_record.dart` | ✅ | ✅ | ✅ | ✅ | ✅ |
| DailyRecord | `daily_record.dart` | ✅ | ✅ | ✅ | ✅ | ✅ |
| AiHealthCheck | `ai_health_check.dart` | ✅ | ✅ | ✅ | ✅ | ✅ |
| AppNotification | `notification.dart` | ✅ | ✅ | ❌ | ✅ | ⚠️ |
| ScheduleRecord | `schedule_record.dart` | ❌ | ❌ | ❌ | ❌ | ❌ |

### 3.2 모델별 상세 분석

#### 3.2.1 Pet 모델 (완전 구현)

```dart
// lib/src/models/pet.dart
class Pet {
  final String id;
  final String userId;
  final String name;
  final String species;      // 'parrot', 'dog', 'cat' 등
  final String? breed;       // 품종
  final DateTime? birthDate;
  final String? gender;      // 'male', 'female', 'unknown'
  final String? profileImageUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**DB 테이블 매핑**: `public.pets` - 완벽 매핑

#### 3.2.2 WeightRecord 모델 (완전 구현)

```dart
// lib/src/models/weight_record.dart
class WeightRecord {
  final String? id;
  final String petId;
  final DateTime date;       // recorded_date
  final double weight;       // 그램 단위
  final String? memo;
}
```

**DB 테이블 매핑**: `public.weight_records` - 완벽 매핑

#### 3.2.3 DailyRecord 모델 (완전 구현)

```dart
// lib/src/models/daily_record.dart
class DailyRecord {
  final String? id;
  final String petId;
  final DateTime recordedDate;
  final String? notes;
  final String? mood;           // 'great', 'good', 'normal', 'bad', 'sick'
  final int? activityLevel;     // 1-5
}
```

**DB 테이블 매핑**: `public.daily_records` - 완벽 매핑

#### 3.2.4 AiHealthCheck 모델 (완전 구현)

```dart
// lib/src/models/ai_health_check.dart
class AiHealthCheck {
  final String? id;
  final String petId;
  final String checkType;       // 'eye', 'skin', 'posture', 'oral', 'ear', 'general'
  final String? imageUrl;
  final Map<String, dynamic> result;
  final double? confidenceScore;  // 0-100
  final String status;          // 'normal', 'warning', 'danger'
  final DateTime checkedAt;
}
```

**DB 테이블 매핑**: `public.ai_health_checks` - 완벽 매핑

#### 3.2.5 AppNotification 모델 (부분 구현)

```dart
// lib/src/models/notification.dart
class AppNotification {
  final String id;
  final NotificationType type;  // reminder, healthWarning, system
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
}
```

**문제점**:
- `toInsertJson` 메서드 없음
- `user_id`, `pet_id` 필드 누락
- 서비스 클래스 없음

**DB 테이블 매핑**: `public.notifications` - 부분 매핑

#### 3.2.6 ScheduleRecord 모델 (미구현) ⚠️

```dart
// lib/src/models/schedule_record.dart
class ScheduleRecord {
  final String petId;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final Color color;           // ❌ JSON 직렬화 불가
  final int? reminderMinutes;
}
```

**심각한 문제점**:
- `id` 필드 없음
- `fromJson` / `toJson` 메서드 없음
- `Color` 타입은 JSON 직렬화 불가능
- 서비스 클래스 없음
- DB 연동 전혀 없음

**DB 테이블 매핑**: `public.schedules` - 매핑 안됨

---

## 4. 서비스 분석

### 4.1 서비스 구현 현황

| 서비스 | 파일 | CREATE | READ | UPDATE | DELETE | 상태 |
|--------|------|:------:|:----:|:------:|:------:|------|
| AuthService | `auth_service.dart` | ✅ | ✅ | ✅ | ✅ | 완전 |
| PetService | `pet_service.dart` | ✅ | ✅ | ✅ | ✅ | 완전 |
| WeightService | `weight_service.dart` | ✅ | ✅ | ✅ | ✅ | 완전 |
| DailyRecordService | `daily_record_service.dart` | ✅ | ✅ | ✅ | ✅ | 완전 |
| HealthCheckService | `health_check_service.dart` | ✅ | ✅ | ❌ | ✅ | 부분 |
| AiEncyclopediaService | `ai_encyclopedia_service.dart` | - | ✅ | - | - | 완전 |
| PetLocalCacheService | `pet_local_cache_service.dart` | ✅ | ✅ | ✅ | ❌ | 부분 |
| **NotificationService** | 없음 | ❌ | ❌ | ❌ | ❌ | **미구현** |
| **ScheduleService** | 없음 | ❌ | ❌ | ❌ | ❌ | **미구현** |

### 4.2 서비스별 상세 분석

#### 4.2.1 AuthService (완전 구현)

```dart
// lib/src/services/auth/auth_service.dart
class AuthService {
  // 회원가입
  Future<AuthResponse> signUp({email, password, nickname});

  // 로그인
  Future<AuthResponse> signInWithEmail({email, password});
  Future<void> signInWithGoogle();
  Future<void> signInWithApple();

  // 로그아웃
  Future<void> signOut();

  // 비밀번호 재설정
  Future<void> resetPassword(email);

  // 현재 사용자
  User? get currentUser;
  Stream<AuthState> get authStateChanges;
}
```

#### 4.2.2 PetService (완전 구현)

```dart
// lib/src/services/pet/pet_service.dart
class PetService {
  Future<Pet> createPet(Pet pet);
  Future<List<Pet>> fetchPets();
  Future<Pet?> fetchActivePet();
  Future<void> updatePet(Pet pet);
  Future<void> deletePet(String id);
  Future<void> setActivePet(String id);
}
```

#### 4.2.3 WeightService (완전 구현 + 캐싱)

```dart
// lib/src/services/weight/weight_service.dart
class WeightService {
  // Supabase CRUD
  Future<WeightRecord> createRecord(WeightRecord record);
  Future<List<WeightRecord>> fetchRecords({petId, startDate, endDate});
  Future<void> updateRecord(WeightRecord record);
  Future<void> deleteRecord(String id);

  // 로컬 캐시
  Future<List<WeightRecord>> fetchLocalRecords({petId});
  Future<void> saveLocalRecords(List<WeightRecord> records);
  void clearCache();
}
```

**특이사항**: 메모리 캐시 + SharedPreferences 혼용

#### 4.2.4 DailyRecordService (완전 구현)

```dart
// lib/src/services/daily_record/daily_record_service.dart
class DailyRecordService {
  Future<DailyRecord> upsertRecord(DailyRecord record);
  Future<DailyRecord?> fetchRecord({petId, date});
  Future<List<DailyRecord>> fetchRecordsByMonth({petId, year, month});
  Future<List<DailyRecord>> fetchRecordsByRange({petId, startDate, endDate});
  Future<void> deleteRecord(String id);
}
```

#### 4.2.5 HealthCheckService (부분 구현)

```dart
// lib/src/services/health_check/health_check_service.dart
class HealthCheckService {
  Future<AiHealthCheck> createCheck(AiHealthCheck check);
  Future<List<AiHealthCheck>> fetchChecks({petId, checkType});
  Future<AiHealthCheck?> fetchLatestCheck({petId, checkType});
  Future<void> deleteCheck(String id);
  Future<String> uploadImage(File file, {petId});

  // ❌ UPDATE 메서드 없음
}
```

#### 4.2.6 AiEncyclopediaService (완전 구현)

```dart
// lib/src/services/ai_encyclopedia/ai_encyclopedia_service.dart
class AiEncyclopediaService {
  Future<String> askQuestion(String question, {Pet? pet});
  // Perplexity API 연동
}
```

### 4.3 누락된 서비스

#### NotificationService (필요)

```dart
// 필요한 메서드
class NotificationService {
  Future<void> createNotification(AppNotification notification);
  Future<List<AppNotification>> fetchNotifications({userId});
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Future<void> deleteNotification(String id);
  Future<int> getUnreadCount();
  Stream<List<AppNotification>> subscribeToNotifications();
}
```

#### ScheduleService (필요)

```dart
// 필요한 메서드
class ScheduleService {
  Future<ScheduleRecord> createSchedule(ScheduleRecord schedule);
  Future<List<ScheduleRecord>> fetchSchedules({petId, date, month});
  Future<void> updateSchedule(ScheduleRecord schedule);
  Future<void> deleteSchedule(String id);
  Future<List<ScheduleRecord>> getTodaySchedules({petId});
}
```

---

## 5. 라우터 분석

### 5.1 라우트 목록

| 라우트 이름 | 경로 | 스크린 | 상태 |
|-------------|------|--------|------|
| splash | `/` | SplashScreen | ✅ |
| onboarding | `/onboarding` | OnboardingScreen | ✅ |
| login | `/login` | LoginScreen | ✅ |
| emailLogin | `/email-login` | EmailLoginScreen | ✅ |
| signup | `/signup` | SignupScreen | ✅ |
| forgotPasswordMethod | `/forgot-password/method` | ForgotPasswordMethodScreen | ✅ |
| forgotPasswordCode | `/forgot-password/code` | ForgotPasswordCodeScreen | ✅ |
| forgotPasswordReset | `/forgot-password/reset` | ForgotPasswordResetScreen | ✅ |
| profileSetup | `/profile-setup` | ProfileSetupScreen | ✅ |
| profileSetupComplete | `/profile-setup/complete` | ProfileSetupCompleteScreen | ✅ |
| home | `/home` | HomeScreen | ✅ |
| petAdd | `/pet/add` | PetAddScreen | ✅ |
| petProfile | `/pet/profile` | PetProfileScreen | ✅ |
| weightDetail | `/weight-detail` | WeightDetailScreen | ✅ |
| weightChart | `/weight/chart` | WeightChartScreen | ✅ |
| weightAdd | `/weight/add/:date` | WeightAddScreen | ✅ |
| weightRecord | `/weight/record` | WeightRecordScreen | ✅ |
| foodRecord | `/food/record` | FoodRecordScreen | ✅ |
| waterRecord | `/water/record` | WaterRecordScreen | ✅ |
| wciIndex | `/wci-index` | WciIndexScreen | ✅ |
| notification | `/notification` | NotificationScreen | ✅ |
| profile | `/profile` | ProfileScreen | ✅ |
| petProfileDetail | `/pet-profile-detail` | PetProfileDetailScreen | ✅ |
| aiEncyclopedia | `/ai-encyclopedia` | AiEncyclopediaScreen | ✅ |

### 5.2 라우트 정합성 문제

| 문제 | 설명 | 해결 방안 |
|------|------|----------|
| 명명 불일치 | `/weight-detail` vs `/weight/chart` | REST 스타일로 통일 |
| 삭제된 라우트 | `biometricComplete` route_names에서만 제거 | route_paths에서도 확인 필요 |

### 5.3 라우트 파일 구조

```dart
// lib/src/router/route_names.dart
class RouteNames {
  static const String splash = 'splash';
  static const String home = 'home';
  // ... 24개 라우트 이름
}

// lib/src/router/route_paths.dart
class RoutePaths {
  static const String splash = '/';
  static const String home = '/home';
  // ... 24개 라우트 경로
}

// lib/src/router/app_router.dart
final GoRouter router = GoRouter(
  initialLocation: RoutePaths.splash,
  routes: [...],
);
```

---

## 6. 스크린 분석

### 6.1 스크린 구현 현황

| 스크린 | 파일 | 구현도 | 문제점 |
|--------|------|:------:|--------|
| SplashScreen | `splash_screen.dart` | 100% | - |
| OnboardingScreen | `onboarding_screen.dart` | 100% | - |
| LoginScreen | `login_screen.dart` | 100% | - |
| EmailLoginScreen | `email_login_screen.dart` | 100% | - |
| SignupScreen | `signup_screen.dart` | 100% | - |
| HomeScreen | `home_screen.dart` | 90% | 일부 하드코딩 |
| WeightDetailScreen | `weight_detail_screen.dart` | 95% | 기본값 하드코딩 |
| WeightChartScreen | `weight_chart_screen.dart` | 100% | - |
| WeightAddScreen | `weight_add_screen.dart` | 90% | 무게 범위 하드코딩 |
| WeightRecordScreen | `weight_record_screen.dart` | 100% | - |
| NotificationScreen | `notification_screen.dart` | 70% | 서비스 연동 없음 |
| AiEncyclopediaScreen | `ai_encyclopedia_screen.dart` | 100% | - |
| **PetAddScreen** | `pet_add_screen.dart` | **50%** | TODO 3개 |
| **PetProfileScreen** | `pet_profile_screen.dart` | **40%** | 더미 데이터 |
| **ProfileScreen** | `profile_screen.dart` | **60%** | 더미 데이터 |
| **FoodRecordScreen** | `food_record_screen.dart` | **60%** | 저장 로직 없음 |
| **WaterRecordScreen** | `water_record_screen.dart` | **60%** | 저장 로직 없음 |
| **ForgotPasswordCodeScreen** | `forgot_password_code_screen.dart` | **30%** | API 미연동 |
| **ForgotPasswordResetScreen** | `forgot_password_reset_screen.dart` | **30%** | API 미연동 |
| ProfileSetupScreen | `profile_setup_screen.dart` | 80% | 사진 선택 미구현 |
| ProfileSetupCompleteScreen | `profile_setup_complete_screen.dart` | 90% | 기본값 하드코딩 |
| PetProfileDetailScreen | `pet_profile_detail_screen.dart` | 85% | 이미지 업로드 미구현 |
| WciIndexScreen | `wci_index_screen.dart` | 80% | - |

### 6.2 심각한 문제가 있는 스크린

#### 6.2.1 PetProfileScreen (더미 데이터 사용)

```dart
// lib/src/screens/pet/pet_profile_screen.dart:23-40
final List<Map<String, dynamic>> pets = [
  {
    'id': '1',
    'name': '점점이',
    'species': '종이름넣어줘요',
    'age': '3년 1개월 23일',
    'gender': 'male',
  },
  {
    'id': '2',
    'name': '콩이',
    'species': '종이름넣어줘요',
    'age': '1년 5개월 2일',
    'gender': 'female',
  },
];
```

**문제**: 실제 DB 데이터 대신 하드코딩된 더미 데이터 표시

#### 6.2.2 PetAddScreen (TODO 항목)

```dart
// lib/src/screens/pet/pet_add_screen.dart
// TODO: petId가 있으면 기존 데이터 로드
// TODO: 실제 저장 로직 구현
// TODO: 이미지 선택 기능 구현
```

#### 6.2.3 FoodRecordScreen / WaterRecordScreen

- 로컬 상태만 관리
- Supabase 저장/로드 없음
- 앱 재시작 시 데이터 손실

### 6.3 하드코딩된 값 목록

| 파일 | 라인 | 값 | 설명 |
|------|------|-----|------|
| `weight_detail_screen.dart` | 30 | `'사랑이'` | 기본 펫 이름 |
| `weight_add_screen.dart` | - | `40-90` | 무게 선택 범위 |
| `water_record_screen.dart` | - | `270` | 일일 목표 음수량 |
| `profile_setup_complete_screen.dart` | - | `'점점이'` | 기본 펫 이름 |
| `pet_profile_screen.dart` | 23-40 | 더미 배열 | 펫 목록 |

---

## 7. 위젯 분석

### 7.1 위젯 목록

| 위젯 | 파일 | 라인 수 | 용도 | 상태 |
|------|------|---------|------|------|
| BottomNavBar | `bottom_nav_bar.dart` | ~92 | 하단 네비게이션 바 | ✅ 완전 |
| AddScheduleBottomSheet | `add_schedule_bottom_sheet.dart` | ~640 | 일정 추가 바텀시트 | ✅ 완전 |
| AnalogTimePicker | `analog_time_picker.dart` | ~300 | 아날로그 시간 선택기 | ✅ 완전 |
| ProgressRing | `progress_ring.dart` | ~80 | 원형 진행률 표시 | ✅ 완전 |
| DashedBorder | `dashed_border.dart` | ~70 | 점선 테두리 | ✅ 완전 |

### 7.2 BottomNavBar 구조

```dart
// lib/src/widgets/bottom_nav_bar.dart
class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  // 4개 탭: 홈, 기록, 건강, 마이페이지
  // 중앙에 + 버튼 (일정 추가)
}
```

### 7.3 AddScheduleBottomSheet 구조

```dart
// lib/src/widgets/add_schedule_bottom_sheet.dart
class AddScheduleBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final String? petId;
  final Function(ScheduleRecord) onSave;
}

// 기능:
// - 시작/종료 날짜 선택
// - 시작/종료 시간 선택 (아날로그 피커)
// - 제목 입력
// - 색상 선택
// - 알림 설정
```

---

## 8. 데이터베이스 연동 현황

### 8.1 Supabase 테이블 구조

| 테이블 | RLS | 모델 | 서비스 | 상태 |
|--------|:---:|------|--------|------|
| profiles | ✅ | (AuthService 내부) | AuthService | ✅ |
| pets | ✅ | Pet | PetService | ✅ |
| weight_records | ✅ | WeightRecord | WeightService | ✅ |
| daily_records | ✅ | DailyRecord | DailyRecordService | ✅ |
| ai_health_checks | ✅ | AiHealthCheck | HealthCheckService | ✅ |
| food_records | ✅ | - | - | ❌ 미연동 |
| water_records | ✅ | - | - | ❌ 미연동 |
| **schedules** | ✅ | ScheduleRecord | - | ❌ **미연동** |
| **notifications** | ✅ | AppNotification | - | ❌ **미연동** |
| wci_records | ✅ | - | - | ⚠️ 부분 |

### 8.2 Storage 버킷

| 버킷 | 용도 | 연동 상태 |
|------|------|----------|
| pet-images | 펫 프로필 이미지 | ✅ 연동 |
| health-check-images | AI 건강 체크 이미지 | ✅ 연동 |
| avatars | 사용자 프로필 이미지 | ⚠️ 부분 연동 |
| wci-images | 체형 지수 이미지 | ⚠️ 부분 연동 |

### 8.3 DB 함수

| 함수 | 용도 | 사용 여부 |
|------|------|----------|
| get_monthly_weight_averages | 월별 체중 평균 | ❌ 미사용 |
| get_weekly_weight_data | 주간 체중 데이터 | ❌ 미사용 |
| get_weight_change_rate | 체중 변화율 | ❌ 미사용 |
| get_daily_summary | 일일 요약 (캘린더) | ❌ 미사용 |
| get_pet_health_stats | 펫 건강 통계 | ❌ 미사용 |
| get_unread_notification_count | 읽지 않은 알림 수 | ❌ 미사용 |
| get_today_schedules | 오늘 일정 | ❌ 미사용 |

**참고**: DB 함수들이 생성되어 있지만 Flutter 앱에서 아직 사용하지 않음

---

## 9. 발견된 문제점

### 9.1 CRITICAL (즉시 해결 필요)

| # | 문제 | 영향도 | 파일 |
|---|------|--------|------|
| 1 | ScheduleRecord DB 연동 없음 | 높음 | `schedule_record.dart` |
| 2 | NotificationService 미구현 | 높음 | 서비스 파일 없음 |
| 3 | PetProfileScreen 더미 데이터 | 높음 | `pet_profile_screen.dart:23-40` |
| 4 | PetAddScreen 저장 로직 TODO | 높음 | `pet_add_screen.dart` |

### 9.2 HIGH (우선 처리 필요)

| # | 문제 | 영향도 | 파일 |
|---|------|--------|------|
| 5 | FoodRecordScreen 저장 없음 | 중간 | `food_record_screen.dart` |
| 6 | WaterRecordScreen 저장 없음 | 중간 | `water_record_screen.dart` |
| 7 | ForgotPassword 플로우 미완성 | 중간 | `forgot_password_*.dart` |
| 8 | ProfileSetup 사진 선택 미구현 | 중간 | `profile_setup_screen.dart` |

### 9.3 MEDIUM (개선 권장)

| # | 문제 | 영향도 | 설명 |
|---|------|--------|------|
| 9 | 하드코딩된 기본값 | 낮음 | 여러 스크린에 산재 |
| 10 | 라우트 명명 불일치 | 낮음 | `/weight-detail` vs `/weight/chart` |
| 11 | HealthCheckService UPDATE 없음 | 낮음 | 기록 수정 불가 |
| 12 | DB 함수 미사용 | 낮음 | 7개 함수 생성만 됨 |

### 9.4 LOW (리팩토링)

| # | 문제 | 설명 |
|---|------|------|
| 13 | 상태 관리 전략 없음 | setState만 사용 |
| 14 | 에러 처리 미흡 | catch에서 무시하는 경우 많음 |
| 15 | 타입 안전성 부족 | Map<String, dynamic> 많이 사용 |

---

## 10. 개선 로드맵

### Phase 1: CRITICAL (1-2주)

```
Week 1:
├── Day 1-2: ScheduleRecord 모델 수정
│   ├── fromJson/toJson 추가
│   ├── Color를 hex string으로 변환
│   └── id 필드 추가
│
├── Day 3-4: ScheduleService 구현
│   ├── CRUD 메서드 구현
│   └── weight_detail_screen 연동
│
└── Day 5-7: NotificationService 구현
    ├── 모델에 toInsertJson 추가
    ├── 서비스 CRUD 구현
    └── notification_screen 연동

Week 2:
├── Day 1-2: PetProfileScreen 수정
│   ├── 더미 데이터 제거
│   └── PetService 연동
│
└── Day 3-5: PetAddScreen 완성
    ├── 기존 데이터 로드 구현
    ├── 저장 로직 구현
    └── 이미지 업로드 연동
```

### Phase 2: HIGH (2-3주)

```
Week 3:
├── FoodRecordScreen DB 연동
├── WaterRecordScreen DB 연동
└── food_records/water_records 모델 생성

Week 4:
├── ForgotPassword 플로우 완성
│   ├── 이메일 발송 API 연동
│   ├── 코드 검증 API 연동
│   └── 비밀번호 재설정 API 연동
│
└── ProfileSetup 완성
    ├── 사진 선택 기능
    └── 프로필 저장 로직
```

### Phase 3: MEDIUM (3-4주)

```
Week 5-6:
├── 하드코딩 값 설정화
├── 라우트 명명 통일
├── HealthCheckService UPDATE 추가
├── DB 함수 활용
│   ├── get_monthly_weight_averages 사용
│   ├── get_daily_summary 사용
│   └── get_unread_notification_count 사용
```

### Phase 4: LOW (진행 중)

```
지속적:
├── 상태 관리 도입 (Provider/Riverpod)
├── 에러 처리 개선
├── 로딩 상태 표시
├── 오프라인 지원
└── 테스트 코드 작성
```

---

## 11. 프로젝트 건강도 점수

### 11.1 종합 점수: 58/100

```
┌─────────────────────────────────────────────────────────┐
│                    프로젝트 건강도                        │
├─────────────────────────────────────────────────────────┤
│ ████████████████████████████░░░░░░░░░░░░░░░░░  58%     │
└─────────────────────────────────────────────────────────┘
```

### 11.2 항목별 점수

| 항목 | 점수 | 상세 |
|------|:----:|------|
| 모델 구현도 | 80/100 | ScheduleRecord 제외 시 완전 |
| 서비스 구현도 | 70/100 | 2개 서비스 누락 |
| 스크린 구현도 | 55/100 | 9개 미완성 |
| 라우터 정합성 | 85/100 | 소소한 명명 불일치 |
| 위젯 품질 | 80/100 | 잘 구현됨 |
| 에러 처리 | 40/100 | 개선 필요 |
| 코드 구조화 | 50/100 | 상태 관리 전략 없음 |
| 문서화 | 60/100 | TODO 주석 많음 |

### 11.3 강점

- ✅ 명확한 디렉토리 구조
- ✅ 일관된 모델링 패턴
- ✅ Supabase RLS 적용
- ✅ Material 3 디자인 시스템
- ✅ go_router 적용

### 11.4 약점

- ❌ 2개 핵심 서비스 미구현
- ❌ 9개 스크린 미완성
- ❌ 하드코딩 데이터 산재
- ❌ 상태 관리 전략 부재
- ❌ 에러 처리 미흡

---

## 부록

### A. 주요 파일 경로

```
# CRITICAL 수정 필요
lib/src/models/schedule_record.dart
lib/src/screens/pet/pet_profile_screen.dart
lib/src/screens/pet/pet_add_screen.dart

# HIGH 수정 필요
lib/src/screens/food/food_record_screen.dart
lib/src/screens/water/water_record_screen.dart
lib/src/screens/forgot_password/

# 생성 필요
lib/src/services/schedule/schedule_service.dart
lib/src/services/notification/notification_service.dart
lib/src/models/food_record.dart
lib/src/models/water_record.dart
```

### B. 환경 설정

```
# .env 파일 필수 항목
SUPABASE_URL=https://qqutjrtciivyfscmnktp.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
PERPLEXITY_API_KEY=<your-api-key>  # AI 백과사전용
```

### C. 참고 문서

- [Supabase 설정 가이드](docs/backend/setup_supabase.md)
- [개발 로그](docs/development-logs/)
- [CLAUDE.md](CLAUDE.md) - 프로젝트 가이드

---

**문서 작성**: Claude Code
**마지막 업데이트**: 2026-01-08
