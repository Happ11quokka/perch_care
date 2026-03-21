import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/health_summary.dart';
import '../theme/colors.dart';
import '../../l10n/app_localizations.dart';

/// 건강 변화 요약 카드.
/// Free: 기본 정보 + 프리미엄 영역 블러 + 업그레이드 CTA.
/// Premium: 전체 상세 정보 표시.
class HealthSummaryCard extends StatelessWidget {
  final HealthSummary summary;
  final bool isPremium;
  final VoidCallback? onUpgradePressed;

  const HealthSummaryCard({
    super.key,
    required this.summary,
    required this.isPremium,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!summary.hasData) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.home_healthSummaryTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.4,
                ),
              ),
              if (summary.bhiScore != null)
                _buildBhiChip(summary.bhiScore!, summary.wciLevel),
            ],
          ),
          const SizedBox(height: 14),

          // 체중 변화
          _buildMetricRow(
            icon: Icons.monitor_weight_outlined,
            label: l10n.home_healthSummaryWeightChange,
            value: _formatWeightChange(),
            trend: summary.weightTrend,
          ),
          const SizedBox(height: 10),

          // BHI 점수
          if (summary.bhiScore != null)
            _buildMetricRow(
              icon: Icons.favorite_outline,
              label: 'BHI',
              value: summary.bhiScore!.toStringAsFixed(1),
              trend: null,
            ),

          // Premium 전용 영역
          if (isPremium) ...[
            const Divider(height: 24, color: AppColors.gray150),
            _buildPremiumDetails(l10n),
          ] else ...[
            const SizedBox(height: 12),
            _buildLockedOverlay(l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildBhiChip(double score, int level) {
    final color = _wciColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'WCI $level',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    String? trend,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.warmGray),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mediumGray,
          ),
        ),
        const Spacer(),
        if (trend != null) ...[
          Icon(
            trend == 'up'
                ? Icons.trending_up
                : trend == 'down'
                    ? Icons.trending_down
                    : Icons.trending_flat,
            size: 16,
            color: trend == 'up'
                ? AppColors.dangerDark
                : trend == 'down'
                    ? AppColors.infoDark
                    : AppColors.warmGray,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDetails(AppLocalizations l10n) {
    return Column(
      children: [
        // 이상 소견
        if (summary.abnormalCount != null)
          _buildMetricRow(
            icon: Icons.warning_amber,
            label: l10n.home_healthSummaryAbnormal,
            value: '${summary.abnormalCount}',
            trend: null,
          ),
        if (summary.abnormalCount != null) const SizedBox(height: 10),

        // 급여 일관성
        if (summary.foodConsistency != null)
          _buildConsistencyBar(
            label: l10n.home_healthSummaryFoodConsistency,
            value: summary.foodConsistency!,
          ),
        if (summary.foodConsistency != null) const SizedBox(height: 8),

        // 음수 일관성
        if (summary.waterConsistency != null)
          _buildConsistencyBar(
            label: l10n.home_healthSummaryWaterConsistency,
            value: summary.waterConsistency!,
          ),

        // BHI 추세
        if (summary.bhiTrend != null) ...[
          const SizedBox(height: 10),
          _buildMetricRow(
            icon: Icons.show_chart,
            label: 'BHI ${_bhiTrendLabel(summary.bhiTrend!)}',
            value: summary.bhiPrevious != null
                ? '${summary.bhiPrevious!.toStringAsFixed(1)} → ${summary.bhiScore!.toStringAsFixed(1)}'
                : '',
            trend: summary.bhiTrend == 'improving'
                ? 'up'
                : summary.bhiTrend == 'declining'
                    ? 'down'
                    : null,
          ),
        ],
      ],
    );
  }

  Widget _buildConsistencyBar({required String label, required double value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.mediumGray,
              ),
            ),
            Text(
              '${value.toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.nearBlack,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            backgroundColor: AppColors.gray150,
            valueColor: AlwaysStoppedAnimation<Color>(
              value >= 70
                  ? AppColors.success
                  : value >= 40
                      ? AppColors.brandPrimary
                      : AppColors.dangerDark,
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildLockedOverlay(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // 블러된 프리뷰
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Opacity(
              opacity: 0.5,
              child: Column(
                children: [
                  _buildConsistencyBar(
                    label: l10n.home_healthSummaryFoodConsistency,
                    value: 75,
                  ),
                  const SizedBox(height: 8),
                  _buildConsistencyBar(
                    label: l10n.home_healthSummaryWaterConsistency,
                    value: 60,
                  ),
                ],
              ),
            ),
          ),
          // 잠금 오버레이
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: onUpgradePressed,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 14, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        l10n.home_healthSummaryUpgrade,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatWeightChange() {
    if (summary.weightCurrent == null) return '-';
    final current = summary.weightCurrent!.toStringAsFixed(1);
    if (summary.weightChangePercent == null) return '${current}g';
    final sign = summary.weightChangePercent! >= 0 ? '+' : '';
    return '${current}g ($sign${summary.weightChangePercent!.toStringAsFixed(1)}%)';
  }

  String _bhiTrendLabel(String trend) {
    switch (trend) {
      case 'improving':
        return '↑';
      case 'declining':
        return '↓';
      default:
        return '→';
    }
  }

  Color _wciColor(int level) {
    switch (level) {
      case 5:
        return AppColors.success;
      case 4:
        return AppColors.lime;
      case 3:
        return AppColors.brandPrimary;
      case 2:
        return AppColors.warningDark;
      case 1:
        return AppColors.dangerDark;
      default:
        return AppColors.warmGray;
    }
  }
}
