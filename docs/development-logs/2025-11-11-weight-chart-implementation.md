# Flutter 체중 기록 차트 화면 구현

**날짜**: 2025-11-11
**파일**:
- [lib/src/screens/weight/weight_detail_screen.dart](../../lib/src/screens/weight/weight_detail_screen.dart)
- [lib/src/models/weight_record.dart](../../lib/src/models/weight_record.dart)

---

## 구현 목표

반려동물 체중 기록을 시각화하는 차트 화면을 구현합니다:

1. **기간 선택**: 주간/월간/연간 차트 전환
2. **라인 차트**: fl_chart를 활용한 부드러운 곡선 그래프
3. **캘린더 뷰**: 월별 기록 일자 표시
4. **데이터 계산**: 주차별/월별/연간 평균 자동 계산
5. **반응형 UI**: 상단 차트 + 하단 스크롤 캘린더

---

## 1. 화면 구조 및 레이아웃

### 1.1 전체 레이아웃

```dart
Scaffold
└─ SafeArea
   └─ Column
      ├─ _buildTopSection()        // 고정 영역 (차트)
      └─ Expanded
         └─ _buildBottomSheet()    // 스크롤 영역 (캘린더)
```

**디자인 결정**:
- 상단: 차트와 제목 영역 고정
- 하단: 캘린더를 스크롤 가능한 바텀시트 형태로 배치
- 바텀시트는 흰색 배경 + 상단 둥근 모서리 + 그림자

### 1.2 상태 관리

```dart
class _WeightDetailScreenState extends State<WeightDetailScreen> {
  late String selectedPeriod;    // '주', '월', '년'
  late int selectedWeek;         // 1~4주차
  late int selectedMonth;        // 1~12월
  late int selectedYear;         // 연도
  late List<WeightRecord> weightRecords;  // 전체 기록 데이터

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    selectedPeriod = '월';
    selectedYear = now.year;
    selectedMonth = now.month;

    // 현재 월의 몇 주차인지 계산
    final weekOfMonth = ((now.day - 1) / 7).floor() + 1;
    selectedWeek = weekOfMonth.clamp(1, 4);

    // 데이터 로드 (실제로는 DB에서 가져옴)
    weightRecords = WeightData.getCurrentMonthData();
  }
}
```

**상태 초기화**:
- 기본 기간: '월' 선택
- 현재 년/월/주차 자동 계산
- 더미 데이터로 초기화 (향후 DB 연동)

---

## 2. 기간 선택 UI

### 2.1 탭 스타일 선택기

```dart
Widget _buildPeriodSelector() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.brandPrimary, width: 1),
      borderRadius: BorderRadius.circular(AppRadius.xl),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPeriodButton('주'),
        _buildPeriodButton('월'),
        _buildPeriodButton('년'),
      ],
    ),
  );
}

Widget _buildPeriodButton(String period) {
  final isSelected = selectedPeriod == period;
  return GestureDetector(
    onTap: () {
      setState(() {
        selectedPeriod = period;
      });
    },
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.brandPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        period,
        style: AppTypography.bodySmall.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
          color: isSelected ? Colors.white : AppColors.mediumGray,
        ),
      ),
    ),
  );
}
```

**디자인 특징**:
- 브랜드 컬러 테두리로 버튼 그룹 강조
- 선택된 탭: 브랜드 배경 + 흰색 텍스트 + 굵은 글씨
- 미선택 탭: 투명 배경 + 회색 텍스트

---

## 3. fl_chart를 활용한 라인 차트 구현

### 3.1 fl_chart 패키지 추가

**pubspec.yaml**:
```yaml
dependencies:
  fl_chart: ^0.70.2
```

### 3.2 공통 차트 설정

모든 차트(주간/월간/연간)에서 공통으로 사용하는 설정:

```dart
LineChartData(
  minX: ...,
  maxX: ...,
  minY: _getMinY(data),
  maxY: _getMaxY(data),
  lineBarsData: [...],
  titlesData: FlTitlesData(...),
  gridData: const FlGridData(show: false),  // 그리드 숨김
  borderData: FlBorderData(show: false),    // 테두리 숨김
  lineTouchData: LineTouchData(...),
)
```

**디자인 철학**:
- 그리드와 테두리 제거로 미니멀한 차트
- 브랜드 컬러를 활용한 일관된 스타일
- 터치 시 툴팁으로 정확한 값 표시

