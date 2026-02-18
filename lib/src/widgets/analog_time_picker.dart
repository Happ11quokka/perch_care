import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AnalogTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeSelected;

  const AnalogTimePicker({
    super.key,
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<AnalogTimePicker> createState() => _AnalogTimePickerState();
}

class _AnalogTimePickerState extends State<AnalogTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;
  late bool _isAM;
  bool _isSelectingHour = true; // true=시 선택, false=분 선택

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hourOfPeriod;
    if (_selectedHour == 0) _selectedHour = 12;
    _selectedMinute = widget.initialTime.minute;
    _isAM = widget.initialTime.period == DayPeriod.am;
  }

  void _onClockTap(Offset position, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    // 각도 계산 (12시 방향이 0도)
    var angle = math.atan2(dx, -dy);
    if (angle < 0) angle += 2 * math.pi;

    if (_isSelectingHour) {
      // 시간 계산 (1-12)
      final hour = ((angle / (2 * math.pi)) * 12).round();
      setState(() {
        _selectedHour = hour == 0 ? 12 : hour;
      });
    } else {
      // 분 계산 (0-59), 1분 단위
      final rawMinute = ((angle / (2 * math.pi)) * 60).round() % 60;
      setState(() {
        _selectedMinute = rawMinute;
      });
    }
  }

  void _onClockTapUp() {
    // 시 선택 후 자동으로 분 모드로 전환
    if (_isSelectingHour) {
      setState(() {
        _isSelectingHour = false;
      });
    }
  }

  TimeOfDay get _currentTime {
    int hour = _selectedHour;
    if (_isAM) {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }
    return TimeOfDay(hour: hour, minute: _selectedMinute);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          // 제목
          const Text(
            '시간을 선택해주세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 24),
          // 시간 표시 (탭으로 시/분 모드 전환)
          _buildTimeDisplay(),
          const SizedBox(height: 16),
          // AM/PM 토글
          _buildAmPmToggle(),
          const SizedBox(height: 32),
          // 아날로그 시계
          _buildAnalogClock(),
          const SizedBox(height: 32),
          // 선택 완료 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GestureDetector(
              onTap: () {
                widget.onTimeSelected(_currentTime);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '선택 완료',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 시 부분 (탭 가능)
        GestureDetector(
          onTap: () => setState(() => _isSelectingHour = true),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _isSelectingHour
                  ? AppColors.brandPrimary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedHour.toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 48,
                fontWeight: FontWeight.w600,
                color: _isSelectingHour
                    ? AppColors.brandPrimary
                    : AppColors.nearBlack,
                letterSpacing: -1.2,
              ),
            ),
          ),
        ),
        const Text(
          ':',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 48,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -1.2,
          ),
        ),
        // 분 부분 (탭 가능)
        GestureDetector(
          onTap: () => setState(() => _isSelectingHour = false),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: !_isSelectingHour
                  ? AppColors.brandPrimary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedMinute.toString().padLeft(2, '0'),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 48,
                fontWeight: FontWeight.w600,
                color: !_isSelectingHour
                    ? AppColors.brandPrimary
                    : AppColors.nearBlack,
                letterSpacing: -1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAmPmToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isAM = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _isAM ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '오전',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isAM ? Colors.white : AppColors.mediumGray,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isAM = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: !_isAM ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                '오후',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: !_isAM ? Colors.white : AppColors.mediumGray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalogClock() {
    return GestureDetector(
      onPanUpdate: (details) {
        _onClockTap(details.localPosition, const Size(240, 240));
      },
      onPanEnd: (_) => _onClockTapUp(),
      onTapDown: (details) {
        _onClockTap(details.localPosition, const Size(240, 240));
      },
      onTapUp: (_) => _onClockTapUp(),
      child: SizedBox(
        width: 240,
        height: 240,
        child: CustomPaint(
          painter: _isSelectingHour
              ? _HourClockPainter(
                  hour: _selectedHour,
                  minute: _selectedMinute,
                )
              : _MinuteClockPainter(
                  minute: _selectedMinute,
                ),
        ),
      ),
    );
  }
}

// ── 시 선택 페인터 ──────────────────────────────────────────────────────────

class _HourClockPainter extends CustomPainter {
  final int hour;
  final int minute;

