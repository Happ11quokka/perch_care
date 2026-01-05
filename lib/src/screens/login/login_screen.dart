import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth/auth_service.dart';

/// 로그인 화면 - Figma 디자인 기반
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isKakaoLoading = false;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _hasNavigatedAfterLogin = false;

  @override
  void initState() {
    super.initState();
    _authStateSubscription =
        _authService.authStateChanges.listen(_handleAuthStateChange);
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _handleAuthStateChange(AuthState state) {
    if (state.session == null) return;
    if (state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.initialSession) {
      _navigateToHomeAfterLogin();
    }
  }

  void _navigateToHomeAfterLogin() {
    if (!mounted || _hasNavigatedAfterLogin) return;
    _hasNavigatedAfterLogin = true;
    context.goNamed(RouteNames.home);
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
      _navigateToHomeAfterLogin();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Google 로그인 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    if (_isAppleLoading) return;
    setState(() => _isAppleLoading = true);
    try {
      await _authService.signInWithApple();
      _navigateToHomeAfterLogin();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apple 로그인 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _handleKakaoLogin() async {
    if (_isKakaoLoading) return;
    setState(() => _isKakaoLoading = true);
    try {
      // TODO: 카카오 로그인 구현
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('카카오 로그인은 준비 중입니다.')),
      );
    } finally {
      if (mounted) setState(() => _isKakaoLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          '로그인',
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
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      // Social Login Buttons
                      _buildSocialLoginButton(
                        icon: _buildKakaoIcon(),
                        label: '카카오 로그인',
                        onTap: _handleKakaoLogin,
                        isLoading: _isKakaoLoading,
                      ),
                      const SizedBox(height: 16),
                      _buildSocialLoginButton(
                        icon: _buildGoogleIcon(),
                        label: '구글로 로그인',
                        onTap: _handleGoogleLogin,
                        isLoading: _isGoogleLoading,
                      ),
                      const SizedBox(height: 16),
                      _buildSocialLoginButton(
                        icon: _buildAppleIcon(),
                        label: '애플로 로그인',
                        onTap: _handleAppleLogin,
                        isLoading: _isAppleLoading,
                      ),
                      const SizedBox(height: 32),
                      // Primary Login Button
                      _buildPrimaryLoginButton(),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Sign Up Section
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '아직 회원이 아니신가요?',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF97928A),
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.pushNamed(RouteNames.signup),
                    child: const Text(
                      '회원가입',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFF9A42),
                        letterSpacing: -0.35,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFFF9A42),
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

  Widget _buildSocialLoginButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF97928A), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKakaoIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: Color(0xFFFFE812),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: SvgPicture.asset(
          'assets/images/btn_kakao/btn_kakao.svg',
          width: 24,
          height: 24,
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SvgPicture.asset(
      'assets/images/btn_google/btn_google.svg',
      width: 24,
      height: 24,
    );
  }

  Widget _buildAppleIcon() {
    return const Icon(
      Icons.apple,
      size: 24,
      color: Colors.black,
    );
  }

  Widget _buildPrimaryLoginButton() {
    return GestureDetector(
      onTap: () {
        // 이메일 로그인 화면으로 이동
        context.pushNamed(RouteNames.emailLogin);
      },
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
    );
  }
}
