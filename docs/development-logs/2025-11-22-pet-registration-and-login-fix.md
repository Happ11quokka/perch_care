# 앵무새 등록 기능 구현 및 로그인 Navigator 충돌 해결

**날짜**: 2025-11-22
**파일**:

- [lib/src/screens/pet/pet_add_screen.dart](../../lib/src/screens/pet/pet_add_screen.dart)
- [lib/src/screens/home/home_screen.dart](../../lib/src/screens/home/home_screen.dart)
- [lib/src/screens/weight/weight_add_screen.dart](../../lib/src/screens/weight/weight_add_screen.dart)
- [lib/src/screens/login/login_screen.dart](../../lib/src/screens/login/login_screen.dart)
- [lib/src/router/app_router.dart](../../lib/src/router/app_router.dart)
- [lib/src/router/route_names.dart](../../lib/src/router/route_names.dart)
- [lib/src/router/route_paths.dart](../../lib/src/router/route_paths.dart)

---

## 구현 목표

앵무새 전용 건강 관리 앱에 필요한 핵심 기능을 구현합니다:

1. **앵무새 등록**: 앵무새 정보(이름, 품종, 생년월일, 성별) 입력 및 저장
2. **홈 화면 통합**: PetService와 연동하여 실제 앵무새 데이터 표시
3. **앵무새 선택 기능**: 여러 마리 등록 시 전환 가능
4. **체중 기록 연동**: 앵무새 미등록 시 등록 유도
5. **앵무새 전용 UI**: 모든 문구와 이모지를 앵무새로 특화
6. **로그인 충돌 해결**: Navigator 상태 충돌로 인한 검은 화면 문제 수정

---

## 1. 앵무새 등록 화면 구현

### 1.1 화면 구조

```
AppBar: "앵무새 등록하기"
  ↓
헤더: "소중한 앵무새의 정보를 입력해주세요"
  ↓
이름 입력 (필수)
  ↓
품종 입력 (선택) - "예: 유황앵무, 코뉴어, 사랑앵무, 회색앵무 등"
  ↓
생년월일 선택 (선택) - DatePicker
  ↓
성별 선택 - 수컷/암컷/모름
  ↓
등록 버튼 (Gradient)
```

### 1.2 핵심 코드

#### species 자동 설정 (앵무새 전용)

```dart
class _PetAddScreenState extends State<PetAddScreen> {
  // 앵무새 전용이므로 species는 항상 'bird'로 고정
  final String _selectedSpecies = 'bird';
  String _selectedGender = 'unknown';
  DateTime? _selectedBirthDate;
}
```

**설계 이유**:
- 앵무새 전용 앱이므로 종류 선택 드롭다운 제거
- 사용자는 이름, 품종, 생년월일, 성별만 입력
- UI 간소화로 빠른 등록 프로세스

#### 등록 로직

```dart
Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    await _petService.createPet(
      name: _nameController.text.trim(),
      species: _selectedSpecies, // 항상 'bird'
      breed: _breedController.text.trim().isEmpty
          ? null
          : _breedController.text.trim(),
      birthDate: _selectedBirthDate,
      gender: _selectedGender,
    );

    if (mounted) {
      context.go(RouteNames.home);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_nameController.text.trim()}이(가) 등록되었습니다!'),
          backgroundColor: AppColors.brandPrimary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('등록 중 오류가 발생했습니다: ${e.toString()}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
```

**핵심 포인트**:
- `createPet()` 호출 시 자동으로 기존 앵무새는 비활성화(`isActive = false`)
- 새로 등록한 앵무새가 자동으로 활성 앵무새(`isActive = true`)로 설정
- 등록 완료 후 홈 화면으로 이동하여 바로 사용 가능

---

## 2. 홈 화면 PetService 통합

### 2.1 앵무새 데이터 로드

```dart
class _HomeScreenState extends State<HomeScreen> {
  final _petService = PetService();
  List<Pet> _pets = [];
  Pet? _activePet;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pets = await _petService.getMyPets();
      final activePet = await _petService.getActivePet();

      if (mounted) {
        setState(() {
          _pets = pets;
          _activePet = activePet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
```

