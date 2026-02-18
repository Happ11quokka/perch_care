import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../router/route_paths.dart';
import '../../services/auth/auth_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

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
  bool _hasNavigatedAfterLogin = false;

  void _navigateToHomeAfterLogin() {
    if (!mounted || _hasNavigatedAfterLogin) return;
    _hasNavigatedAfterLogin = true;
    context.goNamed(RouteNames.home);
  }

  /// 소셜 로그인 결과 처리
  void _handleSocialLoginResult(SocialLoginResult result) {
    final l10n = AppLocalizations.of(context)!;
    if (result.success) {
      _navigateToHomeAfterLogin();
    } else if (result.signupRequired) {
      if (result.provider == 'kakao') {
        _showKakaoSignupRequiredDialog();
      } else {
        // Apple/Google은 발생 안함
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
      debugPrint('[Kakao] Starting login...');
      OAuthToken token;
      if (await isKakaoTalkInstalled()) {
        debugPrint('[Kakao] KakaoTalk installed, using KakaoTalk login');
        token = await UserApi.instance.loginWithKakaoTalk();
      } else {
        debugPrint('[Kakao] KakaoTalk not installed, using KakaoAccount login');
        token = await UserApi.instance.loginWithKakaoAccount();
      }
      debugPrint('[Kakao] Got token: ${token.accessToken.substring(0, 20)}...');
      final result = await _authService.signInWithKakao(accessToken: token.accessToken);
      debugPrint('[Kakao] API result: success=${result.success}, signupRequired=${result.signupRequired}');
      if (!mounted) return;
      _handleSocialLoginResult(result);
    } catch (e, stackTrace) {
      debugPrint('[Kakao] Error: $e');
      debugPrint('[Kakao] StackTrace: $stackTrace');
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.error_kakaoLogin);
    } finally {
      if (mounted) setState(() => _isKakaoLoading = false);
    }
  }

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
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.onboarding);
            }
          },
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
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      // Social Login Buttons
                      // TODO: 사업자 등록 완료 후 카카오 로그인 활성화
                      // _buildSocialLoginButton(
                      //   icon: _buildKakaoIcon(),
                      //   label: l10n.login_kakao,
                      //   onTap: _handleKakaoLogin,
                      //   isLoading: _isKakaoLoading,
                      // ),
                      // const SizedBox(height: 16),
                      _buildSocialLoginButton(
                        icon: _buildGoogleIcon(),
                        label: l10n.login_google,
                        onTap: _handleGoogleLogin,
                        isLoading: _isGoogleLoading,
                      ),
                      const SizedBox(height: 16),
                      _buildSocialLoginButton(
                        icon: _buildAppleIcon(),
                        label: l10n.login_apple,
                        onTap: _handleAppleLogin,
                        isLoading: _isAppleLoading,
                      ),
                      const SizedBox(height: 32),
                      // Primary Login Button
                      _buildPrimaryLoginButton(l10n),
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

  Widget _buildPrimaryLoginButton(AppLocalizations l10n) {
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
        child: Center(
          child: Text(
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
}
