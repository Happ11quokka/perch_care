import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';

class WciIndexScreen extends StatelessWidget {
  const WciIndexScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
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
          l10n.wciIndex_title,
          style: const TextStyle(
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
              Text(
                l10n.wciIndex_description,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mediumGray,
                  height: 1.6,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.wciIndex_calculationMethod,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.weight_formulaText,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.nearBlack,
                  height: 1.6,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.wciIndex_levelCriteria,
                style: const TextStyle(
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
                      title: l10n.weight_level1Title,
                      range: 'WCI <= -7%',
                      description: l10n.weight_level1Desc,
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: l10n.weight_level2Title,
                      range: '-7% < WCI <= -3%',
                      description: l10n.weight_level2Desc,
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: l10n.weight_level3Title,
                      range: '-3% < WCI < +3%',
                      description: l10n.weight_level3Desc,
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: l10n.weight_level4Title,
                      range: '+3% <= WCI < +8%',
                      description: l10n.weight_level4Desc,
                    ),
                    const SizedBox(height: 16),
                    _buildLevel(
                      title: l10n.weight_level5Title,
                      range: 'WCI >= +8%',
                      description: l10n.weight_level5Desc,
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
