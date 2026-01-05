import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';

/// 비밀번호 재설정 완료 화면
class BiometricCompleteScreen extends StatelessWidget {
  const BiometricCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),
                  // 완료 제목
                  const Text(
                    '비밀번호 재설정 완료',
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
                  const SizedBox(height: 16),
                  // 안내 문구
                  const Text(
                    '새로운 비밀번호로 재설정 되었습니다.\n신규 비밀번호를 입력하셔서 로그인을 진행하세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF97928A),
                      letterSpacing: -0.35,
                      height: 1.43,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // 방패 체크 아이콘
                  Image.asset(
                    'assets/images/shield_check_icon.png',
                    width: 180,
                    height: 180,
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
            // 하단 로그인 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 50),
              child: GestureDetector(
                onTap: () => _handleLogin(context),
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
                      '로그인',
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
    );
  }

  void _handleLogin(BuildContext context) {
    // 로그인 화면으로 이동 (스택 정리)
    context.goNamed(RouteNames.emailLogin);
  }
}
