# Flutter 체중 기록 기능 구현

**날짜**: 2025-11-13
**파일**:

- [lib/src/screens/weight/weight_add_screen.dart](../../lib/src/screens/weight/weight_add_screen.dart)
- [lib/src/services/weight/weight_service.dart](../../lib/src/services/weight/weight_service.dart)
- [lib/src/models/weight_record.dart](../../lib/src/models/weight_record.dart)
- [lib/src/screens/weight/weight_detail_screen.dart](../../lib/src/screens/weight/weight_detail_screen.dart)

---

## 구현 목표

반려동물 체중을 기록하고 관리하는 기능을 구현합니다:

1. **오늘 체중 기록**: 버튼 클릭으로 오늘 날짜 기록 추가
2. **특정 날짜 기록**: 캘린더에서 날짜 선택하여 기록
3. **기록 수정**: 동일 날짜 재입력 시 기존 기록 덮어쓰기
4. **실시간 UI 갱신**: 저장 후 차트와 캘린더 자동 업데이트
5. **입력 검증**: 숫자만 허용, 양수만 저장

---

## 1. 데이터 저장 방식

### 1.1 현재 구현: 인메모리 저장 (Singleton 패턴)

```dart
class WeightService {
  WeightService._();

  static final WeightService _instance = WeightService._();
  factory WeightService() => _instance;

  // 인메모리 데이터 저장소
  final List<WeightRecord> _records = [];
}
```

**설계 이유**:

- **Singleton 패턴**: 앱 전체에서 하나의 데이터 소스만 유지
- **인메모리 리스트**: 빠른 CRUD 작업, 프로토타입 단계에서 유용
- **추후 마이그레이션 용이**: Supabase 연동 시 서비스 내부 로직만 변경

### 1.2 데이터 모델 (WeightRecord)

```dart
class WeightRecord {
  final DateTime date;
  final double weight; // in grams

  const WeightRecord({
    required this.date,
    required this.weight,
  });

  // JSON 직렬화 (Supabase 연동 대비)
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'weight': weight,
    };
  }

  // JSON 역직렬화
  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      date: DateTime.parse(json['date'] as String),
      weight: (json['weight'] as num).toDouble(),
    );
  }

  // copyWith 메서드 (불변성 유지)
  WeightRecord copyWith({
    DateTime? date,
    double? weight,
  }) {
    return WeightRecord(
      date: date ?? this.date,
      weight: weight ?? this.weight,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightRecord &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          weight == other.weight;

  @override
  int get hashCode => date.hashCode ^ weight.hashCode;
}
```

**주요 메서드**:

- `toJson()` / `fromJson()`: Supabase 연동 시 직렬화/역직렬화 사용
- `copyWith()`: 불변 객체 수정 시 새 인스턴스 생성
- `==` / `hashCode`: 날짜와 체중 기준 동등성 비교

### 1.3 WeightService CRUD 로직

#### 전체 기록 조회

```dart
List<WeightRecord> getWeightRecords() {
  if (_records.isEmpty) {
    loadDummyData();
  }
  return List.unmodifiable(_records);
}
```

**특징**:

- 첫 호출 시 더미 데이터 자동 로드
- `List.unmodifiable()`: 외부에서 리스트 직접 수정 방지

#### 특정 날짜 기록 조회

```dart
WeightRecord? getRecordByDate(DateTime date) {
  final normalizedDate = _normalizeDate(date);
  try {
    return _records.firstWhere(
      (record) => _normalizeDate(record.date) == normalizedDate,
    );
  } catch (_) {
    return null;
  }
}
```

**핵심: 날짜 정규화**

```dart
DateTime _normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
```

**이유**:

- `DateTime(2025, 11, 13, 14, 30)` → `DateTime(2025, 11, 13, 0, 0)` 변환
- 시간 정보 제거로 "같은 날짜" 정확히 비교
- 시간까지 비교하면 같은 날짜라도 다른 기록으로 인식되는 문제 방지

#### 저장/수정 (Insert or Update)

