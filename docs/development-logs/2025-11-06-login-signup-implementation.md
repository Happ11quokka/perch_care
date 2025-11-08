# Flutter 로그인 및 회원가입 화면 구현

**날짜**: 2025-11-06
**파일**:
- [lib/src/screens/login/login_screen.dart](../../lib/src/screens/login/login_screen.dart)
- [lib/src/screens/signup/signup_screen.dart](../../lib/src/screens/signup/signup_screen.dart)
- [lib/src/router/app_router.dart](../../lib/src/router/app_router.dart)

---

## 구현 목표

사용자 인증 플로우의 첫 단계로 로그인과 회원가입 화면을 구현합니다:

1. **로그인 화면**: 드래그 가능한 바텀시트, SNS 로그인 버튼, 회원가입 유도
2. **회원가입 화면**: 이름, 이메일, 비밀번호, 전화번호 입력 폼
3. **네비게이션 연결**: 로그인 ↔ 회원가입 화면 전환
4. **디자인 일관성**: 브랜드 컬러와 그라데이션 버튼 적용

---

## 1. 로그인 화면 구현

### 1.1 전체 화면 구조

로그인 화면은 여러 레이어가 겹쳐진 구조로 설계되었습니다:

```dart
Scaffold
└─ Stack
   ├─ _buildBackgroundCircles()      // 배경 동심원 (3개)
   ├─ _buildGradientCircle()          // 중앙 그라데이션 원
   ├─ _buildMainContent()             // 새, 나무, 브랜드명, 슬로건
   ├─ _buildBottomSheet()             // 드래그 가능한 로그인 시트
   └─ _buildStatusBar()               // 상단 상태바
```

### 1.2 반응형 좌표 계산

디자인 시안(393×852)을 기준으로 모든 좌표를 비율로 변환:

```dart
static const double _designWidth = 393.0;
static const double _designHeight = 852.0;

double w(double value) => (value / _designWidth) * screenWidth;
double h(double value) => (value / _designHeight) * screenSize.height;
```

**장점**:
- 다양한 화면 크기에서 일관된 레이아웃 유지
- 디자인 시안의 픽셀 값을 그대로 사용 가능
- 유지보수 시 비율만 조정하면 됨

### 1.3 배경 동심원 배치

세 개의 SVG 원을 절대 위치로 배치:

```dart
Widget _buildBackgroundCircles() {
  final double circleCenterX = w(200);  // 중심점 X 좌표

  // 가장 큰 링 (Ellipse 120)
  final double largeRingSize = w(622);
  final double largeRingCenterY = h(272);

  // 중간 링 (Ellipse 69)
  final double outerRingSize = w(439);
  final double outerRingCenterY = h(265.5);

  // 작은 링 (Ellipse 68)
  final double middleRingSize = w(268);
  final double middleRingCenterY = h(254);

  return Stack(
    children: [
      Positioned(
        left: circleCenterX - (largeRingSize / 2),
        top: largeRingCenterY - (largeRingSize / 2),
        child: SvgPicture.asset(
          'assets/images/login_vector/Ellipse_120.svg',
          width: largeRingSize,
          height: largeRingSize,
        ),
      ),
      // 나머지 원들...
    ],
  );
}
```

### 1.4 드래그 가능한 바텀시트

사용자가 위로 드래그하면 로그인 폼이 펼쳐지는 인터랙티브한 UI:

```dart
double _sheetHeight = 60.0;  // 초기 높이 (살짝만 보임)
final double _peekHeight = 60.0;
final double _expandedHeight = 428.0;

GestureDetector(
  onVerticalDragUpdate: (details) {
    setState(() {
      _sheetHeight -= details.delta.dy;  // 드래그 양만큼 높이 변경
      _sheetHeight = _sheetHeight.clamp(_peekHeight, _expandedHeight);
    });
  },
  onVerticalDragEnd: (details) {
    // 드래그 속도에 따라 자동으로 접기/펼치기
    if (details.primaryVelocity! < -500) {
      _sheetHeight = _expandedHeight;  // 빠르게 위로 → 펼침
    } else if (details.primaryVelocity! > 500) {
      _sheetHeight = _peekHeight;  // 빠르게 아래로 → 접힘
    } else {
      // 중간 지점 기준 결정
      final midPoint = (_peekHeight + _expandedHeight) / 2;
      _sheetHeight = _sheetHeight > midPoint ? _expandedHeight : _peekHeight;
    }
  },
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    height: _sheetHeight,
    // ...
  ),
)
```

