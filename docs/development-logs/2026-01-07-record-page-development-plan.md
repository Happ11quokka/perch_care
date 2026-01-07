# 기록 페이지 개발 계획

**작성일**: 2026-01-07
**대상 화면**: 기록(Record) 페이지 - 네비게이션 바 중간 버튼

## 개요

이 문서는 기록 페이지 개발을 위한 사전 조사 및 개발 계획을 정리한 것입니다.

---

## 1. 스무스 차트 구현 (fl_chart)

### 현재 상태
- 프로젝트에 이미 `fl_chart: ^0.68.0` 설치됨
- 체중 기록 화면에서 사용 중

### 스무스 곡선 구현 방법

fl_chart의 `LineChartBarData`에서 다음 속성들을 사용:

```dart
LineChartBarData(
  // 곡선 활성화
  isCurved: true,

  // 곡선 부드러움 정도 (0.0 ~ 1.0)
  // 0.35 ~ 0.5 권장 (자연스러운 곡선)
  curveSmoothness: 0.5,

  // 곡선이 데이터 포인트를 넘어가는 것 방지
  preventCurveOverShooting: true,
  preventCurveOvershootingThreshold: 15.0,

  // 선 스타일
  barWidth: 4.0,
  isStrokeCapRound: true,

  // 데이터 포인트 숨기기 (선만 표시)
  dotData: FlDotData(show: false),

  // 선 아래 그라데이션 채우기
  belowBarData: BarAreaData(
    show: true,
    gradient: LinearGradient(
      colors: [
        AppColors.brandPrimary.withOpacity(0.3),
        AppColors.brandPrimary.withOpacity(0.0),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  ),

  // 데이터 포인트
  spots: [
    FlSpot(0, 5.2),  // 일요일
    FlSpot(1, 5.5),  // 월요일
    FlSpot(2, 5.3),  // 화요일
    // ...
  ],
)
```

### 핵심 파라미터 설명

| 파라미터 | 설명 | 권장값 |
|---------|------|--------|
| `isCurved` | 곡선 사용 여부 | `true` |
| `curveSmoothness` | 곡선 부드러움 (0~1) | `0.35 ~ 0.5` |
| `preventCurveOverShooting` | 오버슈팅 방지 | `true` |
| `preventCurveOvershootingThreshold` | 오버슈팅 임계값 | `15.0` |