```dart
Future<void> saveWeightRecord(WeightRecord record) async {
  final normalizedDate = _normalizeDate(record.date);
  final existingIndex = _records.indexWhere(
    (r) => _normalizeDate(r.date) == normalizedDate,
  );

  if (existingIndex != -1) {
    // Update: 기존 기록 덮어쓰기
    _records[existingIndex] = record;
  } else {
    // Insert: 새 기록 추가
    _records.add(record);
    // 날짜순 정렬 유지
    _records.sort((a, b) => a.date.compareTo(b.date));
  }

  // 추후 Supabase 저장 로직 추가 예정
  // await _saveToSupabase(record);
}
```

**로직**:

1. 동일 날짜 기록 존재 여부 확인
2. 존재 → **Update** (기존 인덱스에 새 값 할당)
3. 없음 → **Insert** (리스트에 추가 후 날짜순 정렬)
4. 정렬: 차트에서 시간순 데이터 보장

#### 삭제

```dart
Future<void> deleteWeightRecord(DateTime date) async {
  final normalizedDate = _normalizeDate(date);
  _records.removeWhere(
    (record) => _normalizeDate(record.date) == normalizedDate,
  );

  // 추후 Supabase 삭제 로직 추가 예정
  // await _deleteFromSupabase(date);
}
```

#### 기간별 조회

```dart
List<WeightRecord> getRecordsByDateRange(DateTime start, DateTime end) {
  final normalizedStart = _normalizeDate(start);
  final normalizedEnd = _normalizeDate(end);

  return _records.where((record) {
    final recordDate = _normalizeDate(record.date);
    return recordDate.isAfter(normalizedStart.subtract(const Duration(days: 1))) &&
        recordDate.isBefore(normalizedEnd.add(const Duration(days: 1)));
  }).toList();
}
```

**범위 비교 트릭**:

- `isAfter(start - 1일)` && `isBefore(end + 1일)`: start와 end 날짜 포함
- 단순 `isAfter(start)`는 start 날짜 제외하므로 -1일 보정

---

## 2. 아키텍처 및 파일 구조

### 2.1 라우팅 (GoRouter)

#### route_paths.dart

```dart
class RoutePaths {
  static const String weightAddToday = '/weight/add/today';
  static const String weightAdd = '/weight/add/:date';
}
```

#### route_names.dart

```dart
class RouteNames {
  static const String weightAddToday = 'weight-add-today';
  static const String weightAdd = 'weight-add';
}
```

#### app_router.dart

```dart
GoRoute(
  path: RoutePaths.weightAddToday,
  name: RouteNames.weightAddToday,
  builder: (context, state) => WeightAddScreen(date: DateTime.now()),
),
GoRoute(
  path: RoutePaths.weightAdd,
  name: RouteNames.weightAdd,
  builder: (context, state) {
    final dateStr = state.pathParameters['date']!;
    final date = DateTime.parse(dateStr);
    return WeightAddScreen(date: date);
  },
),
```

**2가지 경로**:

1. `/weight/add/today`: 오늘 날짜 고정
2. `/weight/add/:date`: 동적 날짜 파라미터 (예: `/weight/add/2025-11-13`)

### 2.2 의존성 흐름

```
WeightDetailScreen
  ↓ (버튼/날짜 클릭)
WeightAddScreen
  ↓ (저장)
WeightService
  ↓ (CRUD)
List<WeightRecord>
  ↓ (pop 결과 반환)
WeightDetailScreen (refresh)
```

---

## 3. WeightAddScreen UI 구현

### 3.1 화면 구조

```
AppBar: "체중 기록하기"
  ↓
날짜 표시: "YYYY년 MM월 DD일 체중 기록"
  ↓
체중 입력 필드
  - 숫자 키패드
  - g 단위 표시
  - 입력 검증
  ↓
저장 버튼 (Gradient)
  - 로딩 중: CircularProgressIndicator
  - 완료 후: SnackBar + 이전 화면으로 돌아가기
```

### 3.2 핵심 코드

#### 상태 관리

```dart
class _WeightAddScreenState extends State<WeightAddScreen> {
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _weightService = WeightService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingRecord();
  }

  /// 기존 기록이 있으면 자동 로드
  void _loadExistingRecord() {
    final existingRecord = _weightService.getRecordByDate(widget.date);
    if (existingRecord != null) {
      _weightController.text = existingRecord.weight.toStringAsFixed(1);
    }
  }
}
```