**UX 포인트**:
- 드래그 속도 감지로 사용자 의도 파악 (`primaryVelocity`)
- 중간 지점 기준으로 자동 스냅
- 300ms 부드러운 애니메이션 전환
- 탭으로도 펼침/접힘 토글 가능

### 1.5 SNS 로그인 버튼 (에셋 경로 이슈 해결)

#### 문제 상황
처음에는 SNS 아이콘이 표시되지 않는 문제 발생:

```dart
// ❌ 잘못된 경로
assetPath: 'assets/images/social/google.svg'
```

**원인**:
- 실제 파일은 `assets/images/btn_google/btn_google.svg`에 있음
- `pubspec.yaml`에 해당 폴더가 등록되지 않음

#### 해결 방법

**1단계**: 파일 경로 수정
```dart
// ✅ 올바른 경로
_SocialLoginButtonData(
  assetPath: 'assets/images/btn_google/btn_google.svg',
  semanticLabel: 'Google로 로그인',
  onTap: () {
    // TODO: 구글 로그인 연동
  },
),
```

**2단계**: `pubspec.yaml`에 asset 폴더 등록
```yaml
assets:
  - assets/images/
  - assets/images/login_vector/
  - assets/images/btn_google/
  - assets/images/btn_apple/
  - assets/images/btn_naver/
  - assets/images/btn_kakao/
```

**3단계**: 빌드 캐시 초기화
```bash
flutter clean
```

### 1.6 SNS 버튼 위젯 구조

재사용 가능한 모듈화된 구조:

```dart
class _SocialLoginButtonData {
  const _SocialLoginButtonData({
    required this.assetPath,
    required this.semanticLabel,
    required this.onTap,
  });

  final String assetPath;
  final String semanticLabel;
  final VoidCallback onTap;
}

class _SocialLoginIconButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: data.semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: data.onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(data.assetPath, width: 28, height: 28),
            ),
          ),
        ),
      ),
    );
  }
}
```

**디자인 포인트**:
- 56×56 원형 버튼 (Material Design 터치 타겟 가이드라인)
- 섬세한 그림자로 입체감 표현
- `Semantics` 위젯으로 접근성 지원
- `InkWell`로 머티리얼 리플 효과

### 1.7 텍스트 수정: "아니면..." → "또는"

```dart
const Text(
  '또는',  // 더 간결하고 자연스러운 표현
  style: TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.gray500,
  ),
),
```

---

## 2. 회원가입 화면 구현

### 2.1 전체 구조

```dart
Scaffold
└─ AppBar (뒤로가기 버튼 + 제목)
   └─ SafeArea
      └─ SingleChildScrollView (키보드가 올라와도 스크롤 가능)
         └─ Form
            ├─ 환영 메시지
            ├─ 이름 입력 필드
            ├─ 이메일 입력 필드
            ├─ 비밀번호 입력 필드 (표시/숨김 토글)
            ├─ 전화번호 입력 필드
            ├─ 회원가입 버튼
            └─ 로그인으로 돌아가기 링크
```

### 2.2 Form 유효성 검사

`GlobalKey<FormState>`를 사용한 중앙 집중식 검증:

```dart
final _formKey = GlobalKey<FormState>();

void _handleSignup() {
  if (_formKey.currentState?.validate() ?? false) {
    // TODO: 실제 회원가입 API 연동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원가입이 완료되었습니다!'),
        backgroundColor: AppColors.brandPrimary,
      ),
    );
    context.pop();  // 로그인 화면으로 돌아가기
  }
}
```

### 2.3 입력 필드별 유효성 규칙

#### 이름
```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return '이름을 입력해주세요';
  }
  return null;
}
```