### 디자인 적용 고려사항
- 하루에 데이터 포인트 1개 (일일 기록)
- X축: 요일 (일~토)
- Y축: 기록 값
- 선 색상: 브랜드 컬러 (#FF9A42)
- 그라데이션 채우기로 시각적 강조

---

## 2. 캘린더 위젯 (table_calendar)

### 패키지 추가 필요

```yaml
dependencies:
  table_calendar: ^3.1.2
```

### 기본 구현

```dart
import 'package:table_calendar/table_calendar.dart';

class RecordCalendar extends StatefulWidget {
  @override
  _RecordCalendarState createState() => _RecordCalendarState();
}

class _RecordCalendarState extends State<RecordCalendar> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 이벤트 데이터 (기록이 있는 날짜)
  final Map<DateTime, List<Event>> _events = {};

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      // 기본 설정
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,

      // 선택된 날짜 표시
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),

      // 날짜 선택 핸들러
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },

      // 이벤트 로더 (기록이 있는 날짜에 마커 표시)
      eventLoader: (day) => _getEventsForDay(day),

      // 스타일 커스터마이징
      calendarStyle: CalendarStyle(
        // 오늘 날짜 스타일
        todayDecoration: BoxDecoration(
          color: AppColors.brandPrimary.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        // 선택된 날짜 스타일
        selectedDecoration: BoxDecoration(
          color: AppColors.brandPrimary,
          shape: BoxShape.circle,
        ),
        // 이벤트 마커 스타일
        markerDecoration: BoxDecoration(
          color: AppColors.brandPrimary,
          shape: BoxShape.circle,
        ),
      ),

      // 헤더 스타일
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: AppTypography.h5,
      ),

      // 커스텀 빌더 (더 세밀한 커스터마이징)
      calendarBuilders: CalendarBuilders(
        // 기록이 있는 날짜에 커스텀 마커
        markerBuilder: (context, date, events) {
          if (events.isEmpty) return null;
          return Positioned(
            bottom: 1,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Event> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }
}
```

### 디자인 맞춤 요소
- 요일 헤더: 일, 월, 화, 수, 목, 금, 토
- 선택된 날짜: 원형 배경 + 브랜드 컬러
- 기록 있는 날짜: 하단 점 마커
- 월 이동: 좌우 화살표

---

## 3. 시간 선택기 (Time Picker)

### 옵션 비교

| 방식 | 장점 | 단점 | 추천도 |
|-----|------|------|-------|
| Flutter 기본 `showTimePicker` | 간단한 구현, 플랫폼 일관성 | 디자인 커스터마이징 제한 | ★★★☆☆ |
| `progressive_time_picker` | 시간 범위 선택 가능, 커스터마이징 | 추가 패키지 필요 | ★★★★☆ |
| `wheel_picker` | iOS 스타일 휠, 직관적 | 아날로그 시계 UI 아님 | ★★★☆☆ |
| **커스텀 구현** | 디자인 완벽 구현 가능 | 개발 시간 필요 | ★★★★★ |

### 추천: 커스텀 아날로그 시계 구현

Figma 디자인에 맞는 아날로그 시계 시간 선택기 구현:

```dart
class AnalogTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const AnalogTimePicker({
    required this.initialTime,
    required this.onTimeChanged,
  });

  @override
  _AnalogTimePickerState createState() => _AnalogTimePickerState();
}

class _AnalogTimePickerState extends State<AnalogTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;
  bool _isAM = true;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hourOfPeriod;
    _selectedMinute = widget.initialTime.minute;
    _isAM = widget.initialTime.period == DayPeriod.am;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // AM/PM 토글
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildPeriodButton('AM', _isAM),
            SizedBox(width: 16),
            _buildPeriodButton('PM', !_isAM),
          ],
        ),

        SizedBox(height: 24),

        // 아날로그 시계
        GestureDetector(
          onPanUpdate: _handlePanUpdate,
          child: CustomPaint(
            size: Size(280, 280),
            painter: ClockPainter(
              hour: _selectedHour,
              minute: _selectedMinute,
              brandColor: AppColors.brandPrimary,
            ),
          ),
        ),

        SizedBox(height: 24),

        // 선택된 시간 표시
        Text(
          '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')} ${_isAM ? 'AM' : 'PM'}',
          style: AppTypography.h3,
        ),
      ],
    );
  }

  Widget _buildPeriodButton(String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAM = label == 'AM';
          _updateTime();
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.gray300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.gray600,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    // 터치 위치로부터 각도 계산하여 시간 업데이트
    // 구현 필요
  }

  void _updateTime() {
    final hour = _isAM ? _selectedHour : _selectedHour + 12;
    widget.onTimeChanged(TimeOfDay(hour: hour % 24, minute: _selectedMinute));
  }
}

// CustomPainter로 시계 UI 그리기
class ClockPainter extends CustomPainter {
  final int hour;
  final int minute;
  final Color brandColor;

  ClockPainter({
    required this.hour,
    required this.minute,
    required this.brandColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 시계 외곽
    final outerPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius - 10, outerPaint);

    // 시간 눈금 (1-12)
    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * pi / 180;
      final textOffset = Offset(
        center.dx + (radius - 40) * cos(angle),
        center.dy + (radius - 40) * sin(angle),
      );
      // 숫자 그리기
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            color: i == hour ? brandColor : Colors.black54,
            fontSize: 18,
            fontWeight: i == hour ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        textOffset - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // 시침
    final hourAngle = ((hour % 12) * 30 + minute * 0.5 - 90) * pi / 180;
    final hourHandEnd = Offset(
      center.dx + (radius - 80) * cos(hourAngle),
      center.dy + (radius - 80) * sin(hourAngle),
    );
    final hourPaint = Paint()
      ..color = brandColor
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, hourHandEnd, hourPaint);

    // 중심점
    canvas.drawCircle(center, 8, Paint()..color = brandColor);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

---

## 4. 색상 팔레트 선택기

### 디자인 분석
- 8가지 사전 정의된 색상
- 원형 버튼으로 표시
- 선택 시 체크 표시 또는 테두리 강조

### 구현

```dart
class ColorPalettePicker extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  // 정의된 색상 팔레트
  static const List<Color> colors = [
    Color(0xFFFF9A42),  // Orange (브랜드 컬러)
    Color(0xFFFF6B6B),  // Red
    Color(0xFF4ECDC4),  // Teal
    Color(0xFF45B7D1),  // Blue
    Color(0xFF96CEB4),  // Green
    Color(0xFFFECA57),  // Yellow
    Color(0xFFDDA0DD),  // Plum
    Color(0xFF778899),  // Slate Gray
  ];

  const ColorPalettePicker({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: colors.map((color) {
        final isSelected = color == selectedColor;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.black, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: isSelected
                ? Icon(Icons.check, color: Colors.white, size: 24)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
```

---

## 5. 바텀 시트 구현

### 기록 추가 바텀 시트

```dart
void showAddRecordBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // 드래그 핸들
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 바텀 시트 컨텐츠
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 날짜 선택
                      _buildDateSelector(),

                      SizedBox(height: 24),

                      // 시간 범위 선택
                      _buildTimeRangeSelector(),

                      SizedBox(height: 24),

                      // 제목 입력
                      _buildTitleInput(),

                      SizedBox(height: 24),

                      // 색상 선택
                      Text('색상', style: AppTypography.h6),
                      SizedBox(height: 12),
                      ColorPalettePicker(
                        selectedColor: _selectedColor,
                        onColorSelected: (color) {
                          setState(() => _selectedColor = color);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 저장 버튼
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveRecord,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text('저장', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}
```

---

## 6. 화면 구조

### 메인 기록 화면 레이아웃

```
┌─────────────────────────────────────┐
│         헤더 (2024년 11월)           │
├─────────────────────────────────────┤
│                                     │
│         스무스 라인 차트              │
│         (주간 데이터)                │
│                                     │
├─────────────────────────────────────┤
│                                     │
│         캘린더 위젯                  │
│         (월간 보기)                  │
│                                     │
├─────────────────────────────────────┤
│                                     │
│         일정 목록                    │
│         (선택된 날짜의 기록들)        │
│                                     │
├─────────────────────────────────────┤
│         [+] 추가 버튼                │
└─────────────────────────────────────┘
```

---

## 7. 개발 단계

### Phase 1: 기본 구조 설정
- [ ] `lib/src/screens/record/` 디렉토리 생성
- [ ] `record_screen.dart` 메인 화면 파일 생성
- [ ] 라우터에 기록 화면 경로 추가
- [ ] `table_calendar` 패키지 추가

### Phase 2: 차트 구현
- [ ] 스무스 라인 차트 위젯 구현
- [ ] 주간 데이터 표시
- [ ] 그라데이션 및 스타일 적용

### Phase 3: 캘린더 구현
- [ ] TableCalendar 위젯 통합
- [ ] 커스텀 스타일 적용
- [ ] 이벤트 마커 구현

### Phase 4: 바텀 시트 및 입력 폼
- [ ] 기록 추가 바텀 시트 구현
- [ ] 날짜/시간 선택기 구현
- [ ] 색상 팔레트 선택기 구현
- [ ] 아날로그 시계 시간 선택기 구현

### Phase 5: 데이터 연동
- [ ] 기록 데이터 모델 정의
- [ ] Supabase 연동 (CRUD)
- [ ] 상태 관리 구현

---

## 8. 필요한 패키지

```yaml
dependencies:
  # 기존 패키지
  fl_chart: ^0.68.0  # 이미 설치됨

  # 추가 필요 패키지
  table_calendar: ^3.1.2  # 캘린더 위젯
```

---

## 9. 참고 자료

- [fl_chart Documentation](https://pub.dev/packages/fl_chart)
- [table_calendar Documentation](https://pub.dev/packages/table_calendar)
- [Flutter CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html)
- Figma 디자인 노드: 714:6083, 680:3456, 714:4940, 698:4257
