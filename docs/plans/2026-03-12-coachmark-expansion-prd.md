# Perch Care 코치마크 전체 화면 확장 PRD

**작성일:** 2026-03-12
**문서 상태:** Draft v1
**작성 목적:** 앱 기능과 화면이 지속 증가하면서 신규/기존 사용자 모두 주요 기능을 놓치는 문제를 해결하기 위해, 기존 커스텀 코치마크 시스템을 전체 핵심 화면으로 확장하는 기획을 정의한다.

---

## 1. 문서 요약

Perch Care는 이미 자체 구현한 코치마크 시스템(`CoachMarkService` + `CoachMarkOverlay`)을 보유하고 있으며, 현재 3개 화면(Home, Weight Detail, AI Encyclopedia)에서 총 13단계의 코치마크를 제공하고 있다.

이번 확장의 목표는 다음 3가지이다:

1. **10개 추가 화면**에 총 **28단계** 코치마크를 신규 구현하여 앱 전체 기능의 발견 가능성(discoverability)을 높인다.
2. `CoachMarkService`를 제네릭 키 기반으로 리팩토링하여 유지보수성과 확장성을 개선한다.
3. 한국어/영어/중국어 3개 언어 로컬라이제이션을 동시에 지원한다.

핵심 전략은 `첫 방문 시 자동 표시 + 완료/건너뛰기 후 재표시 없음 + 로그아웃 시 초기화`이다.

---

## 2. 현재 상태

### 2-1. 기존 코치마크 시스템

| 항목 | 현재 상태 | 관련 파일 |
|------|----------|----------|
| 서비스 | `CoachMarkService` 싱글턴, SharedPreferences 기반 | `lib/src/services/coach_mark/coach_mark_service.dart` |
| 오버레이 | `CoachMarkOverlay` + `CoachMarkStep` + Spotlight + Arrow | `lib/src/widgets/coach_mark_overlay.dart` |
| Home 화면 | 7단계 (WCI, 체중, 수분, 사료, 건강신호, 기록탭, 챗봇탭) | `lib/src/screens/home/home_screen.dart` |
| Weight Detail | 4단계 (토글, 차트, 캘린더, 추가버튼) | `lib/src/screens/weight/weight_detail_screen.dart` |
| AI Encyclopedia | 2단계 (추천 질문, 입력창) | `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` |
| 하단 네비 | 3개 static GlobalKey (homeTab, recordsTab, chatbotTab) | `lib/src/widgets/bottom_nav_bar.dart` |
| 로그아웃 초기화 | `clearAll()` 호출 | `lib/src/services/auth/auth_service.dart` (line 225, 327) |

### 2-2. 오버레이 기능 세부

- **Spotlight 효과**: `_SpotlightPainter`로 타겟 주위에 구멍 뚫린 반투명 배경
- **자동 스크롤**: `ScrollController`를 받아 타겟이 화면에 보이도록 `animateTo`
- **스마트 툴팁 위치**: 타겟 아래 공간 충분 → below, 부족 → above 자동 결정
- **애니메이션**: 300ms fade-in/out, 스텝 전환 시 reverse → forward
- **인터랙션**: 배경 탭으로 다음 단계, Skip 버튼, Next/Got it 버튼
- **비스크롤 지원**: `isScrollable: false`로 하단 네비 등 고정 요소 처리

### 2-3. 현재 문제

1. **기능 발견 격차**: 10개 이상의 핵심 화면에 코치마크가 없어 신규 사용자가 주요 기능을 놓침
2. **서비스 확장성 부족**: 화면마다 `hasSeen{Screen}()` / `mark{Screen}Seen()` 2개 메서드 + 1개 상수가 필요하여 10개 화면 추가 시 20개 메서드 + 10개 상수 추가 필요
3. **clearAll() 수동 관리**: 새 키를 추가할 때마다 수동으로 `clearAll()`에 등록해야 하여 누락 위험

### 2-4. 로컬라이제이션 현황