#### 이메일
```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return '이메일을 입력해주세요';
  }
  final emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  if (!emailRegex.hasMatch(value)) {
    return '올바른 이메일 형식을 입력해주세요';
  }
  return null;
}
```

**정규식 설명**:
- `[a-zA-Z0-9._%+-]+`: 이메일 로컬 부분 (@ 앞)
- `@`: 필수 구분자
- `[a-zA-Z0-9.-]+`: 도메인 부분
- `\.[a-zA-Z]{2,}`: 최소 2자 이상의 최상위 도메인 (.com, .kr 등)

#### 비밀번호
```dart
validator: (value) {
  if (value == null || value.isEmpty) {
    return '비밀번호를 입력해주세요';
  }
  if (value.length < 8) {
    return '비밀번호는 8자 이상이어야 합니다';
  }
  return null;
}
```

#### 전화번호
```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return '전화번호를 입력해주세요';
  }
  final phoneRegex = RegExp(r'^01[0-9]-?\d{3,4}-?\d{4}$');
  if (!phoneRegex.hasMatch(value.replaceAll('-', ''))) {
    return '올바른 전화번호 형식을 입력해주세요';
  }
  return null;
}
```

**정규식 설명**:
- `^01[0-9]`: 010, 011, 016, 017, 018, 019 등
- `-?`: 하이픈 선택적 (있어도 되고 없어도 됨)
- `\d{3,4}`: 3~4자리 숫자 (중간 번호)
- `-?`: 하이픈 선택적
- `\d{4}$`: 마지막 4자리

**지원 형식**:
- `01012345678` ✅
- `010-1234-5678` ✅
- `010-123-5678` ✅

### 2.4 비밀번호 표시/숨김 토글

```dart
bool _isPasswordVisible = false;

_buildTextField(
  controller: _passwordController,
  label: '비밀번호',
  hintText: '8자 이상 입력해주세요',
  obscureText: !_isPasswordVisible,  // 보이기 상태에 따라 변경
  suffixIcon: IconButton(
    icon: Icon(
      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
      color: AppColors.gray500,
    ),
    onPressed: () {
      setState(() {
        _isPasswordVisible = !_isPasswordVisible;
      });
    },
  ),
  // ...
),
```

### 2.5 공통 텍스트 필드 헬퍼 메서드

중복 코드를 제거하고 일관된 디자인 적용:

```dart
Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hintText,
  TextInputType? keyboardType,
  bool obscureText = false,
  Widget? suffixIcon,
  String? Function(String?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.nearBlack,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.gray100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.brandPrimary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          // ...
        ),
      ),
    ],
  );
}
```

**디자인 특징**:
- 레이블 + 입력 필드 세트
- 기본 상태: 회색 배경, 테두리 없음
- 포커스 상태: 브랜드 컬러 2px 테두리
- 에러 상태: 빨간색 1px 테두리

---

## 3. 라우팅 구성

### 3.1 라우트 상수 추가

**route_names.dart**:
```dart
class RouteNames {
  RouteNames._();

  static const String splash = 'splash';
  static const String login = 'login';
  static const String signup = 'signup';  // ✅ 추가
  static const String home = 'home';
}
```

**route_paths.dart**:
```dart
class RoutePaths {
  RoutePaths._();

  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';  // ✅ 추가
  static const String home = '/home';
}
```

### 3.2 GoRouter 라우트 등록

**app_router.dart**:
```dart
import '../screens/signup/signup_screen.dart';

static final GoRouter router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      name: RouteNames.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RoutePaths.signup,  // ✅ 추가
      name: RouteNames.signup,
      builder: (context, state) => const SignupScreen(),
    ),
  ],
  // ...
);
```

### 3.3 네비게이션 연결

**로그인 → 회원가입**:
```dart
// login_screen.dart
import 'package:go_router/go_router.dart';
import '../../router/route_names.dart';

TextButton(
  onPressed: () {
    context.pushNamed(RouteNames.signup);  // 회원가입 화면으로 이동
  },
  child: const Text('회원가입'),
),
```

