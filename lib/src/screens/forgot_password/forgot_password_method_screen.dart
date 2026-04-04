import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 비밀번호 찾기 - 이메일 입력 화면
class ForgotPasswordMethodScreen extends ConsumerStatefulWidget {
  const ForgotPasswordMethodScreen({super.key});

  @override
  ConsumerState<ForgotPasswordMethodScreen> createState() =>
      _ForgotPasswordMethodScreenState();
}

class _ForgotPasswordMethodScreenState
    extends ConsumerState<ForgotPasswordMethodScreen> {
  final _authService = AuthService.instance;
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();

  bool _isSending = false;
  String? _emailError;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w\-.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email);
  }

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
          l10n.forgot_title,
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
                      Text(
                        l10n.forgot_description,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.warmGray,
                          letterSpacing: -0.35,
                          height: 1.43,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 이메일 입력 필드
                      Text(
                        l10n.input_email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.nearBlack,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppColors.nearBlack,
                          letterSpacing: -0.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'example@email.com',
                          hintStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppColors.lightGray,
                            letterSpacing: -0.4,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _emailError != null
                                  ? AppColors.danger
                                  : AppColors.beige,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.danger,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() => _emailError = null);
                          }
                        },
                      ),
                      if (_emailError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _emailError!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.danger,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
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
      ),
    );
  }

  Widget _buildSendCodeButton() {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.btn_sendCode,
      child: GestureDetector(
      onTap: _isSending ? null : _handleSendCode,
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
          child: _isSending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  l10n.btn_sendCode,
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

  Future<void> _handleSendCode() async {
    if (_isSending) return;

    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() => _emailError = l10n.validation_enterEmail);
      return;
    }

    if (!_isValidEmail(email)) {
      setState(() => _emailError = l10n.validation_invalidEmail);
      return;
    }

    setState(() => _isSending = true);

    try {
      await _authService.resetPassword(email);

      if (!mounted) return;

      context.pushNamed(
        RouteNames.forgotPasswordCode,
        extra: {
          'method': 'email',
          'destination': email,
        },
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final msg = ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.forgotPassword);
      AppSnackBar.error(context, message: msg);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
