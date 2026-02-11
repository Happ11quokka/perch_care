import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../services/api/token_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/terms_agreement_section.dart';
import '../../../l10n/app_localizations.dart';

/// 회원가입 화면 - Figma 디자인 기반
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _hasNavigatedAfterSignup = false;
  bool _allRequiredTermsAgreed = false;
  bool _nameHasFocus = false;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;
  final AuthService _authService = AuthService();

  // 아이콘 에셋 경로
  static const String _personIconPath = 'assets/images/signup_vector/name.svg';
  static const String _emailIconPath = 'assets/images/signup_vector/email.svg';
  static const String _lockIconPath = 'assets/images/signup_vector/password.svg';

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(_onNameFocusChange);
    _emailFocusNode.addListener(_onEmailFocusChange);
    _passwordFocusNode.addListener(_onPasswordFocusChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.removeListener(_onNameFocusChange);
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _passwordFocusNode.removeListener(_onPasswordFocusChange);
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onNameFocusChange() => setState(() => _nameHasFocus = _nameFocusNode.hasFocus);
  void _onEmailFocusChange() => setState(() => _emailHasFocus = _emailFocusNode.hasFocus);
  void _onPasswordFocusChange() => setState(() => _passwordHasFocus = _passwordFocusNode.hasFocus);

  bool get _nameHasValue => _nameController.text.isNotEmpty;
  bool get _emailHasValue => _emailController.text.isNotEmpty;
  bool get _passwordHasValue => _passwordController.text.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(
          l10n.signup_title,
          style: const TextStyle(
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 43),
                        // 이름 필드
                        _buildInputField(
                          label: l10n.input_name,
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          hintText: l10n.input_name_hint,
                          iconPath: _personIconPath,
                          hasFocus: _nameHasFocus,
                          hasValue: _nameHasValue,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.input_name_hint;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        // 이메일 필드
                        _buildInputField(
                          label: l10n.input_email,
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          hintText: l10n.input_email_hint,
                          iconPath: _emailIconPath,
                          hasFocus: _emailHasFocus,
                          hasValue: _emailHasValue,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.input_email_hint;
                            }
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return l10n.validation_invalidEmail;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        // 비밀번호 필드
                        _buildInputField(
                          label: l10n.input_password,
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          hintText: l10n.input_password_hint,
                          iconPath: _lockIconPath,
                          hasFocus: _passwordHasFocus,
                          hasValue: _passwordHasValue,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.input_password_hint;
                            }
                            if (value.length < 8) {
                              return l10n.validation_passwordMin8;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // 약관 동의
                        TermsAgreementSection(
                          onChanged: (allRequiredAgreed, marketingAgreed) {
                            setState(() {
                              _allRequiredTermsAgreed = allRequiredAgreed;
                            });
                          },
                          termsRouteName: RouteNames.termsDetailPublic,
                        ),
                        const SizedBox(height: 24),
                        // 회원가입 버튼
                        _buildSignupButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 하단 로그인 안내
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.signup_alreadyMember,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF97928A),
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      l10n.login_button,
                      style: const TextStyle(
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

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required String iconPath,
    required bool hasFocus,
    required bool hasValue,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    // 활성 상태: 포커스가 있거나 값이 있을 때
    final isActive = hasFocus || hasValue;
    final borderColor = isActive ? const Color(0xFFFF9A42) : const Color(0xFF97928A);
    final bgColor = (hasFocus && hasValue)
        ? const Color(0xFFFF9A42).withValues(alpha: 0.1)
        : Colors.transparent;
    final iconColor = isActive ? const Color(0xFFFF9A42) : const Color(0xFF97928A);

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
                iconPath,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  validator: validator,
                  textInputAction: TextInputAction.next,
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
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
              const SizedBox(width: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton() {
    final l10n = AppLocalizations.of(context)!;
    final isEnabled = _allRequiredTermsAgreed && !_isLoading;
    return GestureDetector(
      onTap: isEnabled ? _handleSignup : null,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                )
              : null,
          color: isEnabled ? null : const Color(0xFFE7E5E1),
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
                  l10n.signup_button,
                  style: const TextStyle(
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

  /// 회원가입 성공 후 소셜 계정 연동 안내 다이얼로그
  void _showSocialLinkDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.signup_completeTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          l10n.signup_completeMessage,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B6B6B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_hasNavigatedAfterSignup) return;
              _hasNavigatedAfterSignup = true;
              Navigator.pop(dialogContext);
              // 가입 시 자동 저장된 토큰 제거 후 로그인 페이지로 이동
              TokenService.instance.clearTokens().then((_) {
                if (!context.mounted) return;
                context.goNamed(RouteNames.login);
              });
            },
            child: Text(
              l10n.common_later,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF97928A),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              if (_hasNavigatedAfterSignup) return;
              _hasNavigatedAfterSignup = true;
              Navigator.pop(dialogContext);
              // 가입 시 자동 저장된 토큰 제거 후 로그인 페이지로 이동
              TokenService.instance.clearTokens().then((_) {
                if (!context.mounted) return;
                context.goNamed(RouteNames.login);
              });
            },
            child: Text(
              l10n.common_confirm,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFFFF9A42),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context)!;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      // 유효성 검사 실패 시 에러 메시지 표시
      AppSnackBar.warning(context, message: l10n.validation_checkInput);
      return;
    }
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();

      await _authService.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nickname: name,
      );
      if (!mounted) return;
      // 회원가입 성공 후 소셜 계정 연동 안내
      _showSocialLinkDialog();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.error_unexpected);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