  _HourClockPainter({
    required this.hour,
    required this.minute,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // 시계 외곽선
    final outerPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, outerPaint);

    // 시간 눈금 (1-12)
    for (int i = 1; i <= 12; i++) {
      final angle = (i * 30 - 90) * math.pi / 180;
      final isSelected = i == hour;
      final textRadius = radius - 25;

      final textOffset = Offset(
        center.dx + textRadius * math.cos(angle),
        center.dy + textRadius * math.sin(angle),
      );

      // 선택된 시간에 원 표시
      if (isSelected) {
        final selectedPaint = Paint()..color = AppColors.brandPrimary;
        canvas.drawCircle(textOffset, 18, selectedPaint);
      }

      final textPainter = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.mediumGray,
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
    final hourAngle = ((hour % 12) * 30 + minute * 0.5 - 90) * math.pi / 180;
    final hourHandLength = radius - 50;
    final hourHandEnd = Offset(
      center.dx + hourHandLength * math.cos(hourAngle),
      center.dy + hourHandLength * math.sin(hourAngle),
    );

    final hourPaint = Paint()
      ..color = AppColors.nearBlack
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, hourHandEnd, hourPaint);

    // 중심점
    canvas.drawCircle(center, 5, Paint()..color = AppColors.nearBlack);
  }

  @override
  bool shouldRepaint(covariant _HourClockPainter oldDelegate) {
    return oldDelegate.hour != hour || oldDelegate.minute != minute;
  }
}

// ── 분 선택 페인터 ──────────────────────────────────────────────────────────

class _MinuteClockPainter extends CustomPainter {
  final int minute;

  _MinuteClockPainter({required this.minute});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // 시계 외곽선
    final outerPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, outerPaint);

    // 1분 단위 작은 눈금 (60개)
    for (int i = 0; i < 60; i++) {
      if (i % 5 == 0) continue; // 5분 눈금은 아래에서 별도 처리
      final angle = (i * 6 - 90) * math.pi / 180;
      final tickStart = Offset(
        center.dx + (radius - 4) * math.cos(angle),
        center.dy + (radius - 4) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + (radius - 10) * math.cos(angle),
        center.dy + (radius - 10) * math.sin(angle),
      );
      final tickPaint = Paint()
        ..color = const Color(0xFFE0E0E0)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(tickStart, tickEnd, tickPaint);
    }

    // 분 눈금 (0, 5, 10, ..., 55) - 12개
    for (int i = 0; i < 12; i++) {
      final minuteValue = i * 5;
      final angle = (i * 30 - 90) * math.pi / 180;
      final isSelected = minuteValue == minute;
      final textRadius = radius - 25;

      final textOffset = Offset(
        center.dx + textRadius * math.cos(angle),
        center.dy + textRadius * math.sin(angle),
      );

      // 선택된 5분 눈금에 원 표시
      if (isSelected) {
        final selectedPaint = Paint()..color = AppColors.brandPrimary;
        canvas.drawCircle(textOffset, 18, selectedPaint);
      }

      final label = minuteValue.toString().padLeft(2, '0');
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.mediumGray,
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

    // 분침
    final minuteAngle = (minute * 6 - 90) * math.pi / 180;
    final minuteHandLength = radius - 40;
    final minuteHandEnd = Offset(
      center.dx + minuteHandLength * math.cos(minuteAngle),
      center.dy + minuteHandLength * math.sin(minuteAngle),
    );

    final minutePaint = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, minuteHandEnd, minutePaint);

    // 5분 단위가 아닌 경우 분침 끝에 포인터 표시
    if (minute % 5 != 0) {
      final pointerRadius = radius - 25;
      final pointerOffset = Offset(
        center.dx + pointerRadius * math.cos(minuteAngle),
        center.dy + pointerRadius * math.sin(minuteAngle),
      );
      canvas.drawCircle(pointerOffset, 14, Paint()..color = AppColors.brandPrimary);
      final tp = TextPainter(
        text: TextSpan(
          text: minute.toString(),
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, pointerOffset - Offset(tp.width / 2, tp.height / 2));
    }

    // 중심점
    canvas.drawCircle(center, 5, Paint()..color = AppColors.brandPrimary);
  }

  @override
  bool shouldRepaint(covariant _MinuteClockPainter oldDelegate) {
    return oldDelegate.minute != minute;
  }
}

// 시간 선택 바텀시트 표시 함수
Future<TimeOfDay?> showAnalogTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  TimeOfDay? result;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return AnalogTimePicker(
        initialTime: initialTime,
        onTimeSelected: (time) {
          result = time;
        },
      );
    },
  );
  return result;
}
