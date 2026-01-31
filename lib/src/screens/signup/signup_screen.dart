import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../services/api/token_service.dart';

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
        title: const Text(
          '가입하기',
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 43),
                        // 이름 필드
                        _buildInputField(
                          label: '이름',
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          hintText: '이름을 입력해 주세요',
                          iconPath: _personIconPath,
                          hasFocus: _nameHasFocus,
                          hasValue: _nameHasValue,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '이름을 입력해 주세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        // 이메일 필드
                        _buildInputField(
                          label: '이메일',
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          hintText: '이메일을 입력해 주세요',
                          iconPath: _emailIconPath,
                          hasFocus: _emailHasFocus,
                          hasValue: _emailHasValue,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '이메일을 입력해 주세요';
                            }
                            final emailRegex = RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return '올바른 이메일 형식을 입력해 주세요';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 30),
                        // 비밀번호 필드
                        _buildInputField(
                          label: '비밀번호',
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          hintText: '비밀번호를 입력해 주세요',
                          iconPath: _lockIconPath,
                          hasFocus: _passwordHasFocus,
                          hasValue: _passwordHasValue,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '비밀번호를 입력해 주세요';
                            }
                            if (value.length < 8) {
                              return '비밀번호는 8자 이상이어야 합니다';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
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
                  const Text(
                    '이미 계정이 있으신가요?',
                    style: TextStyle(
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
                    child: const Text(
                      '로그인',
                      style: TextStyle(
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
    return GestureDetector(
      onTap: _isLoading ? null : _handleSignup,
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
                  '회원가입',
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

  /// 회원가입 성공 후 소셜 계정 연동 안내 다이얼로그
  void _showSocialLinkDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '회원가입 완료',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: const Text(
          '회원가입이 완료되었습니다!\n로그인 후 서비스를 이용할 수 있습니다.',
          style: TextStyle(
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
            child: const Text(
              '나중에 하기',
              style: TextStyle(
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
            child: const Text(
              '확인',
              style: TextStyle(
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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      // 유효성 검사 실패 시 에러 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('입력 정보를 확인해 주세요')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('예상치 못한 오류가 발생했습니다. 다시 시도해 주세요.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
