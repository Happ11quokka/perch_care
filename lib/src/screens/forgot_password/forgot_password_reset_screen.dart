import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import 'dart:async';
import 'dart:io';

import '../../services/api/api_client.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 비밀번호 찾기 - 새 비밀번호 입력 화면
class ForgotPasswordResetScreen extends ConsumerStatefulWidget {
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
  ConsumerState<ForgotPasswordResetScreen> createState() =>
      _ForgotPasswordResetScreenState();
}

class _ForgotPasswordResetScreenState extends ConsumerState<ForgotPasswordResetScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  final _authService = AuthService.instance;
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
    final l10n = AppLocalizations.of(context);
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
        title: Text(
          l10n.forgot_newPasswordTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.nearBlack,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
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
                      Text(
                        l10n.forgot_newPasswordDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.warmGray,
                          letterSpacing: -0.35,
                          height: 1.43,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 새로운 비밀번호 필드
                      _buildPasswordField(
                        label: l10n.input_newPassword,
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
                        label: l10n.input_confirmPassword,
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
        isActive ? AppColors.brandPrimary : AppColors.warmGray;
    final bgColor = (hasFocus && hasValue)
        ? AppColors.brandPrimary.withValues(alpha: 0.1)
        : Colors.transparent;
    final iconColor =
        isActive ? AppColors.brandPrimary : AppColors.warmGray;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.warmGray,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: AppColors.nearBlack,
                    letterSpacing: 0.07,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.warmGray,
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
              Semantics(
                button: true,
                label: obscureText ? 'Show password' : 'Hide password',
                child: GestureDetector(
                onTap: onToggleObscure,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: SvgPicture.asset(
                    'assets/images/eye_off_filled_icon.svg',
                    width: 20,
                    height: 17,
                    colorFilter: const ColorFilter.mode(
                      AppColors.warmGray,
                      BlendMode.srcIn,
                    ),
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
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.btn_resetComplete,
      child: GestureDetector(
      onTap: _isLoading ? null : _handleResetPassword,
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
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  l10n.btn_resetComplete,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.45,
                  ),
                ),
        ),
      ),
      ),
    );
  }

  Future<void> _handleResetPassword() async {
    final l10n = AppLocalizations.of(context);
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty) {
      AppSnackBar.warning(context, message: l10n.validation_enterNewPassword);
      return;
    }

    if (confirmPassword.isEmpty) {
      AppSnackBar.warning(context, message: l10n.validation_confirmPassword);
      return;
    }

    if (newPassword != confirmPassword) {
      AppSnackBar.warning(context, message: l10n.validation_passwordMismatch);
      return;
    }

    if (newPassword.length < 8) {
      AppSnackBar.warning(context, message: l10n.validation_passwordMin8);
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

      final l10n = AppLocalizations.of(context);
      AppSnackBar.success(context, message: l10n.snackbar_passwordChanged);
      context.goNamed(RouteNames.login);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (e is SocketException || e is TimeoutException) {
        AppSnackBar.error(context, message: l10n.error_network);
      } else if (e is ApiException && e.statusCode >= 500) {
        AppSnackBar.error(context, message: l10n.error_server);
      } else {
        AppSnackBar.error(context, message: l10n.error_passwordChange);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