| 파일 | 코치마크 문자열 수 | 위치 |
|------|-------------------|------|
| `lib/l10n/app_en.arb` | 16개 (13 title/body + 3 공통) | line 425-453 |
| `lib/l10n/app_ko.arb` | 16개 (13 title/body + 3 공통) | line 623-651 |
| `lib/l10n/app_zh.arb` | 16개 (13 title/body + 3 공통) | line 592-620 |

공통 문자열: `coach_next` (다음/Next/下一步), `coach_gotIt` (알겠어요!/Got it!/知道了！), `coach_skip` (건너뛰기/Skip/跳过)

---

## 3. 문제 정의

### 3-1. 사용자 문제

- **신규 사용자**: 기록 화면(Food, Water, Weight)에 진입해도 배식/취식 토글, WCI 게이지 등 핵심 기능의 존재를 인지하지 못함
- **AI 건강체크 사용자**: History 화면의 수의사 리포트 버튼, 공유 기능, 스와이프 삭제 제스처를 발견하지 못함
- **프리미엄 전환 대상**: Profile 화면의 프리미엄 카드, Premium 화면의 프로모 코드 기능이 눈에 띄지 않음

### 3-2. 기술적 문제

- 10개 화면 추가 시 `CoachMarkService`에 20개 메서드 + 10개 상수 + `clearAll()` 수동 업데이트 필요
- 대부분의 타겟 화면에 `ScrollController`와 `GlobalKey`가 없어 추가 필요

---

## 4. 목표

### 4-1. 사용자 경험 목표

| 목표 | 측정 기준 |
|------|----------|
| 전체 핵심 화면 100% 코치마크 커버리지 | 13개 핵심 화면 중 13개에 코치마크 적용 |
| 신규 사용자 기능 발견율 향상 | 코치마크 완료율 > 70% (analytics 연동 시) |
| 프리미엄 전환 유인 강화 | Premium/Profile 화면에서 프리미엄 기능 하이라이트 |

### 4-2. 기술 목표

| 목표 | 측정 기준 |
|------|----------|
| 서비스 확장성 확보 | 제네릭 `hasSeen(key)` / `markSeen(key)` 적용 |
| clearAll() 자동화 | prefix 기반 키 일괄 삭제 |
| 로컬라이제이션 완성 | EN/KO 각 30개 신규 문자열 |

---

## 5. 범위 정의

### 5-1. 코치마크 적용 화면 (총 13개)

#### 기존 구현 (3개 화면, 13단계)
| # | 화면 | 단계 수 | 상태 |
|---|------|--------|------|
| 1 | Home Screen | 7 | 구현 완료 |
| 2 | Weight Detail Screen | 4 | 구현 완료 |
| 3 | AI Encyclopedia Screen | 2 | 구현 완료 |

#### 신규 구현 (10개 화면, 28단계)
| # | 화면 | 단계 수 | 화면 키 |
|---|------|--------|---------|
| 4 | Food Record Screen | 3 | `food_record` |
| 5 | Water Record Screen | 2 | `water_record` |
| 6 | Weight Record Screen | 4 | `weight_record` |
| 7 | Health Check Main Screen | 3 | `health_check_main` |
| 8 | Health Check History Screen | 3 | `health_check_history` |
| 9 | Health Check Result Screen | 3 | `health_check_result` |
| 10 | BHI Detail Screen | 2 | `bhi_detail` |
| 11 | Profile Screen | 3 | `profile` |
| 12 | Premium Screen | 2 | `premium` |
| 13 | Pet Profile Detail Screen | 3 | `pet_profile_detail` |

### 5-2. 제외 화면 (코치마크 불필요)

| 화면 | 제외 사유 |
|------|----------|
| WCI Index Screen | 정보 전용, 인터랙션 없음 |
| Terms Detail Screen | 법적 약관 표시, 자명한 UI |
| FAQ Screen | 자명한 Q&A 형식 |
| Notification Screen | 표준 알림 목록 |
| Login / Signup / Email Login | 표준 인증 플로우 |
| Forgot Password (3 화면) | 표준 비밀번호 찾기 플로우 |
| Onboarding Screen | 이미 튜토리얼 성격 |
| Splash Screen | 사용자 인터랙션 없음 |
| Profile Setup / Complete | 초기 설정 가이드형 UI |
| Pet Add Screen | 입력 폼 위주, 자명한 UI |
| Health Check Capture | 카메라 UI, 자명함 |
| Health Check Analyzing | 로딩 상태, 인터랙션 없음 |
| Vet Summary Screen | 단순 텍스트 표시 |

