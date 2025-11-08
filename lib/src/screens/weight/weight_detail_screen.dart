import 'package:flutter/material.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../models/weight_record.dart';
import 'dart:math' as math;

class WeightDetailScreen extends StatefulWidget {
  const WeightDetailScreen({super.key});

  @override
  State<WeightDetailScreen> createState() => _WeightDetailScreenState();
}

class _WeightDetailScreenState extends State<WeightDetailScreen> {
  String selectedPeriod = '월'; // 주, 월, 년
  final List<WeightRecord> weightRecords = WeightData.getSeptemberData();
  final Map<int, double> monthlyAverages = WeightData.getMonthlyAverages();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section - Fixed
            _buildTopSection(size),

            // Bottom Sheet - Scrollable Calendar
            Expanded(
              child: _buildBottomSheet(size, padding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(Size size) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header with back button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  '체중',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 48), // Balance for back button
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            ' 꾸준히 기록을 남기며',
            textAlign: TextAlign.center,
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),
          Text(
            '사랑이 체중 변화를 한 눈에!',
            textAlign: TextAlign.center,
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Subtitle
          Text(
            '지금 바로 기록하고 우리 아이 건강 상태를',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
          Text(
            '편하게 관리해 보세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mediumGray,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Period Selector
          _buildPeriodSelector(),

          const SizedBox(height: AppSpacing.xl),

          // Chart
          _buildChart(size),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

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

  Widget _buildChart(Size size) {
    final chartWidth = size.width - (AppSpacing.md * 2);
    final chartHeight = 200.0;

    return SizedBox(
      width: chartWidth,
      height: chartHeight,
      child: CustomPaint(
        painter: WeightChartPainter(
          monthlyAverages: monthlyAverages,
          highlightedMonth: 9,
        ),
      ),
    );
  }

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
                      onPressed: () {},
                      iconSize: 20,
                    ),
                    Text(
                      '9월',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {},
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

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

                  // Add Record Button
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

  Widget _buildCalendarGrid() {
    // September 2025 starts on Monday (1)
    final firstDayOfMonth = DateTime(2025, 9, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = 30;

    final List<Widget> dayWidgets = [];

    // Add empty cells for days before the 1st
    for (int i = 0; i < startWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(2025, 9, day);
      final hasRecord = weightRecords.any((record) =>
          record.date.day == day &&
          record.date.month == 9 &&
          record.date.year == 2025);

      dayWidgets.add(_buildDayCell(day, hasRecord));
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

  Widget _buildDayCell(int day, bool hasRecord) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          day.toString(),
          style: AppTypography.bodyMedium.copyWith(
            color: day > 28
                ? AppColors.lightGray
                : AppColors.mediumGray,
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

  Widget _buildAddRecordButton(Size size) {
    return Container(
      width: size.width - (AppSpacing.md * 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientTop, AppColors.brandPrimary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '오늘의 몸무게 기록하기',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for the weight chart
class WeightChartPainter extends CustomPainter {
  final Map<int, double> monthlyAverages;
  final int highlightedMonth;

  WeightChartPainter({
    required this.monthlyAverages,
    required this.highlightedMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.lightGray
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = AppColors.brandPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.fill;

    // Chart dimensions
    final chartWidth = size.width - 80;
    final chartHeight = size.height - 60;
    final leftPadding = 40.0;
    final topPadding = 30.0;

    // Draw month labels and bars
    final months = [6, 7, 8, 9, 10, 11];
    final monthLabels = ['6월', '7월', '8월', '9월', '10월', '11월'];
    final barWidth = chartWidth / months.length;

    // Find max value for scaling
    final maxValue = monthlyAverages.values
        .where((v) => v > 0)
        .reduce((a, b) => a > b ? a : b);

    // Collect points for smooth curve
    final List<Offset> points = [];
    for (int i = 0; i < months.length; i++) {
      final month = months[i];
      final value = monthlyAverages[month] ?? 0;
      if (value > 0) {
        final x = leftPadding + (i * barWidth) + (barWidth / 2);
        final y = topPadding + chartHeight - (value / maxValue * chartHeight);
        points.add(Offset(x, y));
      }
    }

    // Draw smooth curve path
    final smoothPath = _createSmoothPath(points);

    // Draw month labels
    for (int i = 0; i < months.length; i++) {
      final month = months[i];
      final textPainter = TextPainter(
        text: TextSpan(
          text: monthLabels[i],
          style: TextStyle(
            fontSize: 13,
            color: month == highlightedMonth ? Colors.white : AppColors.mediumGray,
            fontFamily: 'Pretendard',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      final labelX = leftPadding + (i * barWidth) + (barWidth / 2) - (textPainter.width / 2);
      final labelY = topPadding + chartHeight + 10;
      textPainter.paint(canvas, Offset(labelX, labelY));
    }

    // Draw smooth dashed curve
    _drawDashedPath(canvas, smoothPath, paint);

    // Draw bars and points
    for (int i = 0; i < months.length; i++) {
      final month = months[i];
      final value = monthlyAverages[month] ?? 0;

      if (value > 0 && month == highlightedMonth) {
        final x = leftPadding + (i * barWidth) + (barWidth / 2);
        final y = topPadding + chartHeight - (value / maxValue * chartHeight);
        final barHeight = chartHeight - (chartHeight - (value / maxValue * chartHeight));

        // Draw vertical bar
        final barRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 26, y, 53, barHeight),
          const Radius.circular(20),
        );
        canvas.drawRRect(barRect, fillPaint);

        // Draw weight label on bar
        final weightTextPainter = TextPainter(
          text: TextSpan(
            text: '${value.toStringAsFixed(1)} g',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Pretendard',
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        weightTextPainter.layout();
        weightTextPainter.paint(
          canvas,
          Offset(x - weightTextPainter.width / 2, y + 10),
        );

        // Draw outer circle
        canvas.drawCircle(Offset(x, y), 16, fillPaint);

        // Draw inner white circle
        canvas.drawCircle(
          Offset(x, y),
          12,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  // Create smooth bezier curve path through points
  Path _createSmoothPath(List<Offset> points) {
    final path = Path();

    if (points.isEmpty) return path;
    if (points.length == 1) {
      path.moveTo(points[0].dx, points[0].dy);
      return path;
    }

    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < points.length - 2 ? points[i + 2] : p2;

      // Calculate control points for smooth curve
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6;

      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }

    return path;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    final metrics = path.computeMetrics();

    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;

      while (distance < metric.length) {
        final double length = draw ? dashWidth : dashSpace;
        final double end = math.min(distance + length, metric.length);
        if (draw) {
          final extractPath = metric.extractPath(distance, end);
          canvas.drawPath(extractPath, paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(WeightChartPainter oldDelegate) => false;
}
