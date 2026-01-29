---
name: flutter-development
description: |
  perch_care Flutter 앱 개발 가이드. 다음 작업 시 사용:
  - 위젯 구현, 화면 개발, UI 수정
  - go_router 네비게이션, Material 3 테마
  - 상태 관리, 비동기 패턴, 성능 최적화
  - Codex 리뷰 결과의 Flutter 앱 관련 이슈 수정
allowed-tools: Bash, Read, Write, Edit, AskUserQuestion
---

# Flutter Development - perch_care

## Overview

perch_care 프로젝트의 Flutter 앱 개발 가이드. Material 3 디자인 시스템, go_router 네비게이션, FastAPI 백엔드 연동 패턴을 다룹니다.

## When to Use

- 화면(Screen) 구현 및 수정 시
- 위젯 개발 및 UI 버그 수정 시
- go_router 라우팅 추가/변경 시
- 비동기 데이터 로딩, 상태 관리 시
- Codex 코드 리뷰 결과 중 Flutter 관련 이슈 수정 시

## Project Architecture

```
lib/src/
├── config/          # 환경 설정 (environment.dart, app_config.dart)
├── models/          # 데이터 모델 (pet.dart, weight_record.dart 등)
├── router/          # go_router (app_router.dart, route_names.dart, route_paths.dart)
├── screens/         # 화면별 디렉토리
│   ├── splash/      # 스플래시
│   ├── login/       # 로그인/회원가입
│   ├── home/        # 홈 대시보드
│   ├── pet/         # 펫 등록/수정
│   ├── profile/     # 프로필
│   ├── weight/      # 체중 기록
│   ├── food/        # 사료 기록
│   ├── water/       # 음수 기록
│   └── notification/ # 알림
├── services/        # API/비즈니스 로직 서비스
├── theme/           # 디자인 시스템 (colors, typography, spacing 등)
└── widgets/         # 공용 위젯 (bottom_nav_bar, dashed_border 등)
```

## Instructions

### 1. 화면 구현 패턴

모든 화면은 `StatefulWidget`을 기본으로 하며, 다음 구조를 따릅니다:

```dart
class ExampleScreen extends StatefulWidget {
  const ExampleScreen({super.key});

  @override
  State<ExampleScreen> createState() => _ExampleScreenState();
}

class _ExampleScreenState extends State<ExampleScreen> {
  // 서비스 인스턴스
  final _petCache = PetLocalCacheService();

  // 상태
  bool _isLoading = true;
  String? _activePetId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final pet = await _petCache.getActivePet();
      if (!mounted) return;  // ← 필수: async 후 mounted 체크
      setState(() {
        _activePetId = pet?.id;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}
```

### 2. 비동기 안전 패턴 (mounted 체크)

**모든 `await` 후 `setState` 전에 `mounted` 체크 필수:**

```dart
// 올바른 패턴
Future<void> _handleAction() async {
  setState(() => _isLoading = true);
  try {
    final result = await _service.fetchData();
    if (!mounted) return;  // ← 필수
    setState(() {
      _data = result;
    });
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('오류: $e')),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

### 3. 네비게이션 (go_router)

```dart
// 라우트 상수 사용
import '../../router/route_names.dart';
import '../../router/route_paths.dart';

// Named navigation
context.pushNamed(RouteNames.petAdd);
context.goNamed(RouteNames.home);

// Extra 데이터 전달
context.pushNamed(
  RouteNames.forgotPasswordCode,
  extra: {'method': 'email', 'destination': email},
);

// 뒤로가기 안전 처리
void _handleBack() {
  if (context.canPop()) {
    context.pop();
    return;
  }
  context.goNamed(RouteNames.home);
}
```

### 4. 테마 시스템 사용

```dart
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../theme/spacing.dart';

// 색상
AppColors.brandPrimary    // #FF9A42 (주 브랜드 색상)
AppColors.nearBlack       // 텍스트
AppColors.mediumGray      // 보조 텍스트
AppColors.lightGray       // 배경/구분선
AppColors.white           // 배경

// 그라데이션 버튼 패턴
Container(
  height: 60,
  decoration: BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
    ),
    borderRadius: BorderRadius.circular(16),
  ),
)

