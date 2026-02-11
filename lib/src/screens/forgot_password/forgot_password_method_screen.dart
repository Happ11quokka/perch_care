import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 비밀번호 찾기 - 이메일 입력 화면
class ForgotPasswordMethodScreen extends StatefulWidget {
  const ForgotPasswordMethodScreen({super.key});

  @override
  State<ForgotPasswordMethodScreen> createState() =>
      _ForgotPasswordMethodScreenState();
}

class _ForgotPasswordMethodScreenState
    extends State<ForgotPasswordMethodScreen> {
  final _authService = AuthService();
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
        title: Text(
          l10n.forgot_title,
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
                      Text(
                        l10n.forgot_description,
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
                      // 이메일 입력 필드
                      Text(
                        l10n.input_email,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'example@email.com',
                          hintStyle: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFD1CCC3),
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
                                  ? const Color(0xFFE53935)
                                  : const Color(0xFFE8E3DA),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFFF9A42),
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE53935),
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE53935),
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
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFE53935),
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
    );
  }

  Widget _buildSendCodeButton() {
    final l10n = AppLocalizations.of(context);
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
              : Text(
                  l10n.btn_sendCode,
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
      AppSnackBar.error(context, message: l10n.error_sendCode);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