**UX 개선**:

- 기존 기록 있으면 자동으로 입력 필드에 표시
- 사용자는 수정만 하면 됨 (처음부터 입력 불필요)

#### 체중 입력 필드

```dart
TextFormField(
  controller: _weightController,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
  ],
  decoration: InputDecoration(
    hintText: '57.9',
    suffixText: 'g',
    // Material 3 스타일 테두리
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(
        color: AppColors.brandPrimary,
        width: 2,
      ),
    ),
  ),
  validator: (value) {
    if (value == null || value.isEmpty) {
      return '체중을 입력해주세요.';
    }
    final weight = double.tryParse(value);
    if (weight == null) {
      return '올바른 숫자를 입력해주세요.';
    }
    if (weight <= 0) {
      return '체중은 0보다 커야 합니다.';
    }
    return null;
  },
),
```

**입력 제한**:

- `inputFormatters`: 정규식으로 "숫자.소수점1자리"만 허용
  - 예: `57.9` ✅, `57.99` ❌, `abc` ❌
- `validator`: 빈 값, 음수, 문자 입력 방지

#### 저장 로직

```dart
Future<void> _onSave() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final weight = double.parse(_weightController.text);
    final record = WeightRecord(
      date: widget.date,
      weight: weight,
    );

    await _weightService.saveWeightRecord(record);

    if (mounted) {
      // 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오늘의 체중이 기록되었습니다!'),
          backgroundColor: AppColors.brandPrimary,
          duration: const Duration(seconds: 2),
        ),
      );

      // 이전 화면으로 돌아가며 refresh 신호 전달
      context.pop(true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('저장에 실패했습니다. 다시 시도해 주세요.'),
          backgroundColor: Colors.red,
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

1. `_formKey.currentState!.validate()`: 입력 검증 실패 시 조기 반환
2. `_isLoading`: 저장 중 버튼 비활성화 및 로딩 스피너 표시
3. `context.pop(true)`: **true 반환**으로 이전 화면에 "저장 성공" 신호 전달
4. `mounted` 체크: 비동기 작업 완료 후 위젯 트리 존재 여부 확인

#### 저장 버튼 (Gradient + 로딩 상태)

```dart
GestureDetector(
  onTap: _isLoading ? null : _onSave,
  child: Container(
    width: size.width - (AppSpacing.md * 2),
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: _isLoading
            ? [AppColors.lightGray, AppColors.mediumGray]
            : [AppColors.gradientTop, AppColors.brandPrimary],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: _isLoading ? [] : [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 4,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: _isLoading
        ? const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          )
        : Text(
            '저장하기',
            textAlign: TextAlign.center,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
  ),
),
```

**UX 디자인**:

- 로딩 중: 회색 gradient + 그림자 제거 + 스피너 표시
- 완료: 브랜드 gradient + 그림자 + "저장하기" 텍스트
- `onTap: _isLoading ? null : _onSave`: 로딩 중 중복 클릭 방지

#### 날짜 포맷팅

```dart
String _formatDate(DateTime date) {
  return '${date.year}년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일 체중 기록';
}
```

**결과 예시**: `2025년 11월 13일 체중 기록`

---

## 4. WeightDetailScreen 수정 사항

### 4.1 데이터 refresh 로직 추가

```dart
class _WeightDetailScreenState extends State<WeightDetailScreen> {
  late List<WeightRecord> weightRecords;
  final _weightService = WeightService();

  @override
  void initState() {
    super.initState();
    _loadWeightData();
  }

  /// 체중 데이터 로드
  void _loadWeightData() {
    weightRecords = _weightService.getWeightRecords();
  }

  /// 데이터 새로고침
  void _refreshData() {
    setState(() {
      _loadWeightData();
    });
  }
}
```

### 4.2 오늘 기록 버튼에 네비게이션 추가

```dart
Widget _buildAddRecordButton(Size size) {
  return GestureDetector(
    onTap: () async {
      // 오늘 체중 기록 화면으로 이동
      final result = await context.push(RoutePaths.weightAddToday);

      // 저장 후 돌아온 경우 데이터 새로고침
      if (result == true) {
        _refreshData();
      }
    },
    child: Container(
      // Gradient 버튼 스타일
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientTop, AppColors.brandPrimary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text('오늘의 몸무게 기록하기'),
        ],
      ),
    ),
  );
}
```

**핵심**:

- `await context.push()`: 비동기로 결과 대기
- `result == true`: `WeightAddScreen`에서 `pop(true)` 반환한 경우
- `_refreshData()`: `setState()` 호출로 차트/캘린더 재렌더링

### 4.3 캘린더 날짜 셀 클릭 기능

```dart
Widget _buildDayCell(int day, bool hasRecord, {bool isFuture = false}) {
  final cellDate = DateTime(selectedYear, selectedMonth, day);

  return GestureDetector(
    onTap: isFuture
        ? null
        : () async {
            // 특정 날짜 체중 기록 화면으로 이동
            final dateStr = cellDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
            final result = await context.push(
              RoutePaths.weightAdd.replaceAll(':date', dateStr),
            );

            // 저장 후 돌아온 경우 데이터 새로고침
            if (result == true) {
              _refreshData();
            }
          },
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          day.toString(),
          style: AppTypography.bodyMedium.copyWith(
            color: isFuture ? AppColors.lightGray : AppColors.mediumGray,
          ),
        ),
        const SizedBox(height: 4),
        if (hasRecord)
          Container(
            width: 16,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.brandPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
          )
        else
          const SizedBox(height: 4),
      ],
    ),
  );
}
```

**기능**:

- 미래 날짜: `onTap: null`로 클릭 비활성화
- 과거/오늘 날짜: 클릭 시 해당 날짜 기록 화면으로 이동
- `dateStr = YYYY-MM-DD`: ISO 8601 형식에서 날짜만 추출
- `replaceAll(':date', dateStr)`: `/weight/add/:date` → `/weight/add/2025-11-13`

---

## 5. 데이터 흐름 전체 시나리오

### 시나리오 1: 오늘 체중 기록

```
1. 사용자: WeightDetailScreen에서 "오늘의 몸무게 기록하기" 버튼 클릭
   ↓