### 2.2 앵무새 선택 모달

```dart
void _showPetSelector() {
  if (_pets.isEmpty) {
    // 등록된 앵무새가 없으면 등록 화면으로 이동
    context.pushNamed(RouteNames.petAdd).then((_) => _loadPets());
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 타이틀
            Text(
              '앵무새 선택',
              style: AppTypography.h5.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.nearBlack,
              ),
            ),

            // 앵무새 리스트
            ..._pets.map((pet) => ListTile(
              leading: Text('🦜', style: const TextStyle(fontSize: 24)),
              title: Text(
                pet.name,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: _activePet?.id == pet.id
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: AppColors.nearBlack,
                ),
              ),
              trailing: _activePet?.id == pet.id
                  ? const Icon(Icons.check_circle, color: AppColors.brandPrimary)
                  : null,
              onTap: () async {
                await _petService.setActivePet(pet.id);
                if (mounted) {
                  Navigator.pop(context);
                  _loadPets();
                }
              },
            )),

            // 새 앵무새 추가 버튼
            Divider(color: AppColors.gray200),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: AppColors.brandPrimary),
              ),
              title: Text(
                '새 앵무새 추가',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                context.pushNamed(RouteNames.petAdd).then((_) => _loadPets());
              },
            ),
          ],
        ),
      );
    },
  );
}
```

**UX 설계**:
- 등록된 앵무새 없음 → 바로 등록 화면으로 이동
- 앵무새 1마리 이상 → 모달에서 선택 가능
- 활성 앵무새는 체크 표시 및 굵은 글씨로 강조
- "새 앵무새 추가" 버튼으로 추가 등록 가능

### 2.3 앵무새 셀렉터 UI

```dart
GestureDetector(
  onTap: _showPetSelector,
  child: Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.sm,
    ),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.brandPrimary, width: 2),
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: [
        BoxShadow(
          color: AppColors.brandPrimary.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Text(
          _activePet != null ? '🦜' : '🐾',
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          _activePet?.name ?? '앵무새 추가',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(Icons.arrow_drop_down, size: 24, color: AppColors.brandPrimary),
      ],
    ),
  ),
),
```

**표시 로직**:
- 앵무새 등록됨: 🦜 + 앵무새 이름
- 앵무새 미등록: 🐾 + "앵무새 추가"

---

## 3. 앵무새 전용 UI 특화

### 3.1 변경 사항

#### Pet 등록 화면
```dart
// 제목
'앵무새 등록하기' (기존: '반려동물 등록하기')

// 헤더
'소중한 앵무새의\n정보를 입력해주세요' (기존: '소중한 반려동물의')

// 품종 힌트
'예: 유황앵무, 코뉴어, 사랑앵무, 회색앵무 등' (기존: '예: 유황앵무')

// 종류 선택 드롭다운 완전 제거
```

#### 홈 화면
```dart
// 펫 셀렉터 이모지: 항상 🦜
String _getPetEmoji(String species) {
  return '🦜';
}

// 라벨
'앵무새 추가' (기존: '반려동물 추가')
'앵무새 선택' (기존: '반려동물 선택')
'새 앵무새 추가' (기존: '새 반려동물 추가')

// AI 체크 섹션
Container(
  width: 70,
  height: 70,
  decoration: BoxDecoration(
    color: AppColors.brandPrimary.withValues(alpha: 0.1),
    shape: BoxShape.circle,
  ),
  child: Center(
    child: Text('🦜', style: const TextStyle(fontSize: 40)),
  ),
)
// 기존: 다양한 동물 아바타 4개 (🐶🐱🦜🐹)
```

#### Weight Add 화면
```dart
// 다이얼로그
'앵무새 등록 필요' (기존: '반려동물 등록 필요')
'먼저 앵무새를 등록해야 합니다' (기존: '먼저 반려동물을 등록해야')
```

### 3.2 디자인 일관성

**앵무새 아이콘**: 🦜
- 홈 화면 펫 셀렉터
- 앵무새 선택 모달
- AI 체크 섹션

