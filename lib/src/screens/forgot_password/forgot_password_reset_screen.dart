import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/app_snack_bar.dart';

/// 비밀번호 찾기 - 새 비밀번호 입력 화면
class ForgotPasswordResetScreen extends StatefulWidget {
  final String identifier; // 이메일 또는 전화번호
  final String code;
  final String method; // 'email' 또는 'phone'

  const ForgotPasswordResetScreen({
    super.key,
    required this.identifier,
    required this.code,
    this.method = 'email',
  });

  @override
  State<ForgotPasswordResetScreen> createState() =>
      _ForgotPasswordResetScreenState();
}

class _ForgotPasswordResetScreenState extends State<ForgotPasswordResetScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  final _authService = AuthService();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _newPasswordHasFocus = false;
  bool _confirmPasswordHasFocus = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _newPasswordFocusNode.addListener(_onNewPasswordFocusChange);
    _confirmPasswordFocusNode.addListener(_onConfirmPasswordFocusChange);
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordFocusNode.removeListener(_onNewPasswordFocusChange);
    _confirmPasswordFocusNode.removeListener(_onConfirmPasswordFocusChange);
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _onNewPasswordFocusChange() {
    setState(() {
      _newPasswordHasFocus = _newPasswordFocusNode.hasFocus;
    });
  }

  void _onConfirmPasswordFocusChange() {
    setState(() {
      _confirmPasswordHasFocus = _confirmPasswordFocusNode.hasFocus;
    });
  }

  bool get _newPasswordHasValue => _newPasswordController.text.isNotEmpty;
  bool get _confirmPasswordHasValue =>
      _confirmPasswordController.text.isNotEmpty;

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
          '새로운 비밀번호',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      // 안내 문구
                      const Text(
                        '새로운 비밀번호를 입력해 주세요,\n이전에 사용하신 비밀번호는 사용 하실 수 없습니다.',
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
                      // 새로운 비밀번호 필드
                      _buildPasswordField(
                        label: '새로운 비밀번호',
                        controller: _newPasswordController,
                        focusNode: _newPasswordFocusNode,
                        hintText: '비밀번호를 입력해 주세요',
                        hasFocus: _newPasswordHasFocus,
                        hasValue: _newPasswordHasValue,
                        obscureText: _obscureNewPassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      // 비밀번호 재입력 필드
                      _buildPasswordField(
                        label: '비밀번호 재입력',
                        controller: _confirmPasswordController,
                        focusNode: _confirmPasswordFocusNode,
                        hintText: '비밀번호를 입력해 주세요',
                        hasFocus: _confirmPasswordHasFocus,
                        hasValue: _confirmPasswordHasValue,
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // 하단 버튼
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 50),
              child: _buildResetButton(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required bool hasFocus,
    required bool hasValue,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    final isActive = hasFocus || hasValue;
    final borderColor =
        isActive ? const Color(0xFFFF9A42) : const Color(0xFF97928A);
    final bgColor = (hasFocus && hasValue)
        ? const Color(0xFFFF9A42).withValues(alpha: 0.1)
        : Colors.transparent;
    final iconColor =
        isActive ? const Color(0xFFFF9A42) : const Color(0xFF97928A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF97928A),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              SvgPicture.asset(
                'assets/images/signup_vector/password.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscureText,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.07,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF97928A),
                      letterSpacing: 0.07,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onToggleObscure,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: SvgPicture.asset(
                    'assets/images/eye_off_filled_icon.svg',
                    width: 20,
                    height: 17,
                    colorFilter: const ColorFilter.mode(
                      Color(0xFF97928A),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResetButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleResetPassword,
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
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  '재설정 완료',
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

  Future<void> _handleResetPassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      AppSnackBar.warning(context, message: '새로운 비밀번호를 입력해 주세요.');
      return;
    }

    if (confirmPassword.isEmpty) {
      AppSnackBar.warning(context, message: '비밀번호를 다시 입력해 주세요.');
      return;
    }

    if (newPassword != confirmPassword) {
      AppSnackBar.warning(context, message: '비밀번호가 일치하지 않습니다.');
      return;
    }

    if (newPassword.length < 8) {
      AppSnackBar.warning(context, message: '비밀번호는 8자 이상이어야 합니다.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.updatePassword(
        identifier: widget.identifier,
        code: widget.code,
        newPassword: newPassword,
        method: widget.method,
      );
      if (!mounted) return;

      AppSnackBar.success(context, message: '비밀번호가 성공적으로 변경되었습니다.');
      context.goNamed(RouteNames.login);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: '비밀번호 변경 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
