import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/durations.dart';

class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;
  final Widget? child;

  /// 진입 시 링을 0 → [value]로 채우는 애니메이션 시간.
  /// reduced-motion 설정 시 자동으로 0이 되어 즉시 최종 상태로 그린다.
  final Duration duration;

  /// 링 채움과 동기화된 중앙 위젯 빌더. 진행 중인 값(0.0~1.0)을 받아
  /// 점수 카운트업 등에 사용한다. 지정 시 [child] 대신 이 빌더가 쓰인다.
  final Widget Function(BuildContext context, double animatedValue)?
      centerBuilder;

  const ProgressRing({
    super.key,
    required this.value,
    required this.size,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
    this.child,
    this.centerBuilder,
    this.duration = AppDurations.dataReveal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppDurations.of(context, duration),
        curve: AppCurves.enter,
        builder: (context, animatedValue, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _ProgressRingPainter(
                  value: animatedValue,
                  strokeWidth: strokeWidth,
                  activeColor: activeColor,
                  trackColor: trackColor,
                ),
              ),
              if (centerBuilder != null)
                centerBuilder!(context, animatedValue)
              else if (child != null)
                child!,
            ],
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Color activeColor;
  final Color trackColor;

  _ProgressRingPainter({
    required this.value,
    required this.strokeWidth,
    required this.activeColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * value.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);
    if (value > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false, activePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor;
  }
}
