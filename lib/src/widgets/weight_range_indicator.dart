import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// A widget that displays a horizontal bar showing where a bird's current weight
/// falls within its breed's healthy weight range.
///
/// Visual structure:
/// [min]----[ideal_min]========ideal========[ideal_max]----[max]
///                          ▼ (marker)
///
/// Usage example:
/// ```dart
/// WeightRangeIndicator(
///   currentWeight: 450.0,
///   minG: 350.0,
///   idealMinG: 400.0,
///   idealMaxG: 500.0,
///   maxG: 550.0,
/// )
/// ```
class WeightRangeIndicator extends StatelessWidget {
  /// Current weight of the bird in grams
  final double currentWeight;

  /// Minimum acceptable weight in grams
  final double minG;

  /// Lower bound of ideal weight range in grams
  final double idealMinG;

  /// Upper bound of ideal weight range in grams
  final double idealMaxG;

  /// Maximum acceptable weight in grams
  final double maxG;

  const WeightRangeIndicator({
    super.key,
    required this.currentWeight,
    required this.minG,
    required this.idealMinG,
    required this.idealMaxG,
    required this.maxG,
  }) : assert(minG <= idealMinG && idealMinG <= idealMaxG && idealMaxG <= maxG,
             'Weight ranges must be in ascending order: min ≤ idealMin ≤ idealMax ≤ max');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Weight range bar with marker
        SizedBox(
          height: 24,
          child: CustomPaint(
            painter: _WeightRangePainter(
              currentWeight: currentWeight,
              minG: minG,
              idealMinG: idealMinG,
              idealMaxG: idealMaxG,
              maxG: maxG,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildLabel('${minG.toInt()}g', Alignment.centerLeft),
            _buildLabel(
              '${idealMinG.toInt()}g - ${idealMaxG.toInt()}g',
              Alignment.center,
            ),
            _buildLabel('${maxG.toInt()}g', Alignment.centerRight),
          ],
        ),
      ],
    );
  }

  Widget _buildLabel(String text, Alignment alignment) {
    return Expanded(
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF757575),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _WeightRangePainter extends CustomPainter {
  final double currentWeight;
  final double minG;
  final double idealMinG;
  final double idealMaxG;
  final double maxG;

  // Color constants
  static const Color _lightOrange = Color(0xFFFFE0B2);
  static const Color _idealGreen = Color(0xFF4CAF50);
  static const Color _warningRed = Color(0xFFEF5350);

  const _WeightRangePainter({
    required this.currentWeight,
    required this.minG,
    required this.idealMinG,
    required this.idealMaxG,
    required this.maxG,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double barHeight = 12.0;
    const double barY = 12.0; // Leave space for marker above
    const double cornerRadius = 6.0;

    final double totalRange = maxG - minG;
    if (totalRange <= 0) return;
    final double barWidth = size.width;

    // Calculate section widths as percentages
    final double lowRangePercent = (idealMinG - minG) / totalRange;
    final double idealRangePercent = (idealMaxG - idealMinG) / totalRange;
    final double highRangePercent = (maxG - idealMaxG) / totalRange;

    final double lowRangeWidth = barWidth * lowRangePercent;
    final double idealRangeWidth = barWidth * idealRangePercent;
    final double highRangeWidth = barWidth * highRangePercent;

    // Draw the three sections
    final Paint paint = Paint()..style = PaintingStyle.fill;

    // Left section (min → ideal_min) - Light orange
    if (lowRangeWidth > 0) {
      paint.color = _lightOrange;
      final RRect leftRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(0, barY, lowRangeWidth, barHeight),
        topLeft: const Radius.circular(cornerRadius),
        bottomLeft: const Radius.circular(cornerRadius),
      );
      canvas.drawRRect(leftRect, paint);
    }

    // Center section (ideal_min → ideal_max) - Green
    paint.color = _idealGreen;
    final double idealStart = lowRangeWidth;
    final RRect centerRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(idealStart, barY, idealRangeWidth, barHeight),
      // Apply corner radius only if it's at the edges
      topLeft: Radius.circular(lowRangeWidth == 0 ? cornerRadius : 0),
      bottomLeft: Radius.circular(lowRangeWidth == 0 ? cornerRadius : 0),
      topRight: Radius.circular(highRangeWidth == 0 ? cornerRadius : 0),
      bottomRight: Radius.circular(highRangeWidth == 0 ? cornerRadius : 0),
    );
    canvas.drawRRect(centerRect, paint);

    // Right section (ideal_max → max) - Light orange
    if (highRangeWidth > 0) {
      paint.color = _lightOrange;
      final double highStart = idealStart + idealRangeWidth;
      final RRect rightRect = RRect.fromRectAndCorners(
        Rect.fromLTWH(highStart, barY, highRangeWidth, barHeight),
        topRight: const Radius.circular(cornerRadius),
        bottomRight: const Radius.circular(cornerRadius),
      );
      canvas.drawRRect(rightRect, paint);
    }

    // Draw marker
    _drawMarker(canvas, size, barY, barHeight);
  }

  void _drawMarker(Canvas canvas, Size size, double barY, double barHeight) {
    // Calculate marker position
    double markerX;
    Color markerColor;

    if (currentWeight < minG) {
      // Clamp to left edge
      markerX = 0;
      markerColor = _warningRed;
    } else if (currentWeight > maxG) {
      // Clamp to right edge
      markerX = size.width;
      markerColor = _warningRed;
    } else {
      // Position proportionally within range
      final double position = (currentWeight - minG) / (maxG - minG);
      markerX = size.width * position;
      markerColor = AppColors.brandPrimary;
    }

    // Draw downward-pointing triangle marker
    const double markerSize = 8.0;
    final Path trianglePath = Path()
      ..moveTo(markerX, barY - 2) // Top point (above bar)
      ..lineTo(markerX - markerSize / 2, barY - 2 - markerSize) // Top left
      ..lineTo(markerX + markerSize / 2, barY - 2 - markerSize) // Top right
      ..close();

    final Paint markerPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(trianglePath, markerPaint);

    // Draw vertical line from marker to bar
    final Paint linePaint = Paint()
      ..color = markerColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(markerX, barY - 2),
      Offset(markerX, barY + barHeight),
      linePaint,
    );

    // Draw circle at bottom of line
    final Paint circlePaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(markerX, barY + barHeight / 2),
      3.0,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(_WeightRangePainter oldDelegate) {
    return oldDelegate.currentWeight != currentWeight ||
        oldDelegate.minG != minG ||
        oldDelegate.idealMinG != idealMinG ||
        oldDelegate.idealMaxG != idealMaxG ||
        oldDelegate.maxG != maxG;
  }
}
