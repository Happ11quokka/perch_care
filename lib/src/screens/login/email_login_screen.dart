import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 이메일 로그인 화면 - Figma 디자인 기반
class EmailLoginScreen extends ConsumerStatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  ConsumerState<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends ConsumerState<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final AuthService _authService = AuthService.instance;

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  bool _saveId = false;
  bool _obscurePassword = true;
  bool _emailHasFocus = false;
  bool _passwordHasFocus = false;
  bool _hasNavigatedAfterLogin = false;

  // 아이콘 에셋 경로
  static const String _emailIconPath = 'assets/images/signup_vector/email.svg';
  static const String _lockIconPath = 'assets/images/signup_vector/password.svg';
  static const String _checkIconPath =
      'assets/images/b54717784f94f4ef1b3ab356fb0d4011afe42f97.svg';
  static const String _checkIconGrayPath = 'assets/images/check_gray_icon.svg';
  static const String _eyeOffIconPath =
      'assets/images/f0ffc30923267d4d3ce1de841633a20fc519ce41.svg';

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onEmailFocusChange);
    _passwordFocusNode.addListener(_onPasswordFocusChange);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _passwordFocusNode.removeListener(_onPasswordFocusChange);
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onEmailFocusChange() {
    setState(() {
      _emailHasFocus = _emailFocusNode.hasFocus;
    });
  }

  void _onPasswordFocusChange() {
    setState(() {
      _passwordHasFocus = _passwordFocusNode.hasFocus;
    });
  }

  Future<void> _navigateAfterLogin() async {
    if (!mounted || _hasNavigatedAfterLogin) return;
    _hasNavigatedAfterLogin = true;

    // 펫 유무 확인 — 없으면 첫 로그인으로 간주하여 프로필 설정으로
    final hasPets = await _authService.hasPets();
    if (!mounted) return;

    if (hasPets) {
      context.goNamed(RouteNames.home);
    } else {
      context.goNamed(RouteNames.profileSetup);
    }
  }

  /// 소셜 로그인 결과 처리
  Future<void> _handleSocialLoginResult(SocialLoginResult result) async {
    if (result.success) {
      await _navigateAfterLogin();
    } else if (result.signupRequired) {
      final l10n = AppLocalizations.of(context)!;
      AppSnackBar.error(context, message: l10n.error_socialAccountConflict);
    }
  }

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
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          l10n.login_title,
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 43),
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
                        ),
                        const SizedBox(height: 20),
                        // 비밀번호 필드
                        _buildInputField(
                          label: l10n.input_password,
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          hintText: l10n.input_password_hint,
                          iconPath: _lockIconPath,
                          hasFocus: _passwordHasFocus,
                          hasValue: _passwordHasValue,
                          obscureText: _obscurePassword,
                          showPasswordToggle: true,
                        ),
                        const SizedBox(height: 16),
                        // 아이디 저장 & 아이디/비밀번호 찾기
                        _buildOptionsRow(),
                        const SizedBox(height: 50),
                        // 로그인 버튼
                        _buildLoginButton(),
                        const SizedBox(height: 40),
                        // 소셜 로그인 아이콘들
                        _buildSocialLoginRow(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 하단 회원가입 안내
            Padding(
              padding: const EdgeInsets.only(bottom: 50),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.login_notMember,
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
                    label: l10n.login_signup,
                    child: GestureDetector(
                    onTap: () => context.pushNamed(RouteNames.signup),
                    child: Text(
                      l10n.login_signup,
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
    bool showPasswordToggle = false,
  }) {
    // 활성 상태: 포커스가 있거나 값이 있을 때
    final isActive = hasFocus || hasValue;
    final borderColor = isActive ? AppColors.brandPrimary : AppColors.warmGray;
    final bgColor = (hasFocus && hasValue)
        ? AppColors.brandPrimary.withValues(alpha: 0.1)
        : Colors.transparent;
    final iconColor = isActive ? AppColors.brandPrimary : AppColors.warmGray;

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
                iconPath,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
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
                    filled: false, // 테마 기본 배경색 제거
                    fillColor: Colors.transparent,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (showPasswordToggle)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: SvgPicture.asset(
                      _eyeOffIconPath,
                      width: 20,
                      height: 17,
                      colorFilter: const ColorFilter.mode(
                        AppColors.warmGray,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsRow() {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 아이디 저장 체크박스
        Semantics(
          button: true,
          label: l10n.login_saveId,
          child: GestureDetector(
          onTap: () {
            setState(() {
              _saveId = !_saveId;
            });
          },
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _saveId ? AppColors.brandPrimary : Colors.transparent,
                  border: Border.all(
                    color: _saveId ? AppColors.brandPrimary : AppColors.warmGray,
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _saveId
                    ? Padding(
                        padding: const EdgeInsets.all(3),
                        child: SvgPicture.asset(
                          _checkIconPath,
                          width: 16,
                          height: 16,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(3),
                        child: SvgPicture.asset(
                          _checkIconGrayPath,
                          width: 16,
                          height: 16,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.login_saveId,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.warmGray,
                  letterSpacing: 0.07,
                ),
              ),
            ],
          ),
        ),
        ),
        // 아이디/비밀번호 찾기
        Semantics(
          button: true,
          label: l10n.login_findIdPassword,
          child: GestureDetector(
          onTap: () {
            context.pushNamed(RouteNames.forgotPasswordMethod);
          },
          child: Text(
            l10n.login_findIdPassword,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.warmGray,
              letterSpacing: 0.07,
            ),
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      button: true,
      label: l10n.login_button,
      child: GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
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
                  l10n.login_button,
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

  Widget _buildSocialLoginRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 구글
        _buildSocialLoginButton(
          onTap: _handleGoogleLogin,
          isLoading: _isGoogleLoading,
          borderColor: const Color(0xFF747775),
          semanticsLabel: 'Sign in with Google',
          child: SvgPicture.asset(
            'assets/images/btn_google/btn_google.svg',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 8),
        // 애플
        _buildSocialLoginButton(
          onTap: _handleAppleLogin,
          isLoading: _isAppleLoading,
          backgroundColor: Colors.black,
          borderColor: Colors.black,
          loadingColor: Colors.white,
          semanticsLabel: 'Sign in with Apple',
          child: SvgPicture.asset(
            'assets/images/btn_apple/apple_logo_white.svg',
            width: 60,
            height: 60,
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButton({
    required VoidCallback onTap,
    required bool isLoading,
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
    Color? loadingColor,
    String? semanticsLabel,
  }) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border.all(color: borderColor ?? AppColors.gray300, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: loadingColor,
                  ),
                )
              : child,
        ),
      ),
    ),
    );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      AppSnackBar.warning(context, message: l10n.validation_enterEmail);
      return;
    }

    if (password.isEmpty) {
      AppSnackBar.warning(context, message: l10n.validation_enterPassword);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      await _navigateAfterLogin();
    } catch (e) {
      if (!mounted) return;
      final msg = ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.login);
      AppSnackBar.error(context, message: msg);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      if (kDebugMode) debugPrint('[Google] Starting login...');
      final signIn = GoogleSignIn.instance;
      final account = await signIn.authenticate();
      if (kDebugMode) debugPrint('[Google] Got account');
      final idToken = account.authentication.idToken;
      if (kDebugMode) debugPrint('[Google] idToken received: ${idToken != null}');
      if (idToken == null) throw Exception('idToken is null');
      final result = await _authService.signInWithGoogle(idToken: idToken);
      if (kDebugMode) debugPrint('[Google] API result: success=${result.success}');
      if (!mounted) return;
      _handleSocialLoginResult(result);
    } on GoogleSignInException catch (e) {
      if (kDebugMode) debugPrint('[Google] GoogleSignInException: code=${e.code}');
      if (!mounted) return;
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      AppSnackBar.error(context, message: l10n.error_googleLogin);
    } catch (e, stackTrace) {
      if (kDebugMode) debugPrint('[Google] Error: $e');
      if (kDebugMode) debugPrint('[Google] StackTrace: $stackTrace');
      if (!mounted) return;
      final msg = ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.socialLogin);
      AppSnackBar.error(context, message: msg);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    if (_isAppleLoading) return;
    setState(() => _isAppleLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('identityToken is null');

      // fullName 조합 (Apple은 최초 로그인 시에만 이름 제공)
      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        fullName =
            '${credential.givenName ?? ''} ${credential.familyName ?? ''}'
                .trim();
        if (fullName.isEmpty) fullName = null;
      }

      final result = await _authService.signInWithApple(
        idToken: idToken,
        userIdentifier: credential.userIdentifier,
        fullName: fullName,
        email: credential.email,
      );
      if (!mounted) return;
      _handleSocialLoginResult(result);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!mounted) return;
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (kDebugMode) debugPrint('[Apple] Error: ${e.code}');
      AppSnackBar.error(context, message: l10n.error_appleLogin);
    } catch (e) {
      if (!mounted) return;
      if (kDebugMode) debugPrint('[Apple] Error: $e');
      final msg = ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.socialLogin);
      AppSnackBar.error(context, message: msg);
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

}
