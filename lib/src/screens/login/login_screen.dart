import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../router/route_paths.dart';
import '../../services/auth/auth_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 로그인 화면 - Figma 디자인 기반
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final AuthService _authService = AuthService.instance;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  bool _hasNavigatedAfterLogin = false;

  Future<void> _navigateAfterLogin() async {
    if (!mounted || _hasNavigatedAfterLogin) return;
    _hasNavigatedAfterLogin = true;

    // 펫 유무 확인 — 확정 false일 때만 onboarding. null(확인 실패)은 home으로 안전하게 보낸다.
    final hasPets = await _authService.hasPets();
    if (!mounted) return;

    if (hasPets == false) {
      context.goNamed(RouteNames.profileSetup);
    } else {
      context.goNamed(RouteNames.home);
    }
  }

  /// 소셜 로그인 결과 처리
  Future<void> _handleSocialLoginResult(SocialLoginResult result) async {
    if (result.success) {
      await _navigateAfterLogin();
    } else if (result.signupRequired) {
      final l10n = AppLocalizations.of(context);
      AppSnackBar.error(context, message: l10n.error_socialAccountConflict);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    final l10n = AppLocalizations.of(context);
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
    final l10n = AppLocalizations.of(context);
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
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.nearBlack,
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
                      _buildSocialLoginButton(
                        icon: _buildGoogleIcon(),
                        label: l10n.login_google,
                        onTap: _handleGoogleLogin,
                        isLoading: _isGoogleLoading,
                      ),
                      const SizedBox(height: 12),
                      _buildSocialLoginButton(
                        icon: SvgPicture.asset(
                          'assets/images/btn_apple/btn_apple.svg',
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: l10n.login_apple,
                        onTap: _handleAppleLogin,
                        isLoading: _isAppleLoading,
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        borderColor: Colors.black,
                      ),
                      const SizedBox(height: 12),
                      _buildSocialLoginButton(
                        icon: const Icon(
                          Icons.email_outlined,
                          size: 20,
                          color: AppColors.brandDark,
                        ),
                        label: l10n.login_email,
                        onTap: () => context.pushNamed(RouteNames.emailLogin),
                        isLoading: false,
                        borderColor: AppColors.brandPrimary,
                        textColor: AppColors.brandDark,
                      ),
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
    );
  }

  Widget _buildSocialLoginButton({
    required Widget icon,
    required String label,
    required VoidCallback onTap,
    required bool isLoading,
    Color backgroundColor = Colors.white,
    Color textColor = const Color(0xFF1F1F1F),
    Color borderColor = const Color(0xFF747775),
  }) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                AppLoading.button()
              else
                icon,
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return SvgPicture.asset(
      'assets/images/btn_google/btn_google.svg',
      width: 20,
      height: 20,
    );
  }
}