---

## 6. 상세 설계

### 6-1. CoachMarkService 리팩토링

**Before:**
```dart
class CoachMarkService {
  static const _keyHomeCoachSeen = 'coach_mark_home_seen';
  // ... 화면마다 상수 + 2개 메서드 반복

  Future<bool> hasSeenHomeCoachMarks() async { ... }
  Future<void> markHomeCoachMarksSeen() async { ... }
  // ... 반복

  Future<void> clearAll() async {
    await prefs.remove(_keyHomeCoachSeen);
    await prefs.remove(_keyRecordsCoachSeen);  // 수동 나열
    await prefs.remove(_keyChatbotCoachSeen);
  }
}
```

**After:**
```dart
class CoachMarkService {
  CoachMarkService._();
  static final instance = CoachMarkService._();

  static const _prefix = 'coach_mark_seen_';

  // 화면별 키 상수 (type safety)
  static const screenHome = 'home';
  static const screenRecords = 'records';
  static const screenChatbot = 'chatbot';
  static const screenFoodRecord = 'food_record';
  static const screenWaterRecord = 'water_record';
  static const screenWeightRecord = 'weight_record';
  static const screenHealthCheckMain = 'health_check_main';
  static const screenHealthCheckHistory = 'health_check_history';
  static const screenHealthCheckResult = 'health_check_result';
  static const screenBhiDetail = 'bhi_detail';
  static const screenProfile = 'profile';
  static const screenPremium = 'premium';
  static const screenPetProfileDetail = 'pet_profile_detail';

  /// 해당 화면의 코치마크를 이미 봤는지 확인
  Future<bool> hasSeen(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$screenKey') ?? false;
  }

  /// 해당 화면의 코치마크를 본 것으로 표시
  Future<void> markSeen(String screenKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$screenKey', true);
  }

  /// 모든 코치마크 상태 초기화 (로그아웃 시 호출)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
```

**마이그레이션 예시 (Home Screen):**
```dart
// Before
if (await service.hasSeenHomeCoachMarks()) return;
// ...
onComplete: () => service.markHomeCoachMarksSeen(),

// After
if (await service.hasSeen(CoachMarkService.screenHome)) return;
// ...
onComplete: () => service.markSeen(CoachMarkService.screenHome),
```

---

### 6-2. 화면별 코치마크 상세 설계

#### 6-2-1. Food Record Screen (3단계)

**파일:** `lib/src/screens/food/food_record_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 배식/취식 토글 (Serving/Eating switch) | `_dietToggleKey` | true | 항상 |
| 2 | 사료 추가 버튼 (점선 테두리 버튼) | `_addButtonKey` | true | 항상 |
| 3 | 저장 버튼 | `_saveButtonKey` | false | 항상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_foodToggle` | 식단 유형 | 배식과 취식을 전환해서 제공량과 섭취량을 모두 기록하세요. |
| `coach_foodAdd` | 사료 추가 | 여기를 탭해서 사료 이름, 양, 시간을 기록하세요. |
| `coach_foodSave` | 변경사항 저장 | 저장을 잊지 마세요! 온라인 시 자동으로 동기화됩니다. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_foodToggle` | Diet Type | Switch between Serving and Eating to track both provided and consumed food. |
| `coach_foodAdd` | Add Food Entry | Tap here to add a new food record with name, amount, and time. |
| `coach_foodSave` | Save Changes | Don't forget to save! Your records sync automatically when online. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_foodToggle` | 饮食类型 | 切换配餐和进食，同时记录提供量和摄入量。 |
| `coach_foodAdd` | 添加食物 | 点击这里添加食物名称、数量和时间。 |
| `coach_foodSave` | 保存更改 | 别忘了保存！在线时会自动同步。 |

