import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../models/bhi_result.dart';
import '../../router/route_names.dart';
import '../../widgets/progress_ring.dart';

/// BHI (Bird Health Index) 건강 점수 상세 화면
class BhiDetailScreen extends StatelessWidget {
  final BhiResult? bhiResult;

  const BhiDetailScreen({super.key, this.bhiResult});

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          '건강 점수',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.45,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: bhiResult == null ? _buildEmptyState() : _buildContent(),
      ),
    );
  }

  /// 데이터 없음 상태
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.health_and_safety_outlined,
            size: 64,
            color: const Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 16),
          const Text(
            '건강 데이터가 아직 없습니다',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B6B6B),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '체중, 사료, 수분 데이터를 입력해주세요',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF97928A),
              letterSpacing: -0.35,
            ),
          ),
        ],
      ),
    );
  }

  /// 메인 컨텐츠
  Widget _buildContent() {
    final bhi = bhiResult!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BHI 총점 영역
          _buildScoreHero(bhi),

          const SizedBox(height: 28),

          // 점수 구성 섹션
          const Text(
            '점수 구성',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),

          _buildScoreBreakdownCard(
            icon: Icons.monitor_weight_outlined,
            title: '체중',
            score: bhi.weightScore,
            maxScore: 60,
            hasData: bhi.hasWeightData,
          ),
          const SizedBox(height: 8),
          _buildScoreBreakdownCard(
            icon: Icons.restaurant_outlined,
            title: '사료',
            score: bhi.foodScore,
            maxScore: 25,
            hasData: bhi.hasFoodData,
          ),
          const SizedBox(height: 8),
          _buildScoreBreakdownCard(
            icon: Icons.water_drop_outlined,
            title: '수분',
            score: bhi.waterScore,
            maxScore: 15,
            hasData: bhi.hasWaterData,
          ),

          const SizedBox(height: 28),

          // WCI 레벨 & 성장 단계
          _buildInfoSection(bhi),

          const SizedBox(height: 20),

          // 기준 날짜
          Center(
            child: Text(
              '기준 날짜: ${bhi.targetDate.year}.${bhi.targetDate.month.toString().padLeft(2, '0')}.${bhi.targetDate.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF97928A),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// BHI 총점 영역 (원형 게이지)
  Widget _buildScoreHero(BhiResult bhi) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'BHI 건강 점수',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B6B6B),
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 24),
          ProgressRing(
            value: bhi.bhiScore / 100.0,
            size: 180,
            strokeWidth: 14,
            activeColor: _getScoreColor(bhi.bhiScore),
            trackColor: const Color(0xFFF0F0F0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  bhi.bhiScore.toStringAsFixed(0),
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: AppColors.nearBlack,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '/100',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF97928A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getScoreLabel(bhi.bhiScore),
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _getScoreColor(bhi.bhiScore),
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _getScoreDescription(bhi.bhiScore),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: Color(0xFF97928A),
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
    required IconData icon,
    required String title,
    required double score,
    required double maxScore,
    required bool hasData,
  }) {
    final ratio = hasData ? (score / maxScore).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasData
                      ? AppColors.brandPrimary.withValues(alpha: 0.1)
                      : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: hasData
                      ? AppColors.brandPrimary
                      : const Color(0xFFBDBDBD),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
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
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.35,
                      ),
                    )
                  : const Text(
                      '데이터 없음',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF97928A),
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
                    color: const Color(0xFFF0F0F0),
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
                                Color(0xFFFF7C2A),
                              ],
                            )
                          : null,
                      color: hasData ? null : const Color(0xFFF0F0F0),
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
  Widget _buildInfoSection(BhiResult bhi) {
    final growthStageLabel = _mapGrowthStage(bhi.growthStage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // WCI 레벨 헤더
          Row(
            children: [
              const Text(
                'WCI 레벨',
                style: TextStyle(
                  fontFamily: 'Pretendard',
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
                      fontFamily: 'Pretendard',
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
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF97928A),
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
              bhi.wciLevel > 0 ? '${bhi.wciLevel}단계' : '-',
              style: const TextStyle(
                fontFamily: 'Pretendard',
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
              color: Color(0xFFF0F0F0),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  '성장 단계',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B6B6B),
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
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    growthStageLabel,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
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

  /// 5단계 WCI 프로그레스 바 (홈 화면 패턴 재사용)
  Widget _buildWciProgressBars(int wciLevel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSegment(wciLevel >= 1),
        const SizedBox(width: 2),
        _buildSegment(wciLevel >= 2),
        const SizedBox(width: 2),
        // 중앙 인디케이터
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: wciLevel >= 3
                  ? AppColors.brandPrimary
                  : const Color(0xFFF0F0F0),
              width: 2,
            ),
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 2),
        _buildSegment(wciLevel >= 4),
        const SizedBox(width: 2),
        _buildSegment(wciLevel >= 5),
      ],
    );
  }

  Widget _buildSegment(bool isActive) {
    return Container(
      width: 56,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.brandPrimary : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(1),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
      ),
    );
  }

  // --- 헬퍼 메서드 ---

  Color _getScoreColor(double score) {
    if (score >= 80) return const Color(0xFF4CAF50);
    if (score >= 60) return AppColors.brandPrimary;
    if (score >= 40) return const Color(0xFFFF9800);
    return const Color(0xFFFF572D);
  }

  String _getScoreLabel(double score) {
    if (score >= 80) return '건강한 상태';
    if (score >= 60) return '안정적인 상태';
    if (score >= 40) return '주의가 필요해요';
    if (score > 0) return '관리가 필요해요';
    return '데이터 부족';
  }

  String _getScoreDescription(double score) {
    if (score >= 80) return '체중, 식사, 수분 모두 양호합니다.\n지금 습관을 유지해 주세요.';
    if (score >= 60) return '전반적으로 괜찮지만\n일부 항목을 확인해 보세요.';
    if (score >= 40) return '몇 가지 항목에서 변화가 감지되었어요.\n데이터를 확인해 보세요.';
    if (score > 0) return '건강 지표가 낮은 편이에요.\n식사량과 수분을 점검해 주세요.';
    return '데이터를 입력하면 건강 점수를 확인할 수 있어요.';
  }

  String? _mapGrowthStage(String? stage) {
    switch (stage) {
      case 'adult':
        return '성체 (청년기)';
      case 'post_growth':
        return '후속 성장기';
      case 'rapid_growth':
        return '빠른 성장기';
      default:
        return null;
    }
  }
}
