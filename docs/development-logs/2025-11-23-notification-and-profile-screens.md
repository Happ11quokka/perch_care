# Flutter 알림 및 프로필 화면 구현

**날짜**: 2025-11-23
**파일**:
- [lib/src/screens/notification/notification_screen.dart](../../lib/src/screens/notification/notification_screen.dart)
- [lib/src/screens/profile/profile_screen.dart](../../lib/src/screens/profile/profile_screen.dart)

## 구현 목표

홈 화면의 알림 버튼과 프로필 버튼에 실제 기능을 연결하고, 다음 요구사항을 만족하는 화면을 구현합니다:

### 알림 화면
1. **더미 데이터**: 3가지 타입의 알림 (기록 리마인더, 건강 경고, 시스템 알림)
2. **읽음 상태**: 읽음/읽지 않음 상태를 시각적으로 구분
3. **상대 시간**: "방금 전", "N분 전", "N시간 전" 등으로 표시
4. **타입별 디자인**: 알림 타입마다 다른 아이콘과 색상

### 프로필 화면
1. **사용자 정보**: Supabase에서 가져온 사용자 정보 표시
2. **섹션 구조**: 계정, 일반, 정보 섹션으로 구분
3. **앱 필수 메뉴**: 설정, FAQ, 약관, 로그아웃 등
4. **일관된 디자인**: 현재 앱 스타일 유지

---

## 핵심 구현 방법

### 1. 알림 모델 및 타입 시스템

알림 데이터를 체계적으로 관리하기 위한 모델 구조:

```dart
enum NotificationType {
  reminder,        // 기록 리마인더
  healthWarning,   // 건강 경고
  system,          // 시스템 알림
}

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  // 타입별 아이콘과 색상 자동 반환
  IconData get icon { ... }
  Color get iconColor { ... }
}
```

**핵심 포인트**:
- `enum`으로 알림 타입을 명확하게 정의
- `getter`를 통해 타입별 UI 속성 자동 제공
- `copyWith` 패턴으로 불변성 유지하며 상태 업데이트

---

### 2. 더미 데이터 생성기

실제 서비스 연동 전 테스트를 위한 더미 데이터:

```dart
class NotificationData {
  static List<AppNotification> getDummyNotifications({String petName = '초코'}) {
    final now = DateTime.now();

    return [
      AppNotification(
        id: '1',
        type: NotificationType.reminder,
        title: '기록 리마인더',
        message: '$petName 오늘 기록을 해주세요!',
        timestamp: now.subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      AppNotification(
        id: '2',
        type: NotificationType.healthWarning,
        title: '체중 이상 감지',
        message: '현재 기록 데이터를 통해 24일 체중부터 이상한 것 같아요',
        timestamp: now.subtract(const Duration(days: 1)),
        isRead: false,
      ),
      AppNotification(
        id: '3',
        type: NotificationType.system,
        title: '앱 업데이트',
        message: '앱이 업데이트되었습니다. 새로운 기능을 확인해보세요!',
        timestamp: now.subtract(const Duration(days: 3)),
        isRead: true,
      ),
    ];
  }
}
```

**데이터 특징**:
- **동적 pet 이름**: 실제 반려동물 이름으로 개인화 가능
- **다양한 시간대**: 2시간 전, 1일 전, 3일 전 등 다양한 케이스
- **읽음 상태 혼합**: 테스트를 위해 읽음/읽지 않음 상태 모두 포함

---

### 3. 읽음 상태 시각화

읽지 않은 알림을 강조하는 디자인:

```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppRadius.lg),
    border: notification.isRead
        ? null
        : Border(
            left: BorderSide(
              color: AppColors.brandPrimary,
              width: 4,
            ),
          ),
    boxShadow: [...],
  ),
  child: Padding(
    padding: EdgeInsets.only(
      left: notification.isRead ? AppSpacing.lg : AppSpacing.md,
      // 왼쪽 테두리가 있으면 패딩 조정
      ...
    ),
    child: Row(
      children: [
        // 내용...
        if (!notification.isRead)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  ),
)
```

**시각적 구분 요소**:
- **왼쪽 테두리**: 읽지 않은 알림에만 4px 주황색 선 표시
- **패딩 조정**: 테두리가 있을 때 왼쪽 패딩을 줄여 정렬 유지
- **원형 배지**: 제목 옆에 작은 주황색 점 표시

---