---

#### 6-2-2. Water Record Screen (2단계)

**파일:** `lib/src/screens/water/water_record_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 물 아이콘 (탭하여 편집) | `_waterIconKey` | true | 항상 |
| 2 | 일일 목표 정보 카드 | `_targetCardKey` | true | 항상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_waterIcon` | 음수량 기록 | 물 아이콘을 탭해서 섭취량을 늘리세요. 길게 눌러 직접 입력할 수도 있어요. |
| `coach_waterTarget` | 일일 목표 | 권장 일일 음수량이 표시됩니다. 충분한 수분 섭취가 중요해요! |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_waterIcon` | Track Water Intake | Tap the water icon to increase intake. Long press to manually enter the amount. |
| `coach_waterTarget` | Daily Goal | Your recommended daily water intake is shown here. Keep your bird hydrated! |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_waterIcon` | 记录饮水量 | 点击水图标增加饮水量。长按可手动输入数量。 |
| `coach_waterTarget` | 每日目标 | 这里显示建议的每日饮水量。保持充足的水分很重要！ |

---

#### 6-2-3. Weight Record Screen (4단계)

**파일:** `lib/src/screens/weight/weight_record_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | WCI 게이지 (CustomPaint) | `_wciGaugeKey` | true | 항상 |
| 2 | 체중 입력 필드 | `_weightInputKey` | true | 항상 |
| 3 | 시간 선택 카드 | `_timeCardKey` | true | 항상 |
| 4 | 저장 버튼 | `_saveButtonKey` | false | 항상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_weightGauge` | 체중 컨디션 지수 | 품종별 건강 체중 범위를 확인할 수 있어요. |
| `coach_weightInput` | 체중 입력 | 그램 단위로 입력하세요. 아침에 측정하면 일관성 있게 기록할 수 있어요! |
| `coach_weightTime` | 측정 시간 | 체중을 측정한 시간을 선택하세요. 하루에 여러 번 기록할 수 있어요. |
| `coach_weightSave` | 기록 저장 | 탭해서 저장하세요. 데이터가 성장 추이와 건강 변화를 감지하는 데 도움이 돼요. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_weightGauge` | Weight Condition Index | This gauge shows if your bird's weight is within the healthy range for their breed. |
| `coach_weightInput` | Enter Weight | Enter weight in grams. Tip: Weigh in the morning for consistency! |
| `coach_weightTime` | Record Time | Select when the weight was measured. You can record multiple entries per day. |
| `coach_weightSave` | Save Record | Tap to save. Your data helps track growth and detect health changes early. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_weightGauge` | 体重状况指数 | 该仪表显示您的鸟的体重是否在健康范围内。 |
| `coach_weightInput` | 输入体重 | 以克为单位输入。提示：早上称重更一致！ |
| `coach_weightTime` | 记录时间 | 选择称重的时间。每天可以记录多次。 |
| `coach_weightSave` | 保存记录 | 点击保存。数据有助于追踪成长和早期发现健康变化。 |

---

#### 6-2-4. Health Check Main Screen (3단계)

**파일:** `lib/src/screens/health_check/health_check_main_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 기록 보기 버튼 (AppBar 아이콘) | `_historyButtonKey` | false | 항상 |
| 2 | 모드 선택 카드 영역 | `_modeCardsKey` | true | 항상 |
| 3 | 무료 체험 배지 | `_trialBadgeKey` | true | **조건부: 프리미엄 사용자 아닌 경우만** |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcHistory` | 기록 보기 | 과거 건강 체크 기록을 확인하세요. 시간에 따른 패턴을 추적할 수 있어요. |
| `coach_hcModes` | 체크 유형 선택 | 전체 건강은 Full Body, 특정 부위는 Part-Specific, 배설물/사료는 해당 모드를 선택하세요. |
| `coach_hcTrial` | 무료 체험 가능 | 무료 건강 체크 횟수가 남아있어요! 프리미엄은 무제한으로 사용할 수 있습니다. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcHistory` | View History | Access all your past health checks here. Track patterns over time. |
| `coach_hcModes` | Choose Check Type | Select Full Body for overall health, Part-Specific for targeted areas, or Droppings/Food for diet analysis. |
| `coach_hcTrial` | Free Trials Available | You have free health check trials! Premium unlocks unlimited checks. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcHistory` | 查看历史 | 在这里查看所有过去的健康检查。追踪随时间变化的模式。 |
| `coach_hcModes` | 选择检查类型 | 选择全身检查、部位检查、排泄物分析或食物分析。 |
| `coach_hcTrial` | 免费试用可用 | 您有免费健康检查次数！高级版可无限使用。 |

