import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';

/// 프로필 설정 완료 화면
class ProfileSetupCompleteScreen extends StatelessWidget {
  final String petName;

  const ProfileSetupCompleteScreen({
    super.key,
    this.petName = '점점이',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: SvgPicture.asset(
              'assets/images/back_arrow_icon.svg',
              width: 28,
              height: 28,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        centerTitle: true,
        title: const Text(
          '설정 완료',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
            height: 1.7,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 완료 아이콘
                  SvgPicture.asset(
                    'assets/images/profile_complete_icon.svg',
                    width: 120,
                    height: 120,
                  ),
                  const SizedBox(height: 32),
                  // 완료 메시지
                  const Text(
                    '설정이 완료되었습니다!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.6,
                      height: 1.42,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 부가 메시지
                  Text(
                    '$petName를 얄랄루 룰라룰라',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF97928A),
                      letterSpacing: -0.35,
                      height: 1.43,
                    ),
                  ),
                ],
              ),
            ),
            // 하단 버튼들
            _buildBottomButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 34),
      child: Row(
        children: [
          // 다음에 버튼
          Expanded(
            child: GestureDetector(
              onTap: () => _handleSkip(context),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF97928A),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '다음에',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97928A),
                      letterSpacing: -0.45,
                      height: 1.44,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 기록 시작! 버튼
          Expanded(
            child: GestureDetector(
              onTap: () => _handleStart(context),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '기록 시작!',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
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