**브랜드 컬러**: #FF9A42
- 앵무새 아바타 배경 (alpha: 0.1)
- 버튼 gradient
- 테두리 및 강조 요소

---

## 4. 로그인 Navigator 충돌 해결

### 4.1 문제 상황

**증상**:
```
1. 로그인 화면에서 이메일/비밀번호 입력 후 로그인 버튼 클릭
2. 검은 화면으로 전환되거나 Navigator 에러 발생
```

**에러 로그**:
```
Exception caught by widgets library
'package:flutter/src/widgets/navigator.dart': Failed assertion: line 4064 pos 12:
'!_debugLocked': is not true.
```

### 4.2 원인 분석

```dart
// 문제가 있던 코드
Future<void> _handleEmailLogin() async {
  // ...
  await _authService.signInWithEmailPassword(...);

  if (!mounted) return;
  Navigator.of(context).pop(); // 바텀시트 닫기
  context.goNamed(RouteNames.home); // 홈으로 이동
}
```

**원인**:
- `Navigator.pop()`과 `context.goNamed()`를 연속으로 호출
- 두 네비게이션 작업이 동시에 일어나면서 Navigator 상태 충돌
- Flutter Navigator는 한 번에 하나의 네비게이션만 처리 가능

### 4.3 해결 방법

```dart
Future<void> _handleEmailLogin() async {
  FocusScope.of(context).unfocus();
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoginLoading = true);

  try {
    await _authService.signInWithEmailPassword(
      email: _loginEmailController.text.trim(),
      password: _loginPasswordController.text,
    );

    if (!mounted) return;

    // ⭐ 1. 바텀시트 먼저 닫기
    Navigator.of(context).pop();

    // ⭐ 2. 100ms 지연으로 Navigator 상태 안정화
    await Future.delayed(const Duration(milliseconds: 100));

    // ⭐ 3. 그 다음 홈 화면으로 이동
    if (!mounted) return;
    context.goNamed(RouteNames.home);

  } on AuthException catch (e) {
    // 에러 처리...
  }
}
```

**핵심 개선**:
1. **순차적 네비게이션**: pop → 지연 → goNamed
2. **100ms 지연**: Navigator 상태가 안정화될 시간 제공
3. **mounted 재확인**: 지연 후 위젯이 여전히 마운트되어 있는지 확인

### 4.4 에러 메시지 개선

```dart
} on AuthException catch (e) {
  if (!mounted) return;

  String errorMessage = e.message;

  // 사용자 친화적인 한글 메시지로 변환
  if (e.message.contains('Invalid login credentials')) {
    errorMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
  } else if (e.message.contains('Email not confirmed')) {
    errorMessage = '이메일 인증이 필요합니다. 이메일을 확인해주세요.';
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage)),
  );
} catch (e) {
  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}')),
  );
}
```

**개선 효과**:
- "Invalid login credentials" → "이메일 또는 비밀번호가 올바르지 않습니다."
- "Email not confirmed" → "이메일 인증이 필요합니다. 이메일을 확인해주세요."
- 사용자가 이해하기 쉬운 한글 메시지

---

## 5. 체중 기록 연동

### 5.1 앵무새 미등록 시 처리

```dart
// WeightAddScreen
Future<void> _onSave() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  if (_activePetId == null) {
    // 앵무새 등록 유도 다이얼로그
    final shouldNavigate = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          '앵무새 등록 필요',
          style: AppTypography.h5.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
          ),
        ),
        content: Text(
          '체중을 기록하려면 먼저 앵무새를 등록해야 합니다.\n지금 등록하시겠습니까?',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.mediumGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.brandPrimary.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: Text(
              '등록하기',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldNavigate == true && mounted) {
      context.pushNamed(RouteNames.petAdd).then((result) {
        _loadActivePet();
      });
    }
    return;
  }

  // 체중 저장 로직...
}
```

**UX 흐름**:
1. 체중 저장 시도
2. 앵무새 미등록 감지
3. 친절한 다이얼로그 표시
4. "등록하기" 클릭 → 앵무새 등록 화면
5. 등록 완료 후 돌아오면 자동으로 활성 앵무새 로드
6. 다시 체중 저장 가능

