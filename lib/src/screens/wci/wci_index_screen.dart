import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';

class WciIndexScreen extends StatelessWidget {
  const WciIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          'WCI 지수란?',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WCI (Weight Change Index)',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '섭취 습관의 변화가 체중에 어떤 영향을 주고 있는지를\n백분율로 보여주는 건강 지표입니다.',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mediumGray,
                  height: 1.6,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '계산 방법',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'WCI(%) = (현재 체중 - 기준 체중) ÷ 기준 체중 × 100',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.nearBlack,
                  height: 1.6,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'WCI 5단계 기준',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLevel(
                      title: 'Level 1 | 가벼운 상태',
                      range: 'WCI <= -7%',
                      description: '몸이 많이 가벼워요. 식사량과 컨디션을 점검해 주세요.',
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: 'Level 2 | 약간 가벼운 상태',
                      range: '-7% < WCI <= -3%',
                      description: '슬림한 편이에요. 현재 습관을 유지하며 관찰하세요.',
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: 'Level 3 | 이상적인 상태',
                      range: '-3% < WCI < +3%',
                      description: '균형이 가장 좋아요. 지금 상태를 유지하는 것이 좋아요.',
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: 'Level 4 | 약간 무거운 상태',
                      range: '+3% <= WCI < +8%',
                      description: '몸이 조금 묵직해 보여요. 식사 균형을 점검해 보세요.',
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: 'Level 5 | 무거운 상태',
                      range: 'WCI >= +8%',
                      description: '체중이 많이 늘었어요. 식단과 활동 조절이 필요해요.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevel({
    required String title,
    required String range,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '• $title',
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          range,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.nearBlack,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mediumGray,
            height: 1.6,
            letterSpacing: -0.35,
          ),
        ),
      ],
    );
  }
}