### 4. 상대 시간 계산

사용자 친화적인 시간 표시:

```dart
String _getTimeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inMinutes < 1) {
    return '방금 전';
  } else if (difference.inHours < 1) {
    return '${difference.inMinutes}분 전';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}시간 전';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}일 전';
  } else {
    final year = timestamp.year;
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    return '$year.$month.$day';
  }
}
```

**시간 표시 규칙**:
- 1분 미만: "방금 전"
- 1시간 미만: "N분 전"
- 24시간 미만: "N시간 전"
- 7일 미만: "N일 전"
- 7일 이상: "YYYY.MM.DD" 형식

**intl 패키지 미사용 이유**:
- 프로젝트에 `intl` 의존성이 없음
- 간단한 날짜 포맷팅은 기본 Dart 기능으로 충분
- 의존성 추가 없이 가벼운 구현

---

### 5. 프로필 섹션 구조

설정 항목을 논리적 그룹으로 분류:

```dart
Widget _buildSection({
  required String title,
  required List<_MenuItem> items,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 섹션 제목
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Text(title, style: ...),
      ),
      const SizedBox(height: AppSpacing.sm),

      // 메뉴 항목들 (흰색 카드)
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [...],
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (context, index) => Divider(...),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(...);
          },
        ),
      ),
    ],
  );
}
```

**섹션 구성**:
1. **계정**: 계정 정보, 비밀번호 변경, 회원 탈퇴
2. **일반**: 알림 설정, 언어 설정, 테마 설정
3. **정보**: FAQ, 이용약관, 개인정보 처리방침, 버전 정보

**디자인 특징**:
- 회색 배경에 흰색 카드로 섹션 구분
- `Divider`로 메뉴 항목 구분
- `shrinkWrap: true`로 스크롤 충돌 방지

---

### 6. Supabase 사용자 정보 로드

인증된 사용자 정보 가져오기:

```dart
final AuthService _authService = AuthService();
String _userName = '사용자';
String _userEmail = 'user@example.com';

Future<void> _loadUserInfo() async {
  final user = _authService.currentUser;
  if (user != null) {
    setState(() {
      _userEmail = user.email ?? 'user@example.com';
      _userName = user.userMetadata?['name'] ?? '사용자';
    });
  }
}
```

**데이터 소스**:
- `user.email`: Supabase Auth의 이메일 주소
- `user.userMetadata?['name']`: 회원가입 시 저장한 사용자 이름
- Null safety로 기본값 제공

**확장 가능성**:
- 향후 `profiles` 테이블 추가 시 추가 정보 로드 가능
- 프로필 사진 URL, 생년월일 등 확장

---

### 7. 로그아웃 확인 다이얼로그

사용자 실수 방지를 위한 확인 절차:

```dart
Future<void> _handleLogout() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('로그아웃'),
      content: const Text('로그아웃 하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
          ),
          child: const Text('로그아웃'),
        ),
      ],
    ),
  );

  if (confirmed == true && mounted) {
    try {
      await _authService.signOut();
      if (!mounted) return;
      context.goNamed(RouteNames.login);
    } catch (e) {
      // 에러 처리...
    }
  }
}
```

**안전 장치**:
- `confirmed == true` 체크로 명시적 확인
- `mounted` 체크로 비동기 후 위젯 생명주기 확인
- 에러 발생 시 SnackBar로 사용자에게 알림
- 로그아웃 성공 시 로그인 화면으로 이동

---

## 라우팅 설정

### 라우트 상수 추가

**route_names.dart**:
```dart
class RouteNames {
  static const String notification = 'notification';
  static const String profile = 'profile';
}
```

**route_paths.dart**:
```dart
class RoutePaths {
  static const String notification = '/notification';
  static const String profile = '/profile';
}
```

### 라우터 설정

**app_router.dart**:
```dart
GoRoute(
  path: RoutePaths.notification,
  name: RouteNames.notification,
  builder: (context, state) => const NotificationScreen(),
),
GoRoute(
  path: RoutePaths.profile,
  name: RouteNames.profile,
  builder: (context, state) => const ProfileScreen(),
),
```

### 홈 화면 연동

**home_screen.dart**:
```dart
// 알림 버튼
IconButton(
  icon: Icon(Icons.notifications_outlined),
  onPressed: () {
    context.pushNamed(RouteNames.notification);
  },
),

// 프로필 버튼
IconButton(
  icon: Icon(Icons.person_outline),
  onPressed: () {
    context.pushNamed(RouteNames.profile);
  },
),
```

