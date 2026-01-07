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

    // 시간 계산 (1-12)
    final hour = ((angle / (2 * math.pi)) * 12).round();
    setState(() {
      _selectedHour = hour == 0 ? 12 : hour;
    });
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
          // 시간 표시
          Text(
            '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -1.2,
            ),
          ),
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
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final localPosition = details.localPosition;
          _onClockTap(localPosition, const Size(240, 240));
        }
      },
      onTapDown: (details) {
        _onClockTap(details.localPosition, const Size(240, 240));
      },
      child: SizedBox(
        width: 240,
        height: 240,
        child: CustomPaint(
          painter: _AnalogClockPainter(
            hour: _selectedHour,
            minute: _selectedMinute,
          ),
        ),
      ),
    );
  }
}

class _AnalogClockPainter extends CustomPainter {
  final int hour;
  final int minute;

  _AnalogClockPainter({
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
  bool shouldRepaint(covariant _AnalogClockPainter oldDelegate) {
    return oldDelegate.hour != hour || oldDelegate.minute != minute;
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