---

## 6. 라우팅 설정

### 6.1 Route 추가

#### route_paths.dart
```dart
class RoutePaths {
  static const String petAdd = '/pet/add';
}
```

#### route_names.dart
```dart
class RouteNames {
  static const String petAdd = 'pet-add';
}
```

#### app_router.dart
```dart
GoRoute(
  path: RoutePaths.petAdd,
  name: RouteNames.petAdd,
  builder: (context, state) => const PetAddScreen(),
),
```

### 6.2 전체 라우트 구조

```
/ (Splash)
├─ /login (Login)
├─ /signup (Signup)
├─ /home (Home)
│   └─ 앵무새 셀렉터 → /pet/add
├─ /weight-detail (Weight Detail)
│   ├─ /weight/add/today → WeightAddScreen
│   └─ /weight/add/:date → WeightAddScreen
│       └─ 앵무새 미등록 → /pet/add
└─ /pet/add (Pet Add) ⭐ 신규
```

---

## 7. 데이터 흐름

### 7.1 앵무새 등록 흐름

```
1. 홈 화면 진입
   ↓
2. _loadPets() 호출
   ↓
3. PetService.getMyPets() → 빈 리스트
   ↓
4. 펫 셀렉터 표시: "🐾 앵무새 추가"
   ↓
5. 사용자 클릭 → _showPetSelector()
   ↓
6. _pets.isEmpty 감지 → context.pushNamed(RouteNames.petAdd)
   ↓
7. 앵무새 정보 입력 (이름, 품종, 생년월일, 성별)
   ↓
8. "등록하기" 클릭 → _submitForm()
   ↓
9. PetService.createPet(species: 'bird', ...)
   - Supabase에 저장
   - isActive = true 자동 설정
   ↓
10. context.go(RouteNames.home)
    ↓
11. 홈 화면 재진입 → _loadPets()
    ↓
12. 앵무새 데이터 로드 완료
    ↓
13. 펫 셀렉터 업데이트: "🦜 사랑이"
```

### 7.2 체중 기록 연동 흐름

```
1. Weight Detail 화면에서 체중 기록 시도
   ↓
2. WeightAddScreen → _loadActivePet()
   ↓
3. PetService.getActivePet() → null
   ↓
4. _activePetId == null 감지
   ↓
5. 다이얼로그 표시: "앵무새 등록 필요"
   ↓
6. "등록하기" 클릭 → Pet Add Screen
   ↓
7. 앵무새 등록 완료
   ↓
8. Weight Add Screen 복귀 → _loadActivePet() 재호출
   ↓
9. PetService.getActivePet() → Pet 객체 반환
   ↓
10. _activePetId 설정 완료
    ↓
11. 체중 저장 가능
```

---

## 8. 배운 점

### 8.1 Navigator 순차 작업의 중요성

**문제**:
```dart
Navigator.pop(context);
context.goNamed(RouteNames.home); // 즉시 실행 → 충돌!
```

**해결**:
```dart
Navigator.pop(context);
await Future.delayed(const Duration(milliseconds: 100));
if (!mounted) return;
context.goNamed(RouteNames.home);
```

**원리**:
- Flutter Navigator는 상태 머신 기반
- 한 번에 하나의 전환만 처리 가능
- `_debugLocked` 플래그로 동시 작업 방지
- 100ms 지연으로 이전 작업 완료 대기

### 8.2 mounted 체크의 중요성

```dart
await someAsyncOperation();

if (!mounted) return; // ⭐ 필수!
context.goNamed(...);
```

**이유**:
- 비동기 작업 중 사용자가 뒤로가기 누를 수 있음
- 위젯이 트리에서 제거되면 `mounted = false`
- unmounted 위젯에서 네비게이션/setState 호출 시 에러

### 8.3 사용자 친화적 에러 메시지

**Before**:
```
Invalid login credentials
```

**After**:
```
이메일 또는 비밀번호가 올바르지 않습니다.
```

