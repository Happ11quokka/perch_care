import 'package:flutter/material.dart';
import '../services/premium/premium_service.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/radius.dart';

/// AI 백과사전 남은 쿼터를 표시하는 배지 위젯.
///
/// 상태:
/// - Normal (remaining > 1): 초록 배경, "오늘 N회 남음"
/// - Warning (remaining == 1): 주황 배경, "오늘 1회 남음"
/// - Exhausted (remaining == 0): 빨간 배경, "일일 한도 도달" + 업그레이드 CTA
/// - Premium (unlimited): 렌더링하지 않음
class QuotaBadge extends StatelessWidget {
  final EncyclopediaQuota quota;
  final String normalText;
  final String exhaustedText;
  final String upgradeText;
  final VoidCallback? onUpgradePressed;

  const QuotaBadge({
    super.key,
    required this.quota,
    required this.normalText,
    required this.exhaustedText,
    required this.upgradeText,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    if (quota.isUnlimited) return const SizedBox.shrink();

    final Color bgColor;
    final Color textColor;
    final IconData icon;
    final String text;

    if (quota.isExhausted) {
      bgColor = AppColors.dangerLight;
      textColor = AppColors.dangerDark;
      icon = Icons.block;
      text = exhaustedText;
    } else if (quota.isWarning) {
      bgColor = AppColors.brandLighter;
      textColor = AppColors.warningDark;
      icon = Icons.warning_amber;
      text = normalText;
    } else {
      bgColor = AppColors.successLight;
      textColor = AppColors.successMedium;
      icon = Icons.check_circle_outline;
      text = normalText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.chip,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (quota.isExhausted && onUpgradePressed != null) ...[
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onUpgradePressed,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text(
                  upgradeText,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