### 3.3 주간 차트 (일~토, 7일)

```dart
Widget _buildWeeklyChart(Size size) {
  final chartWidth = size.width - (AppSpacing.md * 2);
  final chartHeight = 200.0;
  final weeklyData = _calculateWeeklyData(selectedYear, selectedMonth, selectedWeek);

  return Container(
    width: chartWidth,
    height: chartHeight,
    padding: const EdgeInsets.only(
      top: AppSpacing.md,
      bottom: AppSpacing.lg,
      left: AppSpacing.sm,
      right: AppSpacing.sm,
    ),
    child: LineChart(
      LineChartData(
        minX: 1,
        maxX: 7,
        minY: _getMinY(weeklyData),
        maxY: _getMaxY(weeklyData),
        lineBarsData: [
          LineChartBarData(
            spots: _convertMapToFlSpots(weeklyData),
            isCurved: true,               // 부드러운 곡선
            curveSmoothness: 0.35,        // 곡선 부드러움 정도
            color: AppColors.brandPrimary,
            barWidth: 2,
            isStrokeCapRound: true,       // 선 끝 둥글게
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 5,
                  color: AppColors.brandPrimary,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final day = value.toInt();
              if (day < 1 || day > 7) return const SizedBox();

              const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
              return Text(
                weekdays[day - 1],
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.mediumGray,
                  fontWeight: FontWeight.w400,
                ),
              );
            },
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} g',
                  AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    ),
  );
}
```

**주요 설정**:
- `minX: 1, maxX: 7`: X축은 1=일, 2=월, ..., 7=토
- `isCurved: true, curveSmoothness: 0.35`: 부드러운 곡선 (너무 과하지 않게)
- `dotData`: 각 포인트에 5px 원형 점 표시 (흰색 테두리 2px)
- `getTitlesWidget`: X축에 요일 라벨 표시

### 3.4 월간 차트 (최근 6개월)

```dart
Widget _buildMonthlyChart(Size size) {
  final chartWidth = size.width - (AppSpacing.md * 2);
  final chartHeight = 200.0;

  final now = DateTime.now();
  final minMonth = (now.month - 5).clamp(1, 12);
  final maxMonth = now.month;

  final monthlyAverages = _calculateMonthlyAverages();

  return Container(
    width: chartWidth,
    height: chartHeight,
    padding: const EdgeInsets.only(...),
    child: LineChart(
      LineChartData(
        minX: minMonth.toDouble(),
        maxX: maxMonth.toDouble(),
        minY: _getMinY(monthlyAverages),
        maxY: _getMaxY(monthlyAverages),
        lineBarsData: [
          LineChartBarData(
            spots: _convertMapToFlSpots(monthlyAverages),
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.brandPrimary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final month = spot.x.toInt();
                final isHighlighted = month == selectedMonth;

                if (isHighlighted) {
                  return FlDotCirclePainter(
                    radius: 8,
                    color: AppColors.brandPrimary,
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  );
                }
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.lightGray,
                );
              },
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          verticalLines: [
            if (monthlyAverages[selectedMonth] != null &&
                monthlyAverages[selectedMonth]! > 0)
              VerticalLine(
                x: selectedMonth.toDouble(),
                color: AppColors.brandPrimary.withValues(alpha: 0.15),
                strokeWidth: 53,
                label: VerticalLineLabel(
                  show: true,
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 10),
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  labelResolver: (line) {
                    final value = monthlyAverages[selectedMonth] ?? 0;
                    return '${value.toStringAsFixed(1)} g';
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
```

**핵심 기능**:
- **하이라이트 점**: 선택된 월은 8px 큰 점, 나머지는 3px 작은 점
- **수직선**: `extraLinesData`로 선택된 월에 반투명 배경 + 값 라벨 표시
- **동적 범위**: 현재 월 기준 최근 6개월만 표시

### 3.5 연간 차트 (1~12월)