---

## 전체 위젯 구조

### 알림 화면
```
NotificationScreen (Scaffold)
└─ AppBar (뒤로가기 + 제목)
└─ ListView.separated
   └─ _NotificationCard (각 알림)
      └─ InkWell (탭 처리)
         └─ Container (카드)
            └─ Row
               ├─ Container (아이콘 배경)
               │  └─ Icon (타입별 아이콘)
               └─ Column (알림 내용)
                  ├─ Row (제목 + 배지)
                  ├─ Text (메시지)
                  └─ Text (시간)
```

### 프로필 화면
```
ProfileScreen (Scaffold)
└─ AppBar (뒤로가기 + 제목)
└─ SingleChildScrollView
   └─ Column
      ├─ _buildProfileHeader()
      │  └─ Container (흰색 카드)
      │     └─ Column
      │        ├─ Container (프로필 사진)
      │        ├─ Text (사용자명)
      │        ├─ Text (이메일)
      │        └─ OutlinedButton (수정)
      │
      ├─ _buildAccountSection()
      │  └─ _buildSection()
      │     └─ ListView.separated
      │        └─ ListTile (메뉴 항목)
      │
      ├─ _buildGeneralSection()
      │  └─ _buildSection()
      │     └─ ListView.separated
      │        └─ ListTile (메뉴 항목)
      │
      ├─ _buildInfoSection()
      │  └─ _buildSection()
      │     └─ ListView.separated
      │        └─ ListTile (메뉴 항목)
      │
      └─ _buildLogoutButton()
         └─ TextButton (로그아웃)
```

---

## 디자인 시스템 적용

### 색상 사용

| 요소 | 색상 | 용도 |
|------|------|------|
| 배경 | `AppColors.gray50` | 화면 전체 배경 |
| 카드 | `Colors.white` | 알림 카드, 프로필 섹션 |
| 주요 텍스트 | `AppColors.nearBlack` | 제목, 메뉴 항목 |
| 보조 텍스트 | `AppColors.mediumGray` | 설명, 시간 정보 |
| 강조 | `AppColors.brandPrimary` | 읽지 않은 알림, 버튼 |
| 경고 | `AppColors.error` | 회원 탈퇴, 로그아웃 |

### 여백 사용

| 위치 | 여백 | 크기 |
|------|------|------|
| 화면 패딩 | `AppSpacing.lg` | 16px |
| 카드 패딩 | `AppSpacing.md` | 12px |
| 섹션 간격 | `AppSpacing.lg` | 16px |
| 항목 간격 | `AppSpacing.md` | 12px |
| 작은 간격 | `AppSpacing.sm` | 8px |

### 모서리 반경

| 요소 | 반경 | 크기 |
|------|------|------|
| 카드 | `AppRadius.lg` | 16px |
| 버튼 | `AppRadius.md` | 12px |
| 원형 | `BoxShape.circle` | - |

---

## 구현 시 주요 결정 사항

### 1. 알림 타입별 아이콘 선택

```dart
IconData get icon {
  switch (type) {
    case NotificationType.reminder:
      return Icons.edit_calendar_outlined;  // 달력 아이콘
    case NotificationType.healthWarning:
      return Icons.warning_amber_rounded;   // 경고 아이콘
    case NotificationType.system:
      return Icons.info_outline;            // 정보 아이콘
  }
}
```

**선택 이유**:
- **달력**: 기록 리마인더는 날짜와 연관
- **경고**: 건강 이슈는 주의가 필요한 사항
- **정보**: 시스템 알림은 중립적 정보 전달

### 2. 프로필 메뉴 구조

**계정 섹션**:
- 사용자 개인 정보와 직접 관련된 항목
- 민감한 작업(비밀번호 변경, 회원 탈퇴)

**일반 섹션**:
- 앱 사용 설정
- 자주 변경할 수 있는 항목

**정보 섹션**:
- 읽기 전용 정보
- 법적 문서 및 도움말

### 3. ListView의 physics 설정

```dart
ListView.separated(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  ...
)
```

**이유**:
- 프로필 화면 전체가 `SingleChildScrollView` 내부
- 중첩 스크롤 방지를 위해 ListView는 스크롤 비활성화
- `shrinkWrap: true`로 필요한 만큼만 높이 차지