**조건부 단계 처리:**
```dart
final steps = <CoachMarkStep>[
  CoachMarkStep(targetKey: _historyButtonKey, ...),
  CoachMarkStep(targetKey: _modeCardsKey, ...),
];

// 프리미엄이 아닌 경우에만 trial 배지 코치마크 추가
if (!_isPremium && _hasVisionTrial) {
  steps.add(CoachMarkStep(targetKey: _trialBadgeKey, ...));
}
```

---

#### 6-2-5. Health Check History Screen (3단계)

**파일:** `lib/src/screens/health_check/health_check_history_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 수의사 리포트 버튼 (AppBar) | `_vetSummaryButtonKey` | false | 기록이 1개 이상 |
| 2 | 공유 버튼 (AppBar) | `_shareButtonKey` | false | 기록이 1개 이상 |
| 3 | 첫 번째 기록 카드 | `_firstHistoryCardKey` | true | 기록이 1개 이상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcHistoryVet` | 수의사 리포트 | 수의사용 종합 리포트를 받아보세요. 프리미엄 기능입니다. |
| `coach_hcHistoryShare` | 리포트 공유 | 이메일이나 메시징 앱으로 건강 리포트를 공유하세요. |
| `coach_hcHistorySwipe` | 스와이프 삭제 | 기록 카드를 왼쪽으로 밀어 삭제하세요. 삭제는 되돌릴 수 없으니 주의하세요! |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcHistoryVet` | Vet Summary | Get a comprehensive report formatted for veterinarians. Premium feature. |
| `coach_hcHistoryShare` | Share Report | Share your bird's health report via email or messaging apps. |
| `coach_hcHistorySwipe` | Swipe to Delete | Swipe left on any history card to delete it. Be careful, this cannot be undone! |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcHistoryVet` | 兽医报告 | 获取为兽医准备的综合报告。高级版功能。 |
| `coach_hcHistoryShare` | 分享报告 | 通过邮件或消息应用分享您的鸟的健康报告。 |
| `coach_hcHistorySwipe` | 滑动删除 | 向左滑动任何历史卡片即可删除。请注意，此操作不可撤销！ |

**동적 리스트 아이템 처리:**
```dart
// ListView.builder 내에서 첫 번째 카드에만 key 부착
itemBuilder: (context, index) {
  return Container(
    key: index == 0 ? _firstHistoryCardKey : null,
    child: Dismissible(...),
  );
}
```

---

#### 6-2-6. Health Check Result Screen (3단계)

**파일:** `lib/src/screens/health_check/health_check_result_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 신뢰도 프로그레스 바 | `_confidenceBarKey` | true | 항상 |
| 2 | 분석 결과 카드들 | `_findingsKey` | true | findings 존재 시 |
| 3 | 재검사 버튼 | `_recheckButtonKey` | false | 항상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcResultConfidence` | 신뢰도 점수 | AI 분석의 신뢰도를 나타냅니다. 높을수록 좋지만, 우려 사항은 항상 수의사와 상담하세요. |
| `coach_hcResultFindings` | 분석 결과 | AI 건강 체크의 세부 관찰 내용입니다. 카드를 탭해 자세히 보세요. |
| `coach_hcResultRecheck` | 재검사 가능 | 만족스럽지 않으세요? 다른 사진을 찍어 즉시 재검사할 수 있어요. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcResultConfidence` | Confidence Score | This shows AI confidence in the analysis. Higher is better, but always consult a vet for concerns. |
| `coach_hcResultFindings` | Analysis Findings | Detailed observations from the AI health check. Tap each card for more info. |
| `coach_hcResultRecheck` | Recheck Anytime | Not satisfied? You can take another photo and recheck immediately. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_hcResultConfidence` | 置信度分数 | 显示AI分析的置信度。越高越好，但有疑虑时请咨询兽医。 |
| `coach_hcResultFindings` | 分析结果 | AI健康检查的详细观察。点击卡片查看更多信息。 |
| `coach_hcResultRecheck` | 随时复查 | 不满意？可以拍另一张照片立即重新检查。 |

