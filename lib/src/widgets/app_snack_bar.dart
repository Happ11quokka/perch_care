import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../theme/radius.dart';
import '../theme/spacing.dart';

/// 스낵바 유형 정의
enum SnackBarType {
  success,
  error,
  warning,
  info,
}

/// 앱 전체에서 사용하는 커스텀 스낵바
///
/// 사용법:
/// ```dart
/// AppSnackBar.show(context, message: '저장되었습니다!', type: SnackBarType.success);
/// AppSnackBar.show(context, message: '오류가 발생했습니다.', type: SnackBarType.error);
/// ```
class AppSnackBar {
  AppSnackBar._();

  static OverlayEntry? _currentEntry;

  /// 스낵바 표시
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // 기존 스낵바가 있으면 즉시 제거
    _dismiss();

    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _SnackBarOverlay(
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          _dismiss();
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  /// 성공 스낵바 표시
  static void success(BuildContext context, {required String message}) {
    show(context, message: message, type: SnackBarType.success);
  }

  /// 에러 스낵바 표시
  static void error(BuildContext context, {required String message}) {
    show(context, message: message, type: SnackBarType.error);
  }

  /// 경고 스낵바 표시
  static void warning(BuildContext context, {required String message}) {
    show(context, message: message, type: SnackBarType.warning);
  }

  /// 정보 스낵바 표시
  static void info(BuildContext context, {required String message}) {
    show(context, message: message, type: SnackBarType.info);
  }

  static void _dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _SnackBarOverlay extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SnackBarOverlay({
    required this.message,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_SnackBarOverlay> createState() => _SnackBarOverlayState();
}

class _SnackBarOverlayState extends State<_SnackBarOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // 자동 사라짐
    Future.delayed(widget.duration, () {
      if (mounted) {
        _animateOut();
      }
    });
  }

  void _animateOut() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(widget.type);
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < 0) {
                _animateOut();
              }
            },
            child: Container(
              padding: EdgeInsets.only(top: topPadding + AppSpacing.sm),
              decoration: BoxDecoration(
                color: config.backgroundColor,
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(0, 4),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Row(
                    children: [
                      // 아이콘
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: config.iconBackgroundColor,
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Icon(
                          config.icon,
                          color: config.iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // 메시지
                      Expanded(
                        child: Text(
                          widget.message,
                          style: AppTypography.bodyMedium.copyWith(
                            color: config.textColor,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // 닫기 버튼
                      GestureDetector(
                        onTap: _animateOut,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.close_rounded,
                            color: config.closeColor,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _SnackBarConfig _getConfig(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        return _SnackBarConfig(
          backgroundColor: const Color(0xFFE8F5E9),
          iconBackgroundColor: const Color(0xFF4CAF50),
          iconColor: AppColors.white,
          textColor: const Color(0xFF1B5E20),
          closeColor: const Color(0xFF388E3C),
          icon: Icons.check_circle_rounded,
        );
      case SnackBarType.error:
        return _SnackBarConfig(
          backgroundColor: const Color(0xFFFFEBEE),
          iconBackgroundColor: AppColors.error,
          iconColor: AppColors.white,
          textColor: const Color(0xFFB71C1C),
          closeColor: const Color(0xFFC62828),
          icon: Icons.error_rounded,
        );
      case SnackBarType.warning:
        return _SnackBarConfig(
          backgroundColor: const Color(0xFFFFF3E0),
          iconBackgroundColor: AppColors.brandPrimary,
          iconColor: AppColors.white,
          textColor: const Color(0xFFE65100),
          closeColor: const Color(0xFFF57C00),
          icon: Icons.warning_rounded,
        );
      case SnackBarType.info:
        return _SnackBarConfig(
          backgroundColor: const Color(0xFFE3F2FD),
          iconBackgroundColor: const Color(0xFF1976D2),
          iconColor: AppColors.white,
          textColor: const Color(0xFF0D47A1),
          closeColor: const Color(0xFF1565C0),
          icon: Icons.info_rounded,
        );
    }
  }
}

class _SnackBarConfig {
  final Color backgroundColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color textColor;
  final Color closeColor;
  final IconData icon;

  const _SnackBarConfig({
    required this.backgroundColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.closeColor,
    required this.icon,
  });
}
