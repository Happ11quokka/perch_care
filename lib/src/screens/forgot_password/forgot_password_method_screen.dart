import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';

/// 비밀번호 찾기 - 방법 선택 화면
class ForgotPasswordMethodScreen extends StatefulWidget {
  const ForgotPasswordMethodScreen({super.key});

  @override
  State<ForgotPasswordMethodScreen> createState() =>
      _ForgotPasswordMethodScreenState();
}

class _ForgotPasswordMethodScreenState
    extends State<ForgotPasswordMethodScreen> {
  final _authService = AuthService();

  // 선택된 방법: 'phone' 또는 'email'
  String _selectedMethod = 'phone';

  // 사용자 연락처 (프로필에서 로드)
  String _phoneNumber = '';
  String _email = '';
  bool _isLoadingProfile = true;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadUserContact();
  }

  Future<void> _loadUserContact() async {
    try {
      final profile = await _authService.getProfile();
      if (!mounted) return;
      setState(() {
        _email = profile?['email'] as String? ?? '';
        _phoneNumber = profile?['phone'] as String? ?? '';
        _isLoadingProfile = false;
        // phone 정보가 없으면 email을 기본 선택
        if (_phoneNumber.isEmpty) {
          _selectedMethod = 'email';
        }
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
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
          '비밀번호 찾기',
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
        child: _isLoadingProfile
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // 안내 문구
                      const Text(
                        '암호를 재설정하는 데 필요한 코드번호를 받으실 방법을 선택해 주세요.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF97928A),
                          letterSpacing: -0.35,
                          height: 1.43,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 휴대폰 번호 옵션 (번호가 있을 때만 표시)
                      if (_phoneNumber.isNotEmpty) ...[
                        _buildMethodOption(
                          method: 'phone',
                          icon: 'assets/images/phone_icon.svg',
                          label: '휴대폰 번호',
                          value: _phoneNumber,
                          isSelected: _selectedMethod == 'phone',
                        ),
                        const SizedBox(height: 8),
                      ],
                      // 이메일 옵션
                      if (_email.isNotEmpty)
                        _buildMethodOption(
                          method: 'email',
                          icon: 'assets/images/mail_gray_icon.svg',
                          label: '이메일',
                          value: _email,
                          isSelected: _selectedMethod == 'email',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 50),
              child: _buildSendCodeButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodOption({
    required String method,
    required String icon,
    required String label,
    required String value,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;
        });
      },
      child: Container(
        height: 112,
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFF9A42)
                : const Color(0xFF97928A),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const SizedBox(width: 20),
            // 아이콘 원형 배경
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF9A42).withValues(alpha: 0.3)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isSelected
                    ? null
                    : Border.all(
                        color: const Color(0xFF97928A),
                        width: 1,
                      ),
              ),
              child: Center(
                child: SvgPicture.asset(
                  icon,
                  width: 28,
                  height: 28,
                  colorFilter: ColorFilter.mode(
                    isSelected
                        ? const Color(0xFFFF9A42)
                        : const Color(0xFF97928A),
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 텍스트 영역
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF97928A),
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? const Color(0xFF1A1A1A)
                          : const Color(0xFF97928A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSendCodeButton() {
    return GestureDetector(
      onTap: _isSending ? null : _handleSendCode,
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
        child: Center(
          child: _isSending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  '코드 보내기',
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

  Future<void> _handleSendCode() async {
    if (_isSending) return;

    setState(() => _isSending = true);

    final destination = _selectedMethod == 'phone' ? _phoneNumber : _email;

    try {
      if (_selectedMethod == 'email') {
        await _authService.resetPassword(destination);
      } else {
        await _authService.resetPasswordByPhone(destination);
      }

      if (!mounted) return;

      context.pushNamed(
        RouteNames.forgotPasswordCode,
        extra: {
          'method': _selectedMethod,
          'destination': destination,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코드 전송 중 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