```dart
Widget _buildYearlyChart(Size size) {
  final yearlyData = _calculateYearlyAverages(selectedYear);

  return Container(
    width: chartWidth,
    height: chartHeight,
    child: LineChart(
      LineChartData(
        minX: 1,
        maxX: 12,
        minY: _getMinY(yearlyData),
        maxY: _getMaxY(yearlyData),
        lineBarsData: [
          LineChartBarData(
            spots: _convertMapToFlSpots(yearlyData),
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.brandPrimary,
            barWidth: 2,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final month = spot.x.toInt();
                final isHighlighted = month == selectedMonth;

                if (isHighlighted) {
                  return FlDotCirclePainter(
                    radius: 8,
                    color: AppColors.brandPrimary,
                    strokeWidth: 3,
                    strokeColor: Colors.white,
                  );
                }
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.lightGray,
                );
              },
            ),
          ),
        ],
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final month = value.toInt();
              if (month < 1 || month > 12) return const SizedBox();

              final isHighlighted = month == selectedMonth;

              return Text(
                '$month월',
                style: AppTypography.bodySmall.copyWith(
                  color: isHighlighted
                      ? AppColors.brandPrimary
                      : AppColors.mediumGray,
                  fontWeight: isHighlighted
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}
```

**특징**:
- 월간 차트와 동일한 하이라이트 로직
- X축 라벨: 선택된 월은 브랜드 컬러 + 굵게, 나머지는 회색

---

## 4. 데이터 계산 로직

### 4.1 주간 데이터 계산

```dart
Map<int, double> _calculateWeeklyData(int year, int month, int weekNumber) {
  final Map<int, List<double>> weeklyData = {};

  // 해당 주차의 시작일과 종료일 계산
  final startDay = (weekNumber - 1) * 7 + 1;
  final endDay = (startDay + 6).clamp(1, DateTime(year, month + 1, 0).day);

  // 해당 주차의 데이터만 필터링
  for (final record in weightRecords) {
    if (record.date.year == year &&
        record.date.month == month &&
        record.date.day >= startDay &&
        record.date.day <= endDay) {
      final weekday = record.date.weekday % 7; // 0=일, 1=월, ..., 6=토
      final displayDay = weekday + 1; // 1=일, 2=월, ..., 7=토
      if (!weeklyData.containsKey(displayDay)) {
        weeklyData[displayDay] = [];
      }
      weeklyData[displayDay]!.add(record.weight);
    }
  }

  // 요일별 평균 계산
  final Map<int, double> averages = {};
  weeklyData.forEach((weekday, weights) {
    averages[weekday] = weights.reduce((a, b) => a + b) / weights.length;
  });

  return averages;
}
```

**핵심 로직**:
- **주차 계산**: `startDay = (weekNumber - 1) * 7 + 1` (1주차 = 1~7일)
- **요일 변환**: `weekday % 7`로 일요일=0으로 변환 후 `+1`로 차트 X축(1~7)에 맞춤
- **평균 계산**: 같은 요일에 여러 기록이 있을 경우 평균값 사용

### 4.2 월간 데이터 계산 (최근 6개월 평균)

```dart
Map<int, double> _calculateMonthlyAverages() {
  final Map<int, List<double>> monthlyData = {};

  // 월별로 데이터 그룹화
  for (final record in weightRecords) {
    final month = record.date.month;
    if (!monthlyData.containsKey(month)) {
      monthlyData[month] = [];
    }
    monthlyData[month]!.add(record.weight);
  }

  // 월별 평균 계산
  final Map<int, double> averages = {};
  monthlyData.forEach((month, weights) {
    averages[month] = weights.reduce((a, b) => a + b) / weights.length;
  });

  return averages;
}
```

### 4.3 연간 데이터 계산

```dart
Map<int, double> _calculateYearlyAverages(int year) {
  final Map<int, List<double>> yearlyData = {};

  // 해당 년도의 데이터만 필터링 및 그룹화
  for (final record in weightRecords) {
    if (record.date.year == year) {
      final month = record.date.month;
      if (!yearlyData.containsKey(month)) {
        yearlyData[month] = [];
      }
      yearlyData[month]!.add(record.weight);
    }
  }

  // 월별 평균 계산
  final Map<int, double> averages = {};
  yearlyData.forEach((month, weights) {
    averages[month] = weights.reduce((a, b) => a + b) / weights.length;
  });

  return averages;
}
```

---

## 5. 헬퍼 함수

### 5.1 Map 데이터를 FlSpot으로 변환

```dart
List<FlSpot> _convertMapToFlSpots(Map<int, double> data) {
  final spots = data.entries
      .where((entry) => entry.value > 0)
      .map((entry) => FlSpot(
            entry.key.toDouble(),
            entry.value,
          ))
      .toList();

  // X축 기준으로 정렬하여 자연스러운 연결 보장
  spots.sort((a, b) => a.x.compareTo(b.x));
  return spots;
}
```