2. 앱: context.push(RoutePaths.weightAddToday) → WeightAddScreen(date: DateTime.now())
   ↓
3. WeightAddScreen:
   - initState()에서 _loadExistingRecord() 호출
   - 오늘 기록 있으면 입력 필드에 표시
   ↓
4. 사용자: 체중 입력 (예: 57.9) → "저장하기" 클릭
   ↓
5. _onSave():
   - 입력 검증 (validator)
   - _isLoading = true → 버튼 로딩 상태
   - _weightService.saveWeightRecord(record)
   - SnackBar 표시: "오늘의 체중이 기록되었습니다!"
   - context.pop(true) → WeightDetailScreen으로 돌아가며 true 반환
   ↓
6. WeightDetailScreen:
   - result == true 확인
   - _refreshData() 호출 → setState() → UI 재렌더링
   - 차트에 새 데이터 포인트 표시
   - 캘린더 오늘 날짜에 오렌지 바 표시
```

### 시나리오 2: 특정 날짜 기록 수정

```
1. 사용자: 캘린더에서 11월 10일 클릭 (기록 이미 있음)
   ↓
2. 앱: context.push('/weight/add/2025-11-10')
   ↓
3. WeightAddScreen:
   - _loadExistingRecord()에서 11월 10일 기록 조회
   - 기존 체중 (예: 56.5g) 입력 필드에 표시
   ↓
4. 사용자: 체중 수정 (56.5 → 57.0) → "저장하기" 클릭
   ↓
5. _weightService.saveWeightRecord():
   - existingIndex = 3 (11월 10일 기록의 인덱스)
   - _records[3] = 새 WeightRecord(2025-11-10, 57.0)
   - 기존 기록 덮어쓰기 (Update)
   ↓
6. WeightDetailScreen:
   - _refreshData() → 차트와 캘린더 갱신
   - 11월 10일 데이터 포인트가 57.0으로 업데이트