**회원가입 → 로그인**:
```dart
// signup_screen.dart
IconButton(
  icon: const Icon(Icons.arrow_back_ios),
  onPressed: () => context.pop(),  // 뒤로가기
),

// 또는 텍스트 버튼으로
TextButton(
  onPressed: () => context.pop(),
  child: const Text('로그인'),
),
```

**네비게이션 스택**:
```
[Splash] → [Login] → [Signup]
                 ↑         |
                 └─────────┘
                  context.pop()
```

---

## 4. 그라데이션 버튼 재사용

로그인과 회원가입 화면에서 동일한 브랜드 버튼 사용:

```dart
Widget _buildGradientButton({
  required String label,
  required VoidCallback onPressed,
}) {
  final borderRadius = BorderRadius.circular(12);
  return Material(
    color: Colors.transparent,
    borderRadius: borderRadius,
    child: InkWell(
      onTap: onPressed,
      borderRadius: borderRadius,
      child: Ink(
        decoration: ShapeDecoration(
          gradient: const LinearGradient(
            begin: Alignment(0.00, 0.50),
            end: Alignment(1.00, 0.50),
            colors: [Color(0xFFFF9A42), Color(0xFFFF7B29)],  // 브랜드 그라데이션
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          shadows: const [
            BoxShadow(
              color: Color(0x3F000000),
              blurRadius: 4,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: SizedBox(
          height: 50,  // 로그인: 50, 회원가입: 54
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
```