**중요 포인트**:
- `value > 0` 조건으로 빈 데이터(0.0) 필터링
- **정렬**: X축 기준 정렬로 차트 선이 순서대로 자연스럽게 연결되도록 보장
  - Map은 키 순서를 보장하지 않으므로 명시적 정렬 필요
  - 정렬하지 않으면 선이 지그재그로 그려지는 문제 발생

### 5.2 Y축 범위 자동 계산

```dart
double _getMinY(Map<int, double> data) {
  final values = data.values.where((v) => v > 0);
  if (values.isEmpty) return 0;
  final minValue = values.reduce((a, b) => a < b ? a : b);
  return minValue - 5; // 여유 공간
}

double _getMaxY(Map<int, double> data) {
  final values = data.values.where((v) => v > 0);
  if (values.isEmpty) return 100;
  final maxValue = values.reduce((a, b) => a > b ? a : b);
  return maxValue + 5; // 여유 공간
}
```

**로직**:
- 실제 데이터 최소/최대값 계산
- ±5의 여유 공간으로 차트가 화면 끝에 닿지 않도록 배려

---

## 6. 캘린더 뷰 구현

### 6.1 캘린더 헤더 (요일)

```dart
Widget _buildCalendarHeader() {
  const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceAround,
    children: weekdays.map((day) {
      return Expanded(
        child: Center(
          child: Text(
            day,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
        ),
      );
    }).toList(),
  );
}
```

### 6.2 캘린더 그리드

```dart
Widget _buildCalendarGrid() {
  final now = DateTime.now();
  final firstDayOfMonth = DateTime(selectedYear, selectedMonth, 1);
  final startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
  final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;

  final List<Widget> dayWidgets = [];

  // Add empty cells for days before the 1st
  for (int i = 0; i < startWeekday; i++) {
    dayWidgets.add(const SizedBox());
  }

  // Add day cells
  for (int day = 1; day <= daysInMonth; day++) {
    final hasRecord = weightRecords.any((record) =>
        record.date.day == day &&
        record.date.month == selectedMonth &&
        record.date.year == selectedYear);

    final isFuture = DateTime(selectedYear, selectedMonth, day)
        .isAfter(DateTime(now.year, now.month, now.day));

    dayWidgets.add(_buildDayCell(day, hasRecord, isFuture: isFuture));
  }

  return GridView.count(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: 7,
    mainAxisSpacing: AppSpacing.md,
    crossAxisSpacing: AppSpacing.sm,
    children: dayWidgets,
  );
}
```

**핵심 로직**:
- `startWeekday`: 1일이 시작하는 요일 계산 (일요일=0)
- 빈 셀 추가: 1일 이전 공백으로 정렬
- `hasRecord`: 해당 날짜에 기록 있는지 확인
- `isFuture`: 미래 날짜는 회색 처리

### 6.3 날짜 셀

```dart
Widget _buildDayCell(int day, bool hasRecord, {bool isFuture = false}) {
  return Column(
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
  );
}
```

**디자인**:
- 날짜 숫자 아래에 기록 인디케이터 표시
- 기록 있음: 브랜드 컬러 바 (16x4px)
- 미래 날짜: 연한 회색으로 구분

---

## 7. 바텀시트 스타일

### 7.1 드래그 핸들 및 헤더

```dart
Widget _buildBottomSheet(Size size, EdgeInsets padding) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(AppRadius.lg),
        topRight: Radius.circular(AppRadius.lg),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 10,
          offset: const Offset(0, 0),
        ),
      ],
    ),
    child: Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          width: 36,
          height: 5,
          decoration: BoxDecoration(
            color: AppColors.lightGray,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),

        // Calendar Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '사랑이의 몸무게 총 ${weightRecords.length}일 기록 중',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _onPreviousPeriod,
                    iconSize: 20,
                  ),
                  Text(
                    _getPeriodLabel(),
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.nearBlack,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _onNextPeriod,
                    iconSize: 20,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Calendar Grid
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                _buildCalendarHeader(),
                const SizedBox(height: AppSpacing.sm),
                _buildCalendarGrid(),
                const SizedBox(height: AppSpacing.xl),
                _buildAddRecordButton(size),
                SizedBox(height: padding.bottom + AppSpacing.lg),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
```