---

#### 6-2-7. BHI Detail Screen (2단계)

**파일:** `lib/src/screens/bhi/bhi_detail_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 점수 원형 게이지 | `_scoreRingKey` | true | 항상 |
| 2 | 점수 구성 카드 (체중/사료/수분) | `_breakdownCardsKey` | true | 항상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_bhiRing` | 건강 지수 | 체중, 사료, 수분 데이터로 계산된 100점 만점 건강 점수입니다. |
| `coach_bhiBreakdown` | 점수 구성 | 체중(60점), 사료(25점), 수분(15점)이 총점에 어떻게 기여하는지 확인하세요. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_bhiRing` | Bird Health Index | Your overall health score out of 100, calculated from weight, food, and water data. |
| `coach_bhiBreakdown` | Score Breakdown | See how weight (60pts), food (25pts), and water (15pts) contribute to the total score. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_bhiRing` | 鸟类健康指数 | 基于体重、食物和饮水数据计算的100分满分健康评分。 |
| `coach_bhiBreakdown` | 分数构成 | 查看体重(60分)、食物(25分)和饮水(15分)如何贡献总分。 |

---

#### 6-2-8. Profile Screen (3단계)

**파일:** `lib/src/screens/profile/profile_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 프리미엄 카드 | `_premiumCardKey` | true | 항상 |
| 2 | 반려동물 추가 버튼 | `_addPetButtonKey` | true | 항상 |
| 3 | 첫 번째 펫 프로필 카드 | `_firstPetCardKey` | true | 펫이 1마리 이상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_profilePremium` | 프리미엄 업그레이드 | 무제한 AI 건강 체크, 리포트 내보내기, 고급 인사이트를 잠금 해제하세요! |
| `coach_profileAddPet` | 반려동물 추가 | 여러 마리를 키우시나요? 여기서 추가하고 프로필을 쉽게 전환하세요. |
| `coach_profilePetCard` | 활성 반려동물 선택 | 펫 카드를 탭해 전환하세요. 활성 펫의 데이터가 앱 전체에 표시됩니다. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_profilePremium` | Upgrade to Premium | Unlock unlimited AI health checks, export reports, and advanced insights! |
| `coach_profileAddPet` | Add Another Pet | Managing multiple birds? Add them here and switch between profiles easily. |
| `coach_profilePetCard` | Select Active Pet | Tap any pet card to switch. The active pet's data will be shown throughout the app. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_profilePremium` | 升级高级版 | 解锁无限AI健康检查、导出报告和高级洞察！ |
| `coach_profileAddPet` | 添加宠物 | 养多只鸟？在这里添加并轻松切换个人资料。 |
| `coach_profilePetCard` | 选择活跃宠物 | 点击任何宠物卡片切换。活跃宠物的数据将在整个应用中显示。 |

---

#### 6-2-9. Premium Screen (2단계)

**파일:** `lib/src/screens/premium/premium_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 월간/연간 플랜 선택기 | `_planSelectorKey` | true | 항상 |
| 2 | 프로모 코드 버튼 | `_promoCodeButtonKey` | false | 항상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_premiumPlan` | 플랜 선택 | 월간은 유연성을, 연간은 2개월 무료 혜택을 드려요. 둘 다 모든 기능을 잠금 해제합니다! |
| `coach_premiumPromo` | 프로모 코드가 있으신가요? | 파트너사나 이벤트 코드가 있으세요? 여기를 탭해 특별 혜택을 받으세요. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_premiumPlan` | Choose Your Plan | Monthly offers flexibility, Yearly gives you 2 months free. Both unlock all features! |
| `coach_premiumPromo` | Have a Promo Code? | Got a code from a partner or event? Tap here to redeem special offers. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_premiumPlan` | 选择您的方案 | 月度灵活，年度赠送2个月。两种方案都解锁所有功能！ |
| `coach_premiumPromo` | 有促销码吗？ | 有合作伙伴或活动的优惠码？点击这里兑换特别优惠。 |