```

---

## 6. UI/UX 디자인 세부사항

### 6.1 Material 3 디자인 시스템 활용

**AppBar**:

```dart
AppBar(
  backgroundColor: Colors.white,
  elevation: 0,
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.nearBlack),
    onPressed: () => context.pop(),
  ),
  title: Text(
    '체중 기록하기',
    style: AppTypography.bodyLarge.copyWith(
      fontWeight: FontWeight.w600,
      color: AppColors.brandPrimary,
    ),
  ),
  centerTitle: true,
)
```

**특징**:

- elevation: 0 → 그림자 없음 (플랫 디자인)
- 타이틀: 브랜드 컬러 (#FF9A42)
- 뒤로가기: iOS 스타일 화살표

### 6.2 입력 필드 포커스 상태

```dart
focusedBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.md),
  borderSide: const BorderSide(
    color: AppColors.brandPrimary,
    width: 2,
  ),
),
enabledBorder: OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppRadius.md),
  borderSide: const BorderSide(color: AppColors.lightGray),
),
```

**효과**:

- 포커스 시: 브랜드 컬러 2px 테두리
- 평상시: 연한 회색 1px 테두리
- 사용자가 현재 입력 중인 필드 명확히 인식

### 6.3 SnackBar 피드백

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('오늘의 체중이 기록되었습니다!'),
    backgroundColor: AppColors.brandPrimary,
    duration: const Duration(seconds: 2),
  ),
)
```

**UX**:

- 2초 자동 사라짐
- 브랜드 컬러로 일관된 디자인
- 성공/실패 색상 구분 (성공: 오렌지, 실패: 빨강)

---

## 7. 배운 점

### 7.1 Singleton 패턴 (Service Layer)

**구현**:

```dart
class WeightService {
  WeightService._();

  static final WeightService _instance = WeightService._();
  factory WeightService() => _instance;
}
```

**장점**:

- 앱 전체에서 하나의 데이터 소스만 유지
- 여러 화면에서 `WeightService()` 호출 시 같은 인스턴스 반환
- 데이터 일관성 보장

**사용 예**:

```dart
// 화면 A
final service1 = WeightService();
service1.saveWeightRecord(record);

// 화면 B
final service2 = WeightService();
final records = service2.getWeightRecords(); // service1과 같은 인스턴스
```

### 7.2 날짜 정규화의 중요성

**문제 상황**:

```dart
final date1 = DateTime(2025, 11, 13, 14, 30); // 오후 2시 30분
final date2 = DateTime(2025, 11, 13, 9, 15);  // 오전 9시 15분

if (date1 == date2) { // false! 시간이 달라서
  print('같은 날짜');
}
```

**해결**:

```dart
DateTime _normalizeDate(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

final normalized1 = _normalizeDate(date1); // 2025-11-13 00:00:00
final normalized2 = _normalizeDate(date2); // 2025-11-13 00:00:00

if (normalized1 == normalized2) { // true!
  print('같은 날짜');
}
```

### 7.3 Navigator.pop 결과 반환

**기존 방식 (비효율적)**:

```dart
// WeightDetailScreen
Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => WeightAddScreen()),
).then((_) {
  // 무조건 refresh (저장 안 해도 호출됨)
  _refreshData();
});
```

**개선 방식**:

```dart
// WeightAddScreen
context.pop(true); // 저장 성공 시에만 true

// WeightDetailScreen
final result = await context.push(RoutePaths.weightAddToday);
if (result == true) {
  _refreshData(); // 저장된 경우에만 refresh
}
```

**장점**:

- 불필요한 refresh 방지 (뒤로가기만 누른 경우)
- 명확한 의도 전달 (true = 데이터 변경됨)

### 7.4 TextFormField 입력 제한

**정규식 활용**:

```dart
FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}'))
```

**의미**:

- `^\d+`: 시작부터 1개 이상 숫자
- `\.?`: 소수점 0개 또는 1개
- `\d{0,1}`: 소수점 뒤 숫자 0~1개

**허용 예시**:

- `5` ✅
- `57` ✅
- `57.` ✅ (입력 중)
- `57.9` ✅
- `57.99` ❌ (소수점 2자리 차단)
- `abc` ❌ (문자 차단)