### 4. 메뉴 항목 데이터 클래스

```dart
class _MenuItem {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;
}
```

**장점**:
- 타입 안전성 확보
- 재사용 가능한 구조
- IDE 자동완성 지원
- `_` 접두사로 private 클래스임을 명시

---

## 배운 점

### 1. **알림 모델의 타입 시스템**

`enum`과 `getter`를 결합하여 타입별 UI 속성을 자동화하면:
- 새로운 알림 타입 추가 시 한 곳만 수정
- 런타임 에러 대신 컴파일 타임 에러로 안전성 확보
- 코드 중복 없이 일관된 디자인 유지

### 2. **상대 시간 계산의 UX**

"2시간 전"이 "14:30"보다 직관적인 이유:
- 사용자는 정확한 시간보다 얼마나 최근인지가 중요
- 1주일 이내는 상대 시간, 그 이후는 절대 시간으로 균형
- 모바일 알림 표준 패턴 준수

### 3. **섹션 기반 설정 화면**

설정 항목을 섹션으로 그룹화하면:
- 사용자가 원하는 항목을 빠르게 찾을 수 있음
- 시각적으로 깔끔하고 정리된 느낌
- 새 항목 추가 시 어디에 넣을지 명확

### 4. **확인 다이얼로그의 중요성**

로그아웃, 회원 탈퇴 같은 중요한 작업에는 반드시:
- 두 번 확인 절차 필요
- 액션 버튼을 경고 색상으로 강조
- 취소 버튼을 기본 액션으로 설정

### 5. **비동기 작업의 mounted 체크**

```dart
if (confirmed == true && mounted) {
  await _authService.signOut();
  if (!mounted) return;
  context.goNamed(RouteNames.login);
}
```

Flutter에서 비동기 작업 후에는:
- `mounted` 체크로 위젯이 아직 트리에 있는지 확인
- 없으면 `setState`나 `context` 사용 시 에러 발생
- 사용자 경험과 안정성 모두 향상

### 6. **일관된 디자인 시스템의 장점**

`AppColors`, `AppSpacing`, `AppRadius` 같은 상수 사용:
- 디자이너가 요청한 변경사항을 한 곳에서 반영
- 코드 리뷰 시 "왜 이 색상/여백인가?" 질문 불필요
- 새 화면 추가 시 일관성 자동 유지

### 7. **TODO 주석의 전략적 사용**

```dart
// TODO: 실제로는 서비스에서 가져와야 함
_notifications = NotificationData.getDummyNotifications();

// TODO: 프로필 수정 화면으로 이동
ScaffoldMessenger.of(context).showSnackBar(...);
```

명확한 TODO로:
- 나중에 구현할 부분 추적
- 팀원에게 미완성 기능 알림
- 우선순위 파악 용이

---

## 개선 가능한 부분

### 1. 알림 서비스 구현
현재는 더미 데이터지만, 실제로는:
- Supabase Realtime으로 실시간 알림 수신
- 로컬 데이터베이스에 알림 저장 (오프라인 지원)
- 푸시 알림 통합 (FCM)

### 2. 프로필 사진 업로드
- Supabase Storage 사용
- 이미지 압축 및 최적화
- 카메라/갤러리 선택 UI

### 3. 설정 항목 실제 동작
- 알림 설정: 알림 종류별 on/off
- 언어 설정: 다국어 지원 (flutter_localizations)
- 테마 설정: 라이트/다크 모드

### 4. 애니메이션 추가
- 알림 카드 슬라이드 삭제
- 프로필 사진 확대/축소
- 페이지 전환 애니메이션

---

## 결론

이번 구현을 통해 사용자 중심의 설정 화면과 알림 시스템을 완성했습니다:

✅ **타입 안전한 알림 시스템**으로 유지보수성 향상
✅ **상대 시간 표시**로 사용자 친화적 UX 제공
✅ **섹션 기반 프로필 화면**으로 직관적 네비게이션
✅ **Supabase 연동**으로 실제 사용자 정보 표시
✅ **일관된 디자인 시스템** 적용으로 앱 전체 통일성 유지
✅ **확인 다이얼로그**로 중요한 작업의 안전성 확보

홈 화면의 알림/프로필 버튼이 실제 기능을 갖추게 되었고, 향후 실제 서비스 로직 추가 시에도 쉽게 확장할 수 있는 구조가 완성되었습니다. 🎯