---

#### 6-2-10. Pet Profile Detail Screen (3단계)

**파일:** `lib/src/screens/profile/pet_profile_detail_screen.dart`

| 단계 | 타겟 요소 | GlobalKey | isScrollable | 트리거 조건 |
|------|----------|-----------|-------------|-------------|
| 1 | 프로필 이미지 편집 버튼 | `_profileImageKey` | true | 항상 |
| 2 | 성별/날짜 선택기 영역 | `_genderSelectorKey` | true | 항상 |
| 3 | 저장 버튼 | `_saveButtonKey` | false | 항상 |

**로컬라이제이션 (KO):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_petDetailImage` | 펫 사진 추가 | 탭해서 반려조의 사진을 업로드하세요. 한눈에 식별하는 데 도움이 돼요! |
| `coach_petDetailInfo` | 기본 정보 | 성별, 생년월일, 품종을 입력하면 더 정확한 건강 권장사항을 받을 수 있어요. |
| `coach_petDetailSave` | 프로필 저장 | 변경사항을 저장하세요! 모든 기기에서 동기화됩니다. |

**로컬라이제이션 (EN):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_petDetailImage` | Add Pet Photo | Tap to upload a photo of your bird. It helps identify them at a glance! |
| `coach_petDetailInfo` | Basic Info | Fill in gender, birthdate, and breed for more accurate health recommendations. |
| `coach_petDetailSave` | Save Profile | Don't forget to save your changes! They sync across all your devices. |

**로컬라이제이션 (ZH):**
| 키 | 제목 | 설명 |
|----|------|------|
| `coach_petDetailImage` | 添加宠物照片 | 点击上传您的鸟的照片。有助于一目了然地识别！ |
| `coach_petDetailInfo` | 基本信息 | 填写性别、出生日期和品种，获得更准确的健康建议。 |
| `coach_petDetailSave` | 保存资料 | 别忘了保存更改！所有设备都会同步。 |

---

## 7. 구현 패턴

모든 화면에 동일한 패턴을 적용한다:

```dart
class _SomeScreenState extends State<SomeScreen> {
  // 1. GlobalKey 선언
  final _featureAKey = GlobalKey();
  final _featureBKey = GlobalKey();

  // 2. ScrollController (기존에 없으면 추가)
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 3. 코치마크 표시 메서드
  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenXxx)) return;

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    CoachMarkOverlay.show(
      context,
      scrollController: _scrollController,
      steps: [
        CoachMarkStep(
          targetKey: _featureAKey,
          title: l10n.coach_featureA_title,
          body: l10n.coach_featureA_body,
        ),
        CoachMarkStep(
          targetKey: _featureBKey,
          title: l10n.coach_featureB_title,
          body: l10n.coach_featureB_body,
          isScrollable: false,
        ),
      ],
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () => service.markSeen(CoachMarkService.screenXxx),
    );
  }

  // 4. 데이터 로드 완료 후 호출
  Future<void> _loadData() async {
    // ... 데이터 로드 ...
    _maybeShowCoachMarks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            Container(key: _featureAKey, child: FeatureAWidget()),
            Container(key: _featureBKey, child: FeatureBWidget()),
          ],
        ),
      ),
    );
  }
}
```

---

## 8. 수정 대상 파일 목록

### 서비스 계층 (1개)
| 파일 | 변경 내용 |
|------|----------|
| `lib/src/services/coach_mark/coach_mark_service.dart` | 제네릭 hasSeen/markSeen + 화면 키 상수 + clearAll 리팩토링 |