### 7.5 비동기 작업 후 mounted 체크

```dart
Future<void> _onSave() async {
  setState(() {
    _isLoading = true;
  });

  try {
    await _weightService.saveWeightRecord(record);

    if (mounted) { // ⭐ 중요!
      ScaffoldMessenger.of(context).showSnackBar(...);
      context.pop(true);
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

**이유**:

- `await` 중에 사용자가 뒤로가기 누르면 위젯 트리에서 제거됨
- `mounted == false` 상태에서 `setState()` 호출 시 에러 발생
- `if (mounted)` 체크로 안전하게 방어

---

## 8. 다음 단계 및 개선 사항

### 8.1 Supabase 연동 (백엔드 저장)

**현재**:

```dart
Future<void> saveWeightRecord(WeightRecord record) async {
  // 인메모리 저장
  _records[existingIndex] = record;

  // TODO: Supabase 저장
}
```

**추후 구현**:

```dart
Future<void> saveWeightRecord(WeightRecord record) async {
  // 1. 로컬 저장 (즉시 UI 반영)
  _records[existingIndex] = record;

  // 2. Supabase 저장 (비동기)
  try {
    await Supabase.instance.client
        .from('weight_records')
        .upsert(record.toJson());
  } catch (e) {
    // 오류 시 로컬 롤백
    _records.removeAt(existingIndex);
    rethrow;
  }
}
```

**DB 스키마**:

```sql
CREATE TABLE weight_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pet_id UUID REFERENCES pets(id),
  date DATE NOT NULL,
  weight DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(pet_id, date)
);
```

### 8.2 삭제 기능 추가

**UI**:

- 기록 화면에서 "삭제" 버튼 추가
- 확인 다이얼로그: "정말 삭제하시겠습니까?"

**코드**:

```dart
Future<void> _onDelete() async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('기록 삭제'),
      content: Text('이 날짜의 체중 기록을 삭제하시겠습니까?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('삭제'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _weightService.deleteWeightRecord(widget.date);
    context.pop(true); // 삭제 후 이전 화면 갱신
  }
}
```

### 8.3 사진 첨부 기능

- `image_picker` 패키지 사용
- 체중 기록과 함께 반려동물 사진 저장
- 캘린더에서 사진 썸네일 표시

**모델 확장**:

```dart
class WeightRecord {
  final DateTime date;
  final double weight;
  final String? photoUrl; // 추가
  final String? memo;     // 추가
}
```

### 8.4 단위 전환 (g ↔ kg)

```dart
// 토글 버튼
bool _isKg = false;

Text(
  _isKg
      ? '${(weight / 1000).toStringAsFixed(2)} kg'
      : '${weight.toStringAsFixed(1)} g',
)
```

### 8.5 목표 체중 설정 및 진행률

```dart
// 목표 체중 대비 진행률
final targetWeight = 60.0;
final currentWeight = 57.9;
final progress = (currentWeight / targetWeight * 100).clamp(0, 100);

LinearProgressIndicator(
  value: progress / 100,
  backgroundColor: AppColors.lightGray,
  valueColor: AlwaysStoppedAnimation(AppColors.brandPrimary),
)
```

### 8.6 차트 애니메이션

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: LineChart(
    key: ValueKey(selectedPeriod),
    // ...
  ),
)
```

---

## 결론

✅ **인메모리 Singleton 서비스** - 빠른 CRUD + 추후 Supabase 마이그레이션 용이
✅ **날짜 정규화** - 시간 제거로 "같은 날짜" 정확히 비교
✅ **Insert or Update 로직** - 동일 날짜 자동 덮어쓰기
✅ **Navigator.pop 결과 반환** - 저장 성공 시에만 UI 갱신
✅ **입력 검증** - 정규식 + validator로 양수 숫자만 허용
✅ **Material 3 디자인** - Gradient 버튼, 포커스 상태, SnackBar 피드백
✅ **로딩 상태** - 저장 중 버튼 비활성화 및 스피너 표시

체중 기록 기능의 핵심이 완성되었으며, Supabase 연동 및 사진/메모 추가 기능으로 확장 가능한 구조를 갖추었습니다. 📊
