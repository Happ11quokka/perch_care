import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_names.dart';
import '../../router/route_paths.dart';
import 'dart:io';

import '../../services/api/api_client.dart';
import '../../providers/repository_providers.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 비밀번호 찾기 - 코드 입력 화면
class ForgotPasswordCodeScreen extends ConsumerStatefulWidget {
  final String method; // 'phone' 또는 'email'
  final String destination; // 전화번호 또는 이메일

  const ForgotPasswordCodeScreen({
    super.key,
    required this.method,
    required this.destination,
  });

  @override
  ConsumerState<ForgotPasswordCodeScreen> createState() =>
      _ForgotPasswordCodeScreenState();
}

class _ForgotPasswordCodeScreenState extends ConsumerState<ForgotPasswordCodeScreen>
    with SingleTickerProviderStateMixin {
  static const int _codeLength = 6;
  final List<TextEditingController> _controllers = List.generate(
    _codeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(_codeLength, (_) => FocusNode());

  Timer? _timer;
  int _remainingSeconds = 120; // 2분
  bool _isResending = false;
  bool _isVerifying = false;

  // 오입력 피드백: 흔들림 + 테두리 danger 플래시
  late final AnimationController _shakeController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _startTimer();
    // 첫 번째 필드에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
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
      if (!mounted) {
        timer.cancel();
        return;
      }
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
    final l10n = AppLocalizations.of(context);
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    if (minutes > 0) {
      return '${l10n.datetime_minutes(minutes)} ${l10n.datetime_seconds(seconds)}';
    }
    return l10n.datetime_seconds(seconds);
  }

  bool get _isCodeComplete {
    return _controllers.every((c) => c.text.isNotEmpty);
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
          onPressed: () => context.popOrGo(RoutePaths.login),
        ),
        centerTitle: true,
        title: Text(
          l10n.forgot_codeTitle,
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
                      // 안내 문구
                      Text(
                        l10n.forgot_codeDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.warmGray,
                          letterSpacing: -0.35,
                          height: 1.43,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 전송 대상 정보
                      Text(
                        l10n.forgot_codeSentTo(widget.destination),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: AppColors.warmGray,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // 코드 입력 박스들
                      _buildCodeInputBoxes(),
                      const SizedBox(height: 16),
                      // 남은 시간
                      Center(
                        child: Text(
                          l10n.forgot_timeRemaining(_formattedTime),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.warmGray,
                            letterSpacing: -0.35,
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
      ),
    );
  }

  Widget _buildCodeInputBoxes() {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        // sin(t*3π)*8 → 350ms 동안 좌우로 흔들림
        final dx = math.sin(_shakeController.value * 3 * math.pi) * 8;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      // F08: 6×52 + 5×12 = 372px 고정 폭은 좌우 32px 패딩을 뺀 326px(390px 폰)
      // 에서 넘쳤다. 사용 가능한 폭으로부터 박스/간격을 계산한다(간격 먼저 축소).
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layout = _CodeBoxLayout.fit(constraints.maxWidth);
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_codeLength, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _codeLength - 1 ? layout.gap : 0,
                ),
                child: _buildCodeBox(index, layout.boxSize),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildCodeBox(int index, double boxSize) {
    final hasValue = _controllers[index].text.isNotEmpty;
    final borderColor = _hasError
        ? AppColors.danger
        : (hasValue ? AppColors.brandPrimary : AppColors.warmGray);
    // 숫자 폰트는 박스 크기에 비례(52px 박스 = 24px). 시스템 글자 크기(최대 2.0)로
    // 확대돼도 박스 안에 머물도록 텍스트 스케일 상한을 박스 크기 기준으로 제한한다.
    final fontSize = boxSize * _CodeBoxLayout.fontRatio;
    final radius = boxSize * _CodeBoxLayout.radiusRatio;
    final maxScale = (boxSize * _CodeBoxLayout.maxGlyphRatio / fontSize)
        .clamp(1.0, 2.0)
        .toDouble();
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxScale,
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: AppColors.nearBlack,
            letterSpacing: -0.6,
          ),
          decoration: InputDecoration(
            counterText: '',
            isDense: true,
            contentPadding: EdgeInsets.zero,
            filled: _hasError || hasValue,
            fillColor: _hasError
                ? AppColors.dangerLight
                : AppColors.brandPrimary.withValues(alpha: 0.1),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(
                color: borderColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(
                color: _hasError ? AppColors.danger : AppColors.brandPrimary,
                width: 1,
              ),
            ),
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            setState(() {});
            if (value.isNotEmpty && index < _codeLength - 1) {
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
  }

  Widget _buildResendButton() {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: l10n.btn_resendCode,
      child: GestureDetector(
      onTap: _isResending ? null : _handleResendCode,
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
          child: _isResending
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  l10n.btn_resendCode,
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

  Future<void> _handleVerifyCode() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    final code = _controllers.map((c) => c.text).join();

    try {
      await ref.read(authRepositoryProvider).verifyResetCode(widget.destination, code, method: widget.method);
      if (!mounted) return;
      context.pushNamed(
        RouteNames.forgotPasswordReset,
        extra: {
          'identifier': widget.destination,
          'code': code,
          'method': widget.method,
        },
      );
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      if (e is SocketException || e is TimeoutException) {
        AppSnackBar.error(context, message: l10n.error_network);
      } else if (e is ApiException && e.statusCode >= 500) {
        AppSnackBar.error(context, message: l10n.error_server);
      } else {
        AppSnackBar.warning(context, message: l10n.error_invalidCode);
      }
      // 검증 실패 피드백: 흔들림 + 테두리 danger 플래시 (햅틱은 위 AppSnackBar가
      // 타입별로 발생시키므로 중복 호출하지 않음). clear는 인과를 위해 직후 수행.
      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      setState(() => _hasError = true);
      if (!reduceMotion) {
        _shakeController.forward(from: 0);
      }
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() => _hasError = false);
      });
      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResendCode() async {
    setState(() => _isResending = true);
    try {
      if (widget.method == 'phone') {
        await ref.read(authRepositoryProvider).resetPasswordByPhone(widget.destination);
      } else {
        await ref.read(authRepositoryProvider).resetPassword(widget.destination);
      }
      // 입력 필드 초기화
      for (final controller in _controllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      // 타이머 재시작
      _startTimer();
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.info(context, message: l10n.snackbar_codeResent);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final msg = ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.forgotPassword);
      AppSnackBar.error(context, message: msg);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }
}

/// 인증 코드 6칸의 박스 크기/간격을 사용 가능한 폭에 맞춰 계산한다.
///
/// 우선순위: 기본(52px 박스, 12px 간격) → 간격을 [minGap]까지 축소 →
/// 그래도 넘치면 박스를 축소. 박스는 [maxBoxSize]를 넘지 않아 태블릿에서
/// 과대해 보이지 않고, 항상 정사각형을 유지한다.
class _CodeBoxLayout {
  const _CodeBoxLayout({required this.boxSize, required this.gap});

  static const int count = 6;
  static const double maxBoxSize = 52;
  static const double maxGap = 12;
  static const double minGap = 6;
  static const double minBoxSize = 32;

  /// 숫자 폰트 크기 = 박스 × 비율 (52px 박스 → 24px).
  static const double fontRatio = 24 / 52;

  /// 모서리 반경 = 박스 × 비율 (52px 박스 → 16px). 작은 박스가 알약형이 되지 않도록.
  static const double radiusRatio = 16 / 52;

  /// 텍스트 스케일 적용 후 글리프가 차지할 수 있는 박스 대비 최대 비율.
  static const double maxGlyphRatio = 0.6;

  final double boxSize;
  final double gap;

  double get totalWidth => boxSize * count + gap * (count - 1);

  static _CodeBoxLayout fit(double maxWidth) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return const _CodeBoxLayout(boxSize: maxBoxSize, gap: maxGap);
    }
    final boxesWidth = maxBoxSize * count;
    // 1) 간격을 먼저 줄인다.
    final gap = ((maxWidth - boxesWidth) / (count - 1)).clamp(minGap, maxGap);
    if (boxesWidth + gap * (count - 1) <= maxWidth) {
      return _CodeBoxLayout(boxSize: maxBoxSize, gap: gap.toDouble());
    }
    // 2) 최소 간격으로도 넘치면 박스를 줄인다.
    final boxSize = ((maxWidth - minGap * (count - 1)) / count)
        .clamp(minBoxSize, maxBoxSize);
    return _CodeBoxLayout(boxSize: boxSize.toDouble(), gap: minGap);
  }
}
