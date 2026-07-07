import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/durations.dart';
import '../../router/route_names.dart';
import '../../providers/repository_providers.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/password_strength_indicator.dart';
import '../../widgets/pressable_scale.dart';
import '../../widgets/terms_agreement_section.dart';
import '../../../l10n/app_localizations.dart';

/// 회원가입 화면 - Figma 디자인 기반
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _hasNavigatedAfterSignup = false;
  bool _allRequiredTermsAgreed = false;
  bool _marketingAgreed = false;
  bool _nameHasFocus = false;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;
  bool _confirmPasswordHasFocus = false;

  // 제출 실패 시 문제 필드 테두리를 danger 색으로 표시
  bool _nameHasError = false;
  bool _emailHasError = false;
  bool _passwordHasError = false;
  bool _confirmPasswordHasError = false;

  final _nameFieldKey = GlobalKey<FormFieldState<String>>();
  final _emailFieldKey = GlobalKey<FormFieldState<String>>();
  final _passwordFieldKey = GlobalKey<FormFieldState<String>>();
  final _confirmPasswordFieldKey = GlobalKey<FormFieldState<String>>();

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
    _confirmPasswordFocusNode.addListener(_onConfirmPasswordFocusChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.removeListener(_onNameFocusChange);
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _passwordFocusNode.removeListener(_onPasswordFocusChange);
    _confirmPasswordFocusNode.removeListener(_onConfirmPasswordFocusChange);
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordController.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _onNameFocusChange() => setState(() => _nameHasFocus = _nameFocusNode.hasFocus);
  void _onEmailFocusChange() => setState(() => _emailHasFocus = _emailFocusNode.hasFocus);
  void _onPasswordFocusChange() => setState(() => _passwordHasFocus = _passwordFocusNode.hasFocus);
  void _onConfirmPasswordFocusChange() => setState(() => _confirmPasswordHasFocus = _confirmPasswordFocusNode.hasFocus);

  bool get _nameHasValue => _nameController.text.isNotEmpty;
  bool get _emailHasValue => _emailController.text.isNotEmpty;
  bool get _passwordHasValue => _passwordController.text.isNotEmpty;
  bool get _confirmPasswordHasValue => _confirmPasswordController.text.isNotEmpty;

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
          l10n.signup_title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.nearBlack,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Semantics(
        label: 'Dismiss keyboard',
        child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
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
                          hasError: _nameHasError,
                          fieldKey: _nameFieldKey,
                          onChangedClearError: () => _nameHasError = false,
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
                          hasError: _emailHasError,
                          fieldKey: _emailFieldKey,
                          onChangedClearError: () => _emailHasError = false,
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
                          hasError: _passwordHasError,
                          fieldKey: _passwordFieldKey,
                          onChangedClearError: () => _passwordHasError = false,
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
                        // 비밀번호 강도 표시기
                        PasswordStrengthIndicator(
                          password: _passwordController.text,
                        ),
                        const SizedBox(height: 16),
                        // 비밀번호 확인 필드
                        _buildInputField(
                          label: l10n.input_confirmPassword,
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocusNode,
                          hintText: l10n.validation_confirmPassword,
                          iconPath: _lockIconPath,
                          hasFocus: _confirmPasswordHasFocus,
                          hasValue: _confirmPasswordHasValue,
                          hasError: _confirmPasswordHasError,
                          fieldKey: _confirmPasswordFieldKey,
                          onChangedClearError: () => _confirmPasswordHasError = false,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          suffixWidget: (_confirmPasswordHasValue &&
                                  _passwordController.text.isNotEmpty &&
                                  _confirmPasswordController.text ==
                                      _passwordController.text)
                              ? const Icon(Icons.check_circle,
                                  color: AppColors.success, size: 20)
                              : null,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return l10n.validation_confirmPassword;
                            }
                            if (value != _passwordController.text) {
                              return l10n.validation_passwordMismatch;
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
                              _marketingAgreed = marketingAgreed;
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
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.warmGray,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: l10n.login_button,
                    child: GestureDetector(
                    onTap: () => context.pop(),
                    child: Text(
                      l10n.login_button,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                        letterSpacing: -0.35,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.brandPrimary,
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
    required bool hasError,
    required GlobalKey<FormFieldState<String>> fieldKey,
    VoidCallback? onChangedClearError,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixWidget,
    TextInputAction textInputAction = TextInputAction.next,
  }) {
    // 활성 상태: 포커스가 있거나 값이 있을 때
    final isActive = hasFocus || hasValue;
    final borderColor = hasError
        ? AppColors.danger
        : (isActive ? AppColors.brandPrimary : AppColors.warmGray);
    final bgColor = (hasFocus && hasValue)
        ? AppColors.brandPrimary.withValues(alpha: 0.1)
        : Colors.transparent;
    final iconColor = hasError
        ? AppColors.danger
        : (isActive ? AppColors.brandPrimary : AppColors.warmGray);

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
        AnimatedContainer(
          duration: AppDurations.of(context, AppDurations.quick),
          curve: AppCurves.enter,
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
                  key: fieldKey,
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  obscureText: obscureText,
                  validator: validator,
                  textInputAction: textInputAction,
                  onChanged: (_) => setState(() {
                    onChangedClearError?.call();
                  }),
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
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    filled: false,
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                    errorStyle: const TextStyle(height: 0, fontSize: 0),
                  ),
                ),
              ),
              if (suffixWidget != null) ...[
                suffixWidget,
                const SizedBox(width: 12),
              ] else ...[
                const SizedBox(width: 20),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignupButton() {
    final l10n = AppLocalizations.of(context);
    final isEnabled = _allRequiredTermsAgreed && !_isLoading;
    return Semantics(
      button: true,
      label: l10n.signup_button,
      child: PressableScale(
      onTap: isEnabled ? _handleSignup : null,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.brandPrimary, AppColors.brandDark],
                )
              : null,
          color: isEnabled ? null : AppColors.beige,
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

  /// 회원가입 성공 후 소셜 계정 연동 안내 다이얼로그
  void _showSocialLinkDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.signup_completeTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
          ),
        ),
        content: Text(
          l10n.signup_completeMessage,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mediumGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (_hasNavigatedAfterSignup) return;
              _hasNavigatedAfterSignup = true;
              final router = GoRouter.of(context);
              Navigator.pop(dialogContext);
              // 가입 시 자동 저장된 토큰 제거 후 로그인 페이지로 이동
              await ref.read(authRepositoryProvider).discardSession();
              router.goNamed(RouteNames.login);
            },
            child: Text(
              l10n.common_later,
              style: const TextStyle(
                color: AppColors.warmGray,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_hasNavigatedAfterSignup) return;
              _hasNavigatedAfterSignup = true;
              final router = GoRouter.of(context);
              Navigator.pop(dialogContext);
              // 가입 시 자동 저장된 토큰 제거 후 로그인 페이지로 이동
              await ref.read(authRepositoryProvider).discardSession();
              router.goNamed(RouteNames.login);
            },
            child: Text(
              l10n.common_confirm,
              style: const TextStyle(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    final l10n = AppLocalizations.of(context);
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      // 유효성 검사 실패 시 문제 필드 테두리를 danger 색으로 표시 + 햅틱
      setState(() {
        _nameHasError = _nameFieldKey.currentState?.hasError ?? false;
        _emailHasError = _emailFieldKey.currentState?.hasError ?? false;
        _passwordHasError = _passwordFieldKey.currentState?.hasError ?? false;
        _confirmPasswordHasError =
            _confirmPasswordFieldKey.currentState?.hasError ?? false;
      });
      // 햅틱은 AppSnackBar.warning이 내부에서 발생시킴 (중복 호출 금지)
      AppSnackBar.warning(context, message: l10n.validation_checkInput);
      return;
    }
    // 비밀번호 일치 이중 검사 (안전 장치)
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _confirmPasswordHasError = true);
      AppSnackBar.warning(context, message: l10n.validation_passwordMismatch);
      return;
    }
    // 유효 → 에러 상태 초기화
    setState(() {
      _nameHasError = false;
      _emailHasError = false;
      _passwordHasError = false;
      _confirmPasswordHasError = false;
    });
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      final name = _nameController.text.trim();

      await ref.read(authRepositoryProvider).signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nickname: name,
        marketingAgreed: _marketingAgreed,
      );
      if (!mounted) return;
      // 회원가입 성공 후 소셜 계정 연동 안내
      _showSocialLinkDialog();
    } catch (e) {
      if (!mounted) return;
      final msg = ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.signup);
      AppSnackBar.error(context, message: msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