**UI 요소**:
- **핸들**: 36x5px 회색 바 (드래그 가능한 느낌)
- **헤더**: 총 기록 일수 + 기간 네비게이션 (좌우 화살표)
- **스크롤**: 캘린더 그리드 + 기록 버튼

### 7.2 기간 네비게이션

```dart
String _getPeriodLabel() {
  switch (selectedPeriod) {
    case '주':
      return '$selectedWeek주차';
    case '월':
      return '$selectedMonth월';
    case '년':
      return '$selectedYear년';
    default:
      return '$selectedMonth월';
  }
}

void _onPreviousPeriod() {
  setState(() {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case '주':
        if (selectedWeek > 1) selectedWeek--;
        break;
      case '월':
        final minMonth = (now.month - 5).clamp(1, 12);
        if (selectedMonth > minMonth) selectedMonth--;
        break;
      case '년':
        if (selectedYear > now.year - 1) selectedYear--;
        break;
    }
  });
}

void _onNextPeriod() {
  setState(() {
    final now = DateTime.now();
    switch (selectedPeriod) {
      case '주':
        if (selectedWeek < 4) selectedWeek++;
        break;
      case '월':
        if (selectedMonth < now.month) selectedMonth++;
        break;
      case '년':
        if (selectedYear < now.year) selectedYear++;
        break;
    }
  });
}
```

**로직**:
- 주간: 1~4주차만 이동
- 월간: 최근 6개월 범위 내에서만 이동
- 연간: 작년~올해만 이동

---

## 8. 더미 데이터 모델

### 8.1 WeightRecord 모델

```dart
class WeightRecord {
  final DateTime date;
  final double weight; // in grams

  const WeightRecord({
    required this.date,
    required this.weight,
  });
}
```

### 8.2 더미 데이터 생성

```dart
class WeightData {
  static List<WeightRecord> getCurrentMonthData() {
    final now = DateTime.now();
    final year = now.year;
    final month = now.month;

    final List<WeightRecord> records = [];

    // 최근 6개월 동안의 더미 데이터 생성
    for (int monthOffset = 5; monthOffset >= 0; monthOffset--) {
      final targetMonth = month - monthOffset;
      if (targetMonth < 1) continue;

      final baseWeight = 52.0 + (targetMonth * 0.6);

      records.add(WeightRecord(date: DateTime(year, targetMonth, 2), weight: baseWeight + 0.2));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 5), weight: baseWeight + 0.5));
      records.add(WeightRecord(date: DateTime(year, targetMonth, 8), weight: baseWeight + 0.8));
      // ... (더 많은 날짜 추가)
    }

    return records;
  }
}
```

**특징**:
- 최근 6개월치 데이터 자동 생성
- 점진적 증가 패턴 (월별 +0.6g)
- 현재 날짜 이후는 생성 안 함

---

## 배운 점

### 1. **fl_chart 라이브러리 활용**

**기본 사용법**:
```dart
LineChart(
  LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: [FlSpot(1, 50), FlSpot(2, 55), FlSpot(3, 53)],
        isCurved: true,
      ),
    ],
  ),
)
```

**핵심 설정**:
- `isCurved`: 직선 vs 곡선
- `curveSmoothness`: 0.0~1.0 (곡선 부드러움)
- `dotData`: 각 포인트 표시 여부 및 스타일
- `belowBarData`: 선 아래 영역 색칠 여부
- `extraLinesData`: 수직/수평선 추가 (하이라이트용)

### 2. **데이터 정렬의 중요성**

**문제 상황**:
```dart
// Map은 키 순서를 보장하지 않음
final data = {3: 55.0, 1: 50.0, 2: 53.0};
final spots = data.entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
// 차트: 3→1→2 순서로 연결되어 지그재그 발생
```

**해결**:
```dart
spots.sort((a, b) => a.x.compareTo(b.x));
// 차트: 1→2→3 순서로 자연스럽게 연결
```

### 3. **DateTime 계산 기법**

**주차 계산**:
```dart
final startDay = (weekNumber - 1) * 7 + 1;
// 1주차: 1일, 2주차: 8일, 3주차: 15일, 4주차: 22일
```

**요일 변환** (일요일=1로 만들기):
```dart
final weekday = date.weekday % 7; // 0=일, 1=월, ..., 6=토
final displayDay = weekday + 1;   // 1=일, 2=월, ..., 7=토
```