**구현**:
```dart
String errorMessage = e.message;
if (e.message.contains('Invalid login credentials')) {
  errorMessage = '이메일 또는 비밀번호가 올바르지 않습니다.';
}
```

### 8.4 앱 특화 UI의 중요성

**일반 반려동물 앱**:
- 종류 선택: 강아지/고양이/앵무새/햄스터
- 복잡한 입력 폼
- 다양한 동물 이모지

**앵무새 전용 앱**:
- 종류 자동 설정: `species = 'bird'`
- 간소화된 폼 (이름, 품종만 주로 입력)
- 일관된 🦜 이모지
- 앵무새에 특화된 품종 예시

**장점**:
- 빠른 등록 프로세스
- 명확한 앱 정체성
- 타겟 사용자에게 집중된 UX

### 8.5 Modal Bottom Sheet UX

```dart
showModalBottomSheet(
  context: context,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
  ),
  builder: (context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min, // ⭐ 중요!
        children: [...]
      ),
    );
  },
);
```

**핵심**:
- `mainAxisSize: MainAxisSize.min`: 내용물 크기만큼만 차지
- `SafeArea`: 노치/홈 인디케이터 영역 회피
- 상단 둥근 모서리로 시트임을 명확히 표현
- 드래그 핸들로 닫을 수 있음을 암시

---

## 9. 다음 단계 및 개선 사항

### 9.1 앵무새 프로필 관리

```dart
// 앵무새 상세 정보 화면
class PetDetailScreen extends StatelessWidget {
  final Pet pet;

  // 표시 정보:
  // - 프로필 사진 (추가 예정)
  // - 이름, 품종, 생년월일, 성별
  // - 등록일, 나이 계산
  // - 체중 변화 그래프
  // - AI 건강 체크 이력

  // 기능:
  // - 정보 수정
  // - 삭제 (확인 다이얼로그)
}
```

### 9.2 앵무새 사진 등록

```dart
// image_picker 패키지 사용
Future<void> _pickImage() async {
  final ImagePicker picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 800,
    imageQuality: 85,
  );

  if (image != null) {
    // Supabase Storage에 업로드
    final imageUrl = await _uploadToSupabase(image);
    // Pet 모델에 profileImageUrl 저장
  }
}
```

### 9.3 앵무새별 건강 통계

```dart
class PetHealthStats {
  final String petId;
  final double avgWeight;
  final int totalWeightRecords;
  final int totalHealthChecks;
  final DateTime lastCheckDate;

  // 표시:
  // - 평균 체중
  // - 최근 30일 체중 변화율
  // - AI 건강 체크 횟수
  // - 마지막 체크 날짜
}
```

### 9.4 다중 앵무새 빠른 전환

```dart
// 홈 화면 상단에 Chip 리스트
Row(
  children: _pets.map((pet) =>
    FilterChip(
      label: Text(pet.name),
      selected: pet.id == _activePet?.id,
      onSelected: (_) => _setActivePet(pet.id),
    )
  ).toList(),
)
```

### 9.5 앵무새 초대 기능

```dart
// 다른 사용자와 앵무새 공유
class PetShare {
  // 초대 코드 생성
  String generateInviteCode(String petId);

  // 초대 수락
  Future<void> acceptInvite(String inviteCode);

  // 권한 관리: owner, editor, viewer
}
```

---

## 결론

✅ **앵무새 등록 기능** - 간소화된 폼으로 빠른 등록
✅ **홈 화면 통합** - PetService와 연동하여 실제 데이터 표시
✅ **앵무새 선택** - 여러 마리 등록 시 모달로 전환
✅ **체중 기록 연동** - 앵무새 미등록 시 친절한 유도
✅ **앵무새 전용 UI** - 모든 문구와 이모지 앵무새로 특화
✅ **로그인 충돌 해결** - Navigator 순차 작업으로 안정화
✅ **에러 메시지 개선** - 사용자 친화적인 한글 메시지

앵무새 전용 건강 관리 앱의 핵심 기능이 완성되었으며, 사진 등록, 건강 통계, 다중 앵무새 관리 등으로 확장 가능한 구조를 갖추었습니다. 🦜