**디자인 요소**:
- 가로 그라데이션 (#FF9A42 → #FF7B29)
- 12px 둥근 모서리
- 아래쪽 그림자 (y: 4px, blur: 4px)
- 흰색 볼드 텍스트
- 터치 리플 효과

---

## 배운 점

### 1. **Asset 관리의 중요성**

Flutter에서 asset을 사용할 때 주의할 점:

1. **파일 경로와 pubspec.yaml 등록이 일치해야 함**
   ```yaml
   # ❌ 이것만으로는 하위 폴더 asset 접근 불가
   assets:
     - assets/images/

   # ✅ 하위 폴더도 명시적으로 등록 필요
   assets:
     - assets/images/
     - assets/images/btn_google/
     - assets/images/btn_apple/
   ```

2. **변경 후 flutter clean 필수**
   - `pubspec.yaml` 변경 시 빌드 캐시 문제 발생 가능
   - `flutter clean` → `flutter run`으로 완전히 재빌드

3. **개발 중 에러 메시지 확인**
   ```
   Unable to load asset: "assets/images/btn_google/btn_google.svg"
   ```
   → 경로나 pubspec.yaml 문제

### 2. **Form 유효성 검사 패턴**

`GlobalKey<FormState>`를 사용하면:
- 여러 필드의 검증을 한 번에 처리
- 에러 메시지 자동 표시
- 깔끔한 코드 구조

```dart
// 모든 필드를 한 번에 검증
if (_formKey.currentState?.validate() ?? false) {
  // 모든 필드가 유효할 때만 실행
}
```

### 3. **정규식 기반 입력 검증**

**이메일**:
- 복잡한 RFC 5322 표준보다는 실용적인 패턴 사용
- 대부분의 일반적인 이메일 형식을 커버

**전화번호**:
- 한국 번호 형식 (010, 011 등)
- 하이픈 있음/없음 모두 허용
- `replaceAll('-', '')`로 전처리 후 검증

### 4. **드래그 제스처 처리**

```dart
onVerticalDragEnd: (details) {
  if (details.primaryVelocity! < -500) {
    // 빠른 위쪽 드래그
  } else if (details.primaryVelocity! > 500) {
    // 빠른 아래쪽 드래그
  }
}
```

- `primaryVelocity`: 드래그 속도 (픽셀/초)
- 음수 = 위쪽, 양수 = 아래쪽
- 임계값(500)으로 "빠른 제스처" 감지

### 5. **TextEditingController 메모리 관리**

```dart
@override
void dispose() {
  _nameController.dispose();
  _emailController.dispose();
  _passwordController.dispose();
  _phoneController.dispose();
  super.dispose();
}
```

- 컨트롤러는 반드시 `dispose()`에서 해제
- 메모리 누수 방지
- 4개의 컨트롤러 → 4번 dispose 호출

### 6. **반응형 레이아웃 설계**

```dart
double w(double value) => (value / _designWidth) * screenWidth;
double h(double value) => (value / _designHeight) * screenSize.height;
```

- 디자인 시안 기준으로 모든 값을 비율로 변환
- 화면 크기 변화에도 일관된 레이아웃
- 유지보수 시 시안 값만 변경하면 됨

### 7. **GoRouter의 네비게이션 메서드**

```dart
context.pushNamed(RouteNames.signup);  // 새 화면 추가 (스택 쌓임)
context.pop();                         // 이전 화면으로
context.go(RoutePaths.login);          // 스택 교체 (뒤로가기 불가)
```

- `pushNamed`: 화면 추가 (뒤로가기 가능)
- `pop`: 현재 화면 제거
- `go`: 특정 경로로 이동 (스택 리셋)

### 8. **접근성 (Accessibility) 고려**

```dart
Semantics(
  button: true,
  label: 'Google로 로그인',
  child: InkWell(...),
)
```

- 스크린 리더 사용자를 위한 레이블
- 버튼임을 명시적으로 알림
- 포괄적인 UX 제공

---

## 파일 구조

```
lib/src/
├── screens/
│   ├── login/
│   │   └── login_screen.dart          (435줄)
│   └── signup/
│       └── signup_screen.dart         (324줄)
├── router/
│   ├── app_router.dart                (signup 라우트 추가)
│   ├── route_names.dart               (signup 상수 추가)
│   └── route_paths.dart               (signup 경로 추가)
└── theme/
    └── colors.dart                    (브랜드 컬러 사용)

assets/images/
├── btn_google/
│   └── btn_google.svg
├── btn_apple/
│   └── btn_apple.svg
├── btn_naver/
│   └── btn_naver.svg
└── btn_kakao/
    └── btn_kakao.svg
```

---

## 다음 단계

### 1. **백엔드 연동**
```dart
// TODO: 로그인 API 연동
void _handleLogin() async {
  final response = await authService.login(
    email: _emailController.text,
    password: _passwordController.text,
  );
  // ...
}

// TODO: 회원가입 API 연동
void _handleSignup() async {
  final response = await authService.register(
    name: _nameController.text,
    email: _emailController.text,
    password: _passwordController.text,
    phone: _phoneController.text,
  );
  // ...
}
```

### 2. **SNS 로그인 연동**
```dart
// TODO: 각 플랫폼 SDK 연동
- Google Sign-In (google_sign_in 패키지)
- Apple Sign-In (sign_in_with_apple 패키지)
- Kakao SDK
- Naver SDK
```

### 3. **상태 관리**
- 로그인 상태 전역 관리 (Provider, Riverpod, Bloc 등)
- 토큰 저장 (flutter_secure_storage)
- 자동 로그인 구현

### 4. **비밀번호 찾기/재설정**
- 이메일 인증 플로우
- 비밀번호 재설정 화면

### 5. **로딩 상태 처리**
```dart
bool _isLoading = false;

void _handleSignup() async {
  setState(() => _isLoading = true);
  try {
    await authService.register(...);
  } finally {
    setState(() => _isLoading = false);
  }
}
```

---

## 결론

✅ **드래그 가능한 로그인 화면** - 인터랙티브한 바텀시트 구현
✅ **SNS 로그인 버튼** - Google, Apple, Naver, Kakao 4개 플랫폼
✅ **회원가입 폼** - 유효성 검사를 포함한 4개 필드
✅ **반응형 디자인** - 다양한 화면 크기 대응
✅ **라우팅 연결** - GoRouter 기반 화면 전환
✅ **일관된 디자인** - 브랜드 컬러와 그라데이션 버튼

사용자 인증 플로우의 기초가 완성되었으며, 백엔드 API만 연동하면 실제 서비스에서 사용 가능한 수준입니다. 🎯
