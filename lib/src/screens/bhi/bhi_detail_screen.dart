import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../models/bhi_result.dart';
import '../../router/route_names.dart';
import '../../widgets/progress_ring.dart';
import '../../widgets/empty_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';

/// BHI (Bird Health Index) 건강 점수 상세 화면
class BhiDetailScreen extends ConsumerStatefulWidget {
  final BhiResult? bhiResult;

  const BhiDetailScreen({super.key, this.bhiResult});

  @override
  ConsumerState<BhiDetailScreen> createState() => _BhiDetailScreenState();
}

class _BhiDetailScreenState extends ConsumerState<BhiDetailScreen> {
  final GlobalKey _scoreRingKey = GlobalKey();
  final GlobalKey _breakdownCardsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowCoachMarks();
    });
  }

  Future<void> _maybeShowCoachMarks() async {
    if (widget.bhiResult == null) return; // 데이터 없으면 타겟 위젯 없음
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenBhiDetail)) return;
    await Future.delayed(AppDurations.coachMarkDelay);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    CoachMarkOverlay.show(
      context,
      steps: [
        CoachMarkStep(
          targetKey: _scoreRingKey,
          title: l10n.coach_bhiRing_title,
          body: l10n.coach_bhiRing_body,
        ),
        CoachMarkStep(
          targetKey: _breakdownCardsKey,
          title: l10n.coach_bhiBreakdown_title,
          body: l10n.coach_bhiBreakdown_body,
        ),
      ],
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () => service.markSeen(CoachMarkService.screenBhiDetail),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
        centerTitle: true,
        title: Text(
          l10n.bhi_title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.45,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: widget.bhiResult == null ? _buildEmptyState() : _buildContent(l10n),
      ),
    );
  }

  /// 데이터 없음 상태
  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context);
    return EmptyStateWidget(
      icon: Icons.health_and_safety_outlined,
      title: l10n.bhi_noDataTitle,
      subtitle: l10n.bhi_noDataSubtitle,
    );
  }

  /// 메인 컨텐츠
  Widget _buildContent(AppLocalizations l10n) {
    final bhi = widget.bhiResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BHI 총점 영역
          _buildScoreHero(bhi, l10n),

          const SizedBox(height: 28),

          // 점수 구성 섹션
          Text(
            l10n.bhi_scoreComposition,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          Column(
            key: _breakdownCardsKey,
            children: [
              _buildScoreBreakdownCard(
                iconPath: 'assets/images/home_vector/weight.svg',
                title: l10n.home_weight,
                score: bhi.weightScore,
                maxScore: 60,
                hasData: bhi.hasWeightData,
                noDataText: l10n.bhi_noData,
              ),
              const SizedBox(height: 8),
              _buildScoreBreakdownCard(
                iconPath: 'assets/images/home_vector/eat.svg',
                title: l10n.home_food,
                score: bhi.foodScore,
                maxScore: 25,
                hasData: bhi.hasFoodData,
                noDataText: l10n.bhi_noData,
              ),
              const SizedBox(height: 8),
              _buildScoreBreakdownCard(
                iconPath: 'assets/images/home_vector/water.svg',
                title: l10n.home_water,
                score: bhi.waterScore,
                maxScore: 15,
                hasData: bhi.hasWaterData,
                noDataText: l10n.bhi_noData,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // WCI 레벨 & 성장 단계
          _buildInfoSection(bhi, l10n),

          const SizedBox(height: 20),

          // 안내 메시지
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.brandLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.brandPrimary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.brandPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.bhi_accuracyHint,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.mediumGray,
                      letterSpacing: -0.3,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 기준 날짜
          Center(
            child: Text(
              l10n.bhi_baseDate('${bhi.targetDate.year}.${bhi.targetDate.month.toString().padLeft(2, '0')}.${bhi.targetDate.day.toString().padLeft(2, '0')}'),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.warmGray,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// BHI 총점 영역 (원형 게이지)
  Widget _buildScoreHero(BhiResult bhi, AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.gray50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            l10n.bhi_healthScore,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.mediumGray,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            key: _scoreRingKey,
            child: ProgressRing(
              value: bhi.bhiScore / 100.0,
              size: 180,
              strokeWidth: 14,
              activeColor: _getScoreColor(bhi.bhiScore),
              trackColor: AppColors.gray100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bhi.bhiScore.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: AppColors.nearBlack,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.bhi_scoreMax,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.warmGray,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getScoreLabel(bhi.bhiScore, l10n),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _getScoreColor(bhi.bhiScore),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getScoreDescription(bhi.bhiScore, l10n),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.warmGray,
              letterSpacing: -0.3,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 점수 구성 카드
  Widget _buildScoreBreakdownCard({
    required String iconPath,
    required String title,
    required double score,
    required double maxScore,
    required bool hasData,
    required String noDataText,
  }) {
    final ratio = hasData ? (score / maxScore).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gray100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                iconPath,
                width: 32,
                height: 32,
                colorFilter: hasData
                    ? const ColorFilter.mode(
                        AppColors.brandPrimary,
                        BlendMode.srcIn,
                      )
                    : const ColorFilter.mode(
                        AppColors.lightGray,
                        BlendMode.srcIn,
                      ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
              const Spacer(),
              hasData
                  ? Text(
                      '${score.toStringAsFixed(1)} / ${maxScore.toInt()}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.35,
                      ),
                    )
                  : Text(
                      noDataText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.warmGray,
                        letterSpacing: -0.3,
                      ),
                    ),
            ],
          ),
          const SizedBox(height: 12),
          // 프로그레스 바
          SizedBox(
            height: 8,
            child: Stack(
              children: [
                // 트랙
                Container(
                  width: double.infinity,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                // 채움
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: hasData
                          ? const LinearGradient(
                              colors: [
                                AppColors.brandPrimary,
                                AppColors.brandDark,
                              ],
                            )
                          : null,
                      color: hasData ? null : AppColors.gray100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// WCI 레벨 & 성장 단계 섹션
  Widget _buildInfoSection(BhiResult bhi, AppLocalizations l10n) {
    final growthStageLabel = _mapGrowthStage(bhi.growthStage, l10n);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gray100,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WCI 레벨 헤더
          Row(
            children: [
              Text(
                l10n.bhi_wciLevel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
              const Spacer(),
              if (bhi.wciLevel > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Level ${bhi.wciLevel}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                )
              else
                const Text(
                  '-',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.warmGray,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 5단계 프로그레스 바
          _buildWciProgressBars(bhi.wciLevel),
          const SizedBox(height: 8),
          Center(
            child: Text(
              bhi.wciLevel > 0 ? l10n.bhi_stageNumber(bhi.wciLevel) : '-',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.nearBlack,
                height: 20 / 14,
              ),
            ),
          ),

          // 성장 단계
          if (growthStageLabel != null) ...[
            const SizedBox(height: 16),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColors.gray100,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  l10n.bhi_growthStage,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mediumGray,
                    letterSpacing: -0.35,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    growthStageLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.nearBlack,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 5단계 WCI 프로그레스 바 (홈 화면과 동일한 동적 위치 방식)
  Widget _buildWciProgressBars(int wciLevel) {
    final int circlePos = wciLevel == 0 ? 3 : wciLevel;

    final List<Widget> children = [];
    for (int i = 1; i <= 5; i++) {
      if (i > 1) children.add(const SizedBox(width: 2));

      if (i == circlePos) {
        // 동그라미
        children.add(Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: wciLevel > 0
                  ? AppColors.brandPrimary
                  : AppColors.gray100,
              width: 2,
            ),
            color: Colors.white,
          ),
        ));
      } else {
        // 바: 동그라미 왼쪽이면 채움, 오른쪽이면 비움
        final bool filled = wciLevel > 0 && i < circlePos;
        children.add(_buildSegment(filled));
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  Widget _buildSegment(bool isActive) {
    return Container(
      width: 56,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.brandPrimary : AppColors.gray100,
        borderRadius: BorderRadius.circular(1),
        border: Border.all(
          color: AppColors.gray100,
          width: 1,
        ),
      ),
    );
  }

  // --- 헬퍼 메서드 ---

  Color _getScoreColor(double score) {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.brandPrimary;
    if (score >= 40) return AppColors.warning;
    return AppColors.gradientBottom;
  }

  String _getScoreLabel(double score, AppLocalizations l10n) {
    if (score >= 80) return l10n.bhi_statusHealthy;
    if (score >= 60) return l10n.bhi_statusStable;
    if (score >= 40) return l10n.bhi_statusCaution;
    if (score > 0) return l10n.bhi_statusManagement;
    return l10n.bhi_statusInsufficient;
  }

  String _getScoreDescription(double score, AppLocalizations l10n) {
    if (score >= 80) return l10n.bhi_descHealthy;
    if (score >= 60) return l10n.bhi_descStable;
    if (score >= 40) return l10n.bhi_descCaution;
    if (score > 0) return l10n.bhi_descManagement;
    return l10n.bhi_descInsufficient;
  }

  String? _mapGrowthStage(String? stage, AppLocalizations l10n) {
    switch (stage) {
      case 'adult':
        return l10n.bhi_growthAdult;
      case 'post_growth':
        return l10n.bhi_growthPostGrowth;
      case 'rapid_growth':
        return l10n.bhi_growthRapidGrowth;
      default:
        return null;
    }
  }
}
