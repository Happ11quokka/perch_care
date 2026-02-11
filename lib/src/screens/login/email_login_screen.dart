import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 이메일 로그인 화면 - Figma 디자인 기반
class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isKakaoLoading = false;
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
      if (result.provider == 'kakao') {
        _showKakaoSignupRequiredDialog();
      } else {
        // Apple/Google은 발생 안함
        final l10n = AppLocalizations.of(context)!;
        AppSnackBar.error(context, message: l10n.error_loginRetry);
      }
    }
  }

  /// 카카오 로그인 안내 다이얼로그
  void _showKakaoSignupRequiredDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFF9A42), size: 24),
            const SizedBox(width: 8),
            Text(
              l10n.dialog_kakaoLoginTitle,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.dialog_kakaoLoginContent1,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.dialog_kakaoLoginContent2,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.common_close,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                color: Color(0xFF97928A),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pushNamed(RouteNames.signup);
            },
            child: Text(
              l10n.dialog_goSignup,
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
          l10n.login_title,
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
                    child: Text(
                      l10n.login_signup,
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
    bool showPasswordToggle = false,
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
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
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
                        Color(0xFF97928A),
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
        GestureDetector(
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
                  color: _saveId ? const Color(0xFFFF9A42) : Colors.transparent,
                  border: Border.all(
                    color: _saveId ? const Color(0xFFFF9A42) : const Color(0xFF97928A),
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
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF97928A),
                  letterSpacing: 0.07,
                ),
              ),
            ],
          ),
        ),
        // 아이디/비밀번호 찾기
        GestureDetector(
          onTap: () {
            context.pushNamed(RouteNames.forgotPasswordMethod);
          },
          child: Text(
            l10n.login_findIdPassword,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF97928A),
              letterSpacing: 0.07,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    final l10n = AppLocalizations.of(context)!;
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
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
              : Text(
                  l10n.login_button,
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

  Widget _buildSocialLoginRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 카카오
        _buildSocialLoginButton(
          onTap: _handleKakaoLogin,
          isLoading: _isKakaoLoading,
          child: SvgPicture.asset(
            'assets/images/btn_kakao/btn_kakao.svg',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: 8),
        // 구글
        _buildSocialLoginButton(
          onTap: _handleGoogleLogin,
          isLoading: _isGoogleLoading,
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
          child: const Icon(
            Icons.apple,
            size: 24,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButton({
    required VoidCallback onTap,
    required bool isLoading,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : child,
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
      _navigateAfterLogin();
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.error_login);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      debugPrint('[Google] Starting login...');
      final signIn = GoogleSignIn.instance;
      debugPrint('[Google] Calling authenticate...');
      final account = await signIn.authenticate();
      debugPrint('[Google] Got account: ${account.email}');
      final idToken = account.authentication.idToken;
      debugPrint('[Google] Got idToken: ${idToken?.substring(0, 20)}...');
      if (idToken == null) throw Exception('idToken is null');
      final result = await _authService.signInWithGoogle(idToken: idToken);
      debugPrint('[Google] API result: success=${result.success}');
      if (!mounted) return;
      _handleSocialLoginResult(result);
    } on GoogleSignInException catch (e) {
      debugPrint('[Google] GoogleSignInException: code=${e.code}');
      if (!mounted) return;
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      AppSnackBar.error(context, message: l10n.error_googleLogin);
    } catch (e, stackTrace) {
      debugPrint('[Google] Error: $e');
      debugPrint('[Google] StackTrace: $stackTrace');
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.error_googleLogin);
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
      debugPrint('Apple Sign In Error: ${e.code} - ${e.message}');
      AppSnackBar.error(context, message: l10n.error_appleLogin);
    } catch (e) {
      if (!mounted) return;
      debugPrint('Apple Sign In Error: $e');
      AppSnackBar.error(context, message: l10n.error_appleLogin);
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _handleKakaoLogin() async {
    if (_isKakaoLoading) return;
    setState(() => _isKakaoLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      final result = await _authService.signInWithKakao(accessToken: token.accessToken);
      if (!mounted) return;
      _handleSocialLoginResult(result);
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.error_kakaoLogin);
    } finally {
      if (mounted) setState(() => _isKakaoLoading = false);
    }
  }
}