### 로컬라이제이션 (3개)
| 파일 | 변경 내용 |
|------|----------|
| `lib/l10n/app_en.arb` | +30개 코치마크 문자열 (title/body 쌍) |
| `lib/l10n/app_ko.arb` | +30개 코치마크 문자열 (title/body 쌍) |
| `lib/l10n/app_zh.arb` | +30개 코치마크 문자열 (title/body 쌍) |

### 기존 화면 마이그레이션 (3개)
| 파일 | 변경 내용 |
|------|----------|
| `lib/src/screens/home/home_screen.dart` | 새 API(`hasSeen`/`markSeen`)로 전환 |
| `lib/src/screens/weight/weight_detail_screen.dart` | 새 API로 전환 |
| `lib/src/screens/ai_encyclopedia/ai_encyclopedia_screen.dart` | 새 API로 전환 |

### 신규 코치마크 구현 (10개)
| 파일 | 단계 수 | 변경 내용 |
|------|--------|----------|
| `lib/src/screens/food/food_record_screen.dart` | 3 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/water/water_record_screen.dart` | 2 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/weight/weight_record_screen.dart` | 4 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/health_check/health_check_main_screen.dart` | 3 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/health_check/health_check_history_screen.dart` | 3 | GlobalKey + _maybeShowCoachMarks (조건부: 기록 존재 시) |
| `lib/src/screens/health_check/health_check_result_screen.dart` | 3 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/bhi/bhi_detail_screen.dart` | 2 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/profile/profile_screen.dart` | 3 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/premium/premium_screen.dart` | 2 | GlobalKey + ScrollController + _maybeShowCoachMarks |
| `lib/src/screens/profile/pet_profile_detail_screen.dart` | 3 | GlobalKey + ScrollController + _maybeShowCoachMarks |

**총 수정 파일: 17개** (app_zh.arb 포함)

---

## 9. 엣지 케이스 및 주의사항

### 9-1. 동적 리스트 아이템
- Health Check History, Profile Screen에서 첫 번째 카드에만 `GlobalKey` 부착
- 데이터가 없는 경우 (empty state) 코치마크 표시하지 않음

### 9-2. 조건부 단계
- Health Check Main: trial 배지는 프리미엄 사용자에게 표시되지 않으므로 코치마크도 조건부
- Health Check History: 기록이 0개이면 vet/share/swipe 코치마크 모두 건너뜀

### 9-3. 타이밍
- 모든 화면에서 데이터 로드 완료 후 800ms 딜레이 적용
- `mounted` 체크 필수 (비동기 갭 동안 화면 이탈 가능)

### 9-4. 스크롤 충돌
- `isScrollable: false` 사용 시 스크롤 시도하지 않음 (AppBar 버튼, 하단 네비, 고정 저장 버튼)
- `ScrollController`가 이미 있는 화면은 기존 컨트롤러 재사용

### 9-5. 다국어
- `app_zh.arb` (중국어) 존재 확인됨 → 30개 중국어 문자열 추가 필수

---

## 10. 테스트 체크리스트

| # | 테스트 항목 | 예상 결과 |
|---|-----------|----------|
| 1 | 각 화면 첫 방문 | 코치마크 자동 표시 |
| 2 | 각 화면 두 번째 방문 | 코치마크 미표시 |
| 3 | 코치마크 "건너뛰기" 클릭 | seen 마킹, 이후 미표시 |
| 4 | 코치마크 전체 완료 | 마지막 "알겠어요!" 클릭 후 seen 마킹 |
| 5 | 로그아웃 후 재로그인 | 모든 코치마크 초기화, 다시 표시 |
| 6 | EN/KO 전환 후 코치마크 | 해당 언어 문자열 정상 표시 |
| 7 | 스크롤 필요 타겟 | 자동 스크롤 후 spotlight 표시 |
| 8 | AppBar 고정 버튼 타겟 | 스크롤 없이 바로 spotlight 표시 |
| 9 | 빈 데이터 상태 화면 | 코치마크 미표시 (조건부 화면) |
| 10 | flutter analyze | 정적 분석 에러 없음 |