// 폰트 (Pretendard)
TextStyle(
  fontFamily: 'Pretendard',
  fontSize: 16,
  fontWeight: FontWeight.w500,
  letterSpacing: -0.4,
)
```

### 5. 보안 스토리지 패턴

```dart
// 민감 데이터: flutter_secure_storage 사용
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final _secureStorage = const FlutterSecureStorage();
await _secureStorage.write(key: 'token', value: token);
final token = await _secureStorage.read(key: 'token');

// 비민감 데이터: SharedPreferences 사용
import 'package:shared_preferences/shared_preferences.dart';

final prefs = await SharedPreferences.getInstance();
await prefs.setString('key', value);
```

### 6. 공통 위젯 활용

```dart
// 공용 DashedBorder 위젯 사용 (화면 내 중복 구현 금지)
import '../../widgets/dashed_border.dart';

DashedBorder(
  radius: 20,
  color: Color(0xFF97928A),
  strokeWidth: 1,
  dashWidth: 6,
  dashGap: 4,
  child: Container(/* content */),
)

// 하단 네비게이션 바
import '../../widgets/bottom_nav_bar.dart';

const BottomNavBar(currentIndex: 0)  // 0: 홈, 1: 기록, 2: 프로필
```

### 7. 데이터 저장 시 주의사항

```dart
// 서버 저장과 로컬 캐시를 함께 업데이트
Future<void> _handleSave() async {
  // 1. 서버에 저장 (PetService 등)
  final savedPet = await _petService.createPet(name: name, ...);

  // 2. 로컬 캐시도 업데이트
  await _petCache.upsertPet(
    PetProfileCache(id: savedPet.id, name: savedPet.name, ...),
    setActive: true,
  );
}

// 편집 시 기존 ID 유지 (새 ID 생성 금지)
final petId = _existingPetId ?? DateTime.now().millisecondsSinceEpoch.toString();
```

### 8. 입력 검증 패턴

```dart
// petId 검증
if (widget.petId == null || widget.petId!.isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('펫을 먼저 선택해 주세요.')),
  );
  return;
}

// 시간 검증
if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('종료 시간이 시작 시간보다 이후여야 합니다.')),
  );
  return;
}
```

### 9. 성능 최적화

```dart
// 빌드마다 재계산되는 값은 캐싱
Map<DateTime, double>? _cachedAverages;

Map<DateTime, double> _calculateAverages() {
  if (_cachedAverages != null) return _cachedAverages!;
  // ... 계산 로직
  _cachedAverages = result;
  return result;
}

// 데이터 변경 시 캐시 무효화
setState(() {
  _records = newRecords;
  _cachedAverages = null;
});
```

## Codex 리뷰에서 발견된 주요 패턴

이전 Codex 리뷰에서 반복적으로 발견된 이슈입니다. 새 코드 작성 시 주의:

| 패턴 | 올바른 방법 |
|------|------------|
| async 후 setState | `if (!mounted) return;` 체크 필수 |
| 민감 데이터 저장 | `flutter_secure_storage` 사용 |
| API 키 클라이언트 포함 | 서버 프록시를 통해 호출 |
| 입력 필드 저장 누락 | 모든 입력값이 save 로직에 반영되는지 확인 |
| 위젯 중복 구현 | `lib/src/widgets/` 공용 위젯 우선 확인 |
| 하드코딩 목록 | 동적 생성 (월 목록, 연도 등) |
| 편집 시 새 ID 생성 | 기존 ID 유지, 없을 때만 신규 생성 |
| 토글 UI 가시성 | 선택/미선택 상태 모두 시각적 구분 |

## Best Practices

### DO
- `super.key` 사용 (Key? key 대신)
- `const` 생성자 적극 활용
- `SafeArea`로 시스템 UI 영역 처리
- `dispose()`에서 컨트롤러 정리
- SVG는 `flutter_svg`, PNG은 `Image.asset()` 사용

### DON'T
- 상태바/홈 인디케이터 직접 구현 (시스템 UI)
- `build()` 내에서 네트워크 호출
- 화면 단위로 중복 위젯 구현 (공용 위젯 확인)
- `mounted` 체크 없이 async 후 UI 업데이트
- 하드코딩된 날짜/월/연도 목록 사용
