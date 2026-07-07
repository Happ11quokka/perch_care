import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../theme/durations.dart';
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
  static GlobalKey<_SnackBarOverlayState>? _currentKey;

  /// 스낵바 표시
  static void show(
    BuildContext context, {
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = AppDurations.snackBarDisplay,
  }) {
    _emitHaptic(type);

    // 기존 스낵바가 있으면 애니메이션으로 내보낸다(즉시 제거 대신).
    // 새 스낵바는 곧바로 삽입되어 이전 것이 위로 빠지는 동안 아래로 내려온다.
    final previousState = _currentKey?.currentState;
    if (previousState != null) {
      previousState.animateOut();
    } else {
      _dismiss();
    }

    // rootOverlay: 탭(브랜치) Navigator의 Overlay가 아니라 앱 루트 Overlay에 삽입.
    // 탭 전환 시 TickerMode 음소거로 exit 애니메이션이 멈춰 스낵바가 잔류하는 것을 방지.
    final overlay = Overlay.of(context, rootOverlay: true);
    final key = GlobalKey<_SnackBarOverlayState>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _SnackBarOverlay(
        key: key,
        message: message,
        type: type,
        duration: duration,
        onDismiss: () {
          // 자신의 entry만 제거 — 그 사이 다른 스낵바가 떠 있어도 안전.
          entry.remove();
          if (_currentEntry == entry) {
            _currentEntry = null;
            _currentKey = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    _currentKey = key;
    overlay.insert(entry);
  }

  static void _emitHaptic(SnackBarType type) {
    switch (type) {
      case SnackBarType.success:
        HapticFeedback.lightImpact();
      case SnackBarType.error:
        HapticFeedback.heavyImpact();
      case SnackBarType.warning:
        HapticFeedback.mediumImpact();
      case SnackBarType.info:
        break;
    }
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
    _currentKey = null;
  }
}

class _SnackBarOverlay extends StatefulWidget {
  final String message;
  final SnackBarType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _SnackBarOverlay({
    super.key,
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
      duration: AppDurations.snackBarEnter,
      reverseDuration: AppDurations.snackBarExit,
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
        animateOut();
      }
    });
  }

  void animateOut() {
    if (!mounted || _controller.status == AnimationStatus.reverse) return;
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
          child: Semantics(
            label: widget.message,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  animateOut();
                }
              },
              child: Padding(
                padding: EdgeInsets.only(
                  top: topPadding + AppSpacing.sm,
                  left: AppSpacing.lg,
                  right: AppSpacing.lg,
                ),
                child: Container(
                decoration: BoxDecoration(
                  color: config.backgroundColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowLight,
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
                        Semantics(
                          button: true,
                          label: 'Close',
                          child: GestureDetector(
                            onTap: animateOut,
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
                        ),
                      ],
                    ),
                  ),
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
          backgroundColor: AppColors.brandLight,
          iconBackgroundColor: AppColors.brandPrimary,
          iconColor: AppColors.white,
          textColor: AppColors.nearBlack,
          closeColor: AppColors.brandDark,
          icon: Icons.check_circle_rounded,
        );
      case SnackBarType.error:
        return _SnackBarConfig(
          backgroundColor: AppColors.dangerLight,
          iconBackgroundColor: AppColors.error,
          iconColor: AppColors.white,
          textColor: AppColors.dangerDarker,
          closeColor: AppColors.dangerDeep,
          icon: Icons.error_rounded,
        );
      case SnackBarType.warning:
        return _SnackBarConfig(
          backgroundColor: AppColors.brandLighter,
          iconBackgroundColor: AppColors.brandPrimary,
          iconColor: AppColors.white,
          textColor: AppColors.warningDeep,
          closeColor: AppColors.warningDark,
          icon: Icons.warning_rounded,
        );
      case SnackBarType.info:
        return _SnackBarConfig(
          backgroundColor: AppColors.infoLight,
          iconBackgroundColor: AppColors.infoDark,
          iconColor: AppColors.white,
          textColor: AppColors.infoDarker,
          closeColor: AppColors.infoDeep,
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
