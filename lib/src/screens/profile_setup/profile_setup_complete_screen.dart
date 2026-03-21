import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../../l10n/app_localizations.dart';

/// 프로필 설정 완료 화면
class ProfileSetupCompleteScreen extends ConsumerWidget {
  final String? petName;

  const ProfileSetupCompleteScreen({
    super.key,
    this.petName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = petName ?? l10n.pet_defaultName;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 앱바
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Stack(
                children: [
                  // 뒤로가기 버튼
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Semantics(
                      button: true,
                      label: 'Go back',
                      child: GestureDetector(
                      onTap: () => context.pop(),
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: SvgPicture.asset(
                          'assets/images/profile/back_arrow.svg',
                        ),
                      ),
                      ),
                    ),
                  ),
                  // 제목
                  Center(
                    child: Text(
                      l10n.profileSetup_doneTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: AppColors.nearBlack,
                        height: 34 / 20,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 완료 아이콘
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.gray350,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.mediumGray,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 완료 메시지
                  Text(
                    l10n.profileSetup_doneMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: AppColors.nearBlack,
                      height: 34 / 24,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 부가 메시지
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.warmGray,
                      height: 20 / 14,
                      letterSpacing: -0.35,
                    ),
                  ),
                ],
              ),
            ),
            // 하단 버튼들
            _buildBottomButtons(context, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
      child: Row(
        children: [
          // 다음에 버튼
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.common_later,
              child: GestureDetector(
              onTap: () => _handleSkip(context),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.warmGray,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    l10n.common_later,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warmGray,
                      letterSpacing: -0.45,
                      height: 1.44,
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 기록 시작! 버튼
          Expanded(
            child: Semantics(
              button: true,
              label: l10n.profileSetup_startRecording,
              child: GestureDetector(
              onTap: () => _handleStart(context),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [AppColors.brandPrimary, AppColors.brandDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    l10n.profileSetup_startRecording,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.45,
                      height: 1.44,
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSkip(BuildContext context) {
    // 다음에 - 홈으로 이동
    context.goNamed(RouteNames.home);
  }

  void _handleStart(BuildContext context) {
    // 기록 시작 - 홈으로 이동
    context.goNamed(RouteNames.home);
  }
}