**월의 마지막 날**:
```dart
final daysInMonth = DateTime(year, month + 1, 0).day;
// month+1월의 0일 = month월의 마지막 날
```

### 4. **조건부 하이라이트**

**선택된 월 강조**:
```dart
getDotPainter: (spot, percent, barData, index) {
  final month = spot.x.toInt();
  final isHighlighted = month == selectedMonth;

  if (isHighlighted) {
    return FlDotCirclePainter(
      radius: 8,                      // 큰 점
      color: AppColors.brandPrimary,
      strokeWidth: 3,
      strokeColor: Colors.white,
    );
  }
  return FlDotCirclePainter(
    radius: 3,                        // 작은 점
    color: AppColors.lightGray,
  );
},
```

### 5. **Y축 자동 범위 설정**

고정 범위(예: 0~100) 대신 데이터 기반 동적 범위:
```dart
minY: _getMinY(data),  // 실제 최소값 - 5
maxY: _getMaxY(data),  // 실제 최대값 + 5
```

**장점**:
- 작은 변화도 확대되어 보임
- 화면 공간 효율적 사용
- 데이터 트렌드 명확히 파악

### 6. **스크롤 영역 분리**

상단 고정 + 하단 스크롤 구조:
```dart
Column(
  children: [
    _buildTopSection(),      // 고정
    Expanded(
      child: SingleChildScrollView(
        child: _buildBottomSheet(),  // 스크롤
      ),
    ),
  ],
)
```

**주의사항**:
- `GridView.count` 내부에서는 `shrinkWrap: true, physics: NeverScrollableScrollPhysics` 필수
- 그렇지 않으면 스크롤 충돌 발생

### 7. **fl_chart 터치 인터랙션**

```dart
lineTouchData: LineTouchData(
  enabled: true,
  touchTooltipData: LineTouchTooltipData(
    getTooltipItems: (touchedSpots) {
      return touchedSpots.map((spot) {
        return LineTooltipItem(
          '${spot.y.toStringAsFixed(1)} g',
          AppTypography.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList();
    },
  ),
),
```

**기능**:
- 차트 터치 시 해당 포인트의 정확한 값 표시
- 툴팁 스타일 커스터마이징 가능

---

## 다음 단계

### 1. **실제 데이터 연동**

```dart
// TODO: DB에서 체중 기록 가져오기
Future<List<WeightRecord>> loadWeightRecords() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query('weight_records');
  return List.generate(maps.length, (i) {
    return WeightRecord(
      date: DateTime.parse(maps[i]['date']),
      weight: maps[i]['weight'],
    );
  });
}
```

### 2. **기록 추가 기능**

- 바텀시트: 날짜 선택 + 체중 입력 (kg/g 단위 전환)
- 사진 첨부 옵션
- 메모 작성

### 3. **애니메이션 개선**

```dart
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: _buildChart(size),
  key: ValueKey(selectedPeriod),
)
```

- 기간 전환 시 부드러운 애니메이션
- 차트 데이터 업데이트 시 트윈 애니메이션

### 4. **통계 정보 추가**

- 기간별 평균 체중
- 증감률 (전 기간 대비 %)
- 목표 체중 대비 진행률

### 5. **차트 확대/축소**

```dart
InteractiveViewer(
  minScale: 1.0,
  maxScale: 3.0,
  child: LineChart(...),
)
```

### 6. **데이터 내보내기**

- CSV 파일로 저장
- 이미지(차트 스크린샷) 공유

---

## 결론

✅ **fl_chart 기반 라인 차트** - 주간/월간/연간 3가지 뷰
✅ **부드러운 곡선 그래프** - `isCurved: true, curveSmoothness: 0.35`
✅ **동적 데이터 계산** - 주차별/월별/연간 평균 자동 계산
✅ **하이라이트 기능** - 선택된 기간 강조 (큰 점 + 수직선)
✅ **캘린더 뷰** - 월별 기록 일자 인디케이터
✅ **반응형 레이아웃** - 상단 고정 + 하단 스크롤
✅ **데이터 정렬** - X축 기준 정렬로 자연스러운 선 연결

반려동물 체중 기록을 시각적으로 추적할 수 있는 차트 화면이 완성되었습니다. 향후 실제 DB 연동 및 기록 추가 기능을 구현하면 완전한 체중 관리 시스템이 됩니다. 📊
