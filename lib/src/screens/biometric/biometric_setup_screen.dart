import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';

/// 지문 인증 등록 화면
class BiometricSetupScreen extends StatelessWidget {
  const BiometricSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/images/back_arrow_icon.svg',
            width: 18,
            height: 14,
            colorFilter: const ColorFilter.mode(
              Color(0xFF1A1A1A),
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          '지문 인증 등록',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
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
                  // 상단 여백 조정을 위한 Spacer
                  const Spacer(flex: 1),
                  // 안내 문구
                  const Text(
                    '빠른 이용을 위해\n생체 인증을 설정하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.7,
                      height: 1.36,
                    ),
                  ),
                  const SizedBox(height: 60),
                  // 지문 아이콘
                  SvgPicture.asset(
                    'assets/images/fingerprint_icon.svg',
                    width: 140,
                    height: 158,
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            // 하단 버튼들
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 50),
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
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 사용 동의 버튼
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _handleAgree(context),
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
                            '사용 동의',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.45,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSkip(BuildContext context) {
    // 다음에 - 완료 화면으로 바로 이동
    context.goNamed(RouteNames.biometricComplete);
  }

  void _handleAgree(BuildContext context) {
    // TODO: 실제 생체 인증 등록 로직 구현
    // 동의 후 완료 화면으로 이동
    context.goNamed(RouteNames.biometricComplete);
  }
}
