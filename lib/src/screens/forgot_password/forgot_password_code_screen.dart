import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';

/// 비밀번호 찾기 - 코드 입력 화면
class ForgotPasswordCodeScreen extends StatefulWidget {
  final String method; // 'phone' 또는 'email'
  final String destination; // 전화번호 또는 이메일

  const ForgotPasswordCodeScreen({
    super.key,
    required this.method,
    required this.destination,
  });

  @override
  State<ForgotPasswordCodeScreen> createState() =>
      _ForgotPasswordCodeScreenState();
}

class _ForgotPasswordCodeScreenState extends State<ForgotPasswordCodeScreen> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 120; // 2분
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    // 첫 번째 필드에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingSeconds = 120;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes > 0 ? '$minutes분 ' : ''}$seconds초';
  }

  bool get _isCodeComplete {
    return _controllers.every((c) => c.text.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          '코드 입력',
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
                      // 안내 문구
                      const Text(
                        '복구 코드가 귀하에게 전달되었습니다.\n전달 받은 코드를 2분안에 입력 하시길 바랍니다.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Color(0xFF97928A),
                          letterSpacing: -0.35,
                          height: 1.43,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 전송 대상 정보
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF97928A),
                            letterSpacing: -0.35,
                          ),
                          children: [
                            TextSpan(
                              text: widget.destination,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            const TextSpan(text: ' 코드를 보냈습니다.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 코드 입력 박스들
                      _buildCodeInputBoxes(),
                      const SizedBox(height: 16),
                      // 남은 시간
                      Center(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF97928A),
                              letterSpacing: -0.35,
                            ),
                            children: [
                              const TextSpan(text: '코드 입력까지 '),
                              TextSpan(
                                text: _formattedTime,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFFFF9A42),
                                ),
                              ),
                              const TextSpan(text: ' 남았습니다.'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 코드 다시 보내기 버튼
                      _buildResendButton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeInputBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final hasValue = _controllers[index].text.isNotEmpty;
        return Container(
          margin: EdgeInsets.only(right: index < 3 ? 18 : 0),
          child: SizedBox(
            width: 68,
            height: 68,
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.6,
              ),
              decoration: InputDecoration(
                counterText: '',
                filled: hasValue,
                fillColor: const Color(0xFFFF9A42).withValues(alpha: 0.1),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: hasValue
                        ? const Color(0xFFFF9A42)
                        : const Color(0xFF97928A),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFFFF9A42),
                    width: 1,
                  ),
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) {
                setState(() {});
                if (value.isNotEmpty && index < 3) {
                  _focusNodes[index + 1].requestFocus();
                }
                if (value.isEmpty && index > 0) {
                  _focusNodes[index - 1].requestFocus();
                }
                // 모든 코드 입력 완료시 자동 제출
                if (_isCodeComplete) {
                  _handleVerifyCode();
                }
              },
            ),
          ),
        );
      }),
    );
  }

  Widget _buildResendButton() {
    return GestureDetector(
      onTap: _isResending ? null : _handleResendCode,
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
          child: _isResending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  '코드 다시 보내기',
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

  void _handleVerifyCode() {
    // 코드 검증 후 다음 화면으로 이동
    // TODO: 실제 코드 검증 API 호출
    context.pushNamed(RouteNames.forgotPasswordReset);
  }

  Future<void> _handleResendCode() async {
    setState(() => _isResending = true);
    try {
      // TODO: 실제 코드 재전송 API 호출
      await Future.delayed(const Duration(seconds: 1));
      // 입력 필드 초기화
      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      // 타이머 재시작
      _startTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코드가 다시 전송되었습니다.')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }
}
