import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/colors.dart';
import '../theme/durations.dart';
import 'pressable_scale.dart';

/// 코치마크 단계 데이터
class CoachMarkStep {
  final GlobalKey targetKey;
  final String title;
  final String body;
  final bool isScrollable; // false면 스크롤 안 함 (하단 네비 등 고정 요소)

  const CoachMarkStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.isScrollable = true,
  });
}

/// 코치마크 오버레이 관리자
///
/// 오버레이는 루트 [Overlay]에 전체 화면 배리어로 삽입되므로, 호출한 화면이
/// 실제로 보이는 상태인지 반드시 확인한다. StatefulShellRoute 탭은 비활성 상태에서도
/// 위젯이 살아 있어(`mounted == true`) 지연 콜백이 그대로 실행되기 때문에,
/// [show]는 [isContextVisible]로 가시성을 검사하고 라우트가 바뀌면 스스로 닫힌다.
class CoachMarkOverlay {
  static OverlayEntry? _currentEntry;
  static Listenable? _routeListenable;
  static VoidCallback? _routeListener;

  /// 현재 코치마크가 떠 있는지.
  static bool get isShowing => _currentEntry != null;

  /// [context]가 속한 화면이 지금 사용자에게 보이는지 판단한다.
  ///
  /// 1. 같은 Navigator 안에서 다른 route(푸시된 화면/다이얼로그)에 덮여 있으면 false
  /// 2. go_router 사용 시, 이 화면이 매칭된 경로가 현재 라우터 위치와 다르면 false
  ///    (StatefulShellRoute의 비활성 탭 — 위젯은 살아 있지만 화면에는 없음)
  /// 3. 프레임워크 신호: 비활성 브랜치·불투명 route 아래 서브트리는 [TickerMode]가 꺼진다
  static bool isContextVisible(BuildContext context) {
    if (!context.mounted) return false;

    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      String? matched;
      try {
        matched = GoRouterState.of(context).matchedLocation;
      } catch (_) {
        // go_router 페이지 밖의 context(예: 테스트의 일반 MaterialPageRoute)
        matched = null;
      }
      if (matched != null) {
        final current = router.routerDelegate.currentConfiguration.uri.path;
        if (current != matched && !current.startsWith('$matched/')) {
          return false;
        }
      }
    }

    if (!TickerMode.valuesOf(context).enabled) return false;
    return true;
  }

  /// 코치마크를 표시한다. [context]의 화면이 보이지 않으면(비활성 탭·덮인 route)
  /// 아무것도 하지 않고 [onComplete]도 호출하지 않는다 — 다음 진입 시 다시 시도된다.
  static void show(
    BuildContext context, {
    required List<CoachMarkStep> steps,
    required String nextLabel,
    required String gotItLabel,
    required String skipLabel,
    ScrollController? scrollController,
    VoidCallback? onComplete,
  }) {
    if (!isContextVisible(context)) return;

    // 타겟이 위젯 트리에 없는 단계 필터링
    final validSteps =
        steps.where((s) => s.targetKey.currentContext != null).toList();
    if (validSteps.isEmpty) {
      onComplete?.call();
      return;
    }

    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _CoachMarkWidget(
        steps: validSteps,
        nextLabel: nextLabel,
        gotItLabel: gotItLabel,
        skipLabel: skipLabel,
        scrollController: scrollController,
        onDismiss: () {
          dismiss();
          onComplete?.call();
        },
      ),
    );
    _currentEntry = entry;
    overlay.insert(entry);
    _watchRouteChanges(context, entry);
  }

  /// 라우트/탭이 바뀌어 호출 화면이 더 이상 보이지 않으면 배리어를 즉시 걷어낸다.
  /// 화면을 떠난 것이므로 [onComplete](markSeen)는 호출하지 않는다.
  static void _watchRouteChanges(BuildContext origin, OverlayEntry entry) {
    final router = GoRouter.maybeOf(origin);
    if (router == null) return;
    final listenable = router.routerDelegate;
    void listener() {
      // 새 위치가 프레임에 반영된 뒤(isCurrent/TickerMode 갱신) 판정한다.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_currentEntry != entry) return;
        if (!isContextVisible(origin)) dismiss();
      });
    }

    listenable.addListener(listener);
    _routeListenable = listenable;
    _routeListener = listener;
  }

  static void dismiss() {
    final listenable = _routeListenable;
    final listener = _routeListener;
    if (listenable != null && listener != null) {
      listenable.removeListener(listener);
    }
    _routeListenable = null;
    _routeListener = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _CoachMarkWidget extends StatefulWidget {
  final List<CoachMarkStep> steps;
  final String nextLabel;
  final String gotItLabel;
  final String skipLabel;
  final ScrollController? scrollController;
  final VoidCallback onDismiss;

  const _CoachMarkWidget({
    required this.steps,
    required this.nextLabel,
    required this.gotItLabel,
    required this.skipLabel,
    this.scrollController,
    required this.onDismiss,
  });

  @override
  State<_CoachMarkWidget> createState() => _CoachMarkWidgetState();
}

class _CoachMarkWidgetState extends State<_CoachMarkWidget>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  bool _isScrolling = false;
  bool _scrollDirty = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppDurations.coachMarkTransition,
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    // 스크롤 변경 시 spotlight 위치 동기화
    widget.scrollController?.addListener(_onScroll);

    // initState에서는 MediaQuery 사용 불가 → 첫 프레임 이후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTargetAndShow(0);
    });
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// 스크롤 시 spotlight/tooltip 위치를 타겟에 맞게 갱신 (프레임당 1회 제한)
  void _onScroll() {
    if (!_isScrolling && mounted && !_scrollDirty) {
      _scrollDirty = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
          _scrollDirty = false;
        }
      });
    }
  }

  /// 타겟 위젯이 화면에 보이도록 스크롤 후 fade-in
  Future<void> _scrollToTargetAndShow(int stepIndex) async {
    if (!mounted) return;

    final step = widget.steps[stepIndex];
    final sc = widget.scrollController;

    // 고정 요소(하단 네비 등)는 스크롤 불필요
    if (step.isScrollable && sc != null && sc.hasClients) {
      final targetRect = _getTargetRect(step.targetKey);
      if (targetRect != null) {
        final screenHeight = MediaQuery.of(context).size.height;
        final safeTop = MediaQuery.of(context).padding.top + 160; // 헤더 높이
        const tooltipSpace = 230.0; // 툴팁(~210) + gap(8) + 여유

        // 타겟 + 툴팁이 화면에 들어오는지 확인
        final needsScroll = targetRect.top < safeTop ||
            targetRect.bottom + tooltipSpace > screenHeight ||
            targetRect.top - tooltipSpace < safeTop;

        if (needsScroll) {
          _isScrolling = true;
          final currentOffset = sc.offset;

          // 타겟 상단이 화면 상단 1/3 지점에 오도록 (아래에 툴팁 공간 확보)
          final desiredTargetTop = screenHeight * 0.3;
          final delta = targetRect.top - desiredTargetTop;
          final newOffset = (currentOffset + delta).clamp(
            sc.position.minScrollExtent,
            sc.position.maxScrollExtent,
          );

          await sc.animateTo(
            newOffset,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );

          _isScrolling = false;

          // 스크롤 후 레이아웃 안정화 대기
          await Future.delayed(const Duration(milliseconds: 100));
          if (!mounted) return;
        }
      }
    }

    // targetRect가 null이면 한 프레임 대기 후 재시도 (네비바 키 등)
    if (_getTargetRect(step.targetKey) == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }

    // fade-in
    if (mounted) {
      setState(() {}); // rebuild with new target position
      _controller.forward();
    }
  }

  void _nextStep() {
    if (_isScrolling) return; // 스크롤 중 탭 무시

    if (_currentStep < widget.steps.length - 1) {
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() => _currentStep++);
          _scrollToTargetAndShow(_currentStep);
        }
      });
    } else {
      _animateOut();
    }
  }

  void _animateOut() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  Rect? _getTargetRect(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final offset = renderObject.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        offset.dx,
        offset.dy,
        renderObject.size.width,
        renderObject.size.height,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final targetRect = _getTargetRect(step.targetKey);
    final screenSize = MediaQuery.of(context).size;
    final isLastStep = _currentStep == widget.steps.length - 1;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // 반투명 배경 + spotlight
            if (targetRect != null)
              CustomPaint(
                size: screenSize,
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  padding: 8,
                  borderRadius: 16,
                ),
              )
            else
              Container(
                width: screenSize.width,
                height: screenSize.height,
                color: AppColors.overlay50,
              ),

            // 배경 탭으로 다음 단계
            Positioned.fill(
              child: Semantics(
                button: true,
                label: 'Next',
                child: GestureDetector(
                  onTap: _nextStep,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
            ),

            // 툴팁
            if (targetRect != null)
              _buildTooltip(context, step, targetRect, screenSize, isLastStep),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(
    BuildContext context,
    CoachMarkStep step,
    Rect targetRect,
    Size screenSize,
    bool isLastStep,
  ) {
    const tooltipMaxWidth = 300.0;
    const arrowSize = 10.0;
    const margin = 16.0;
    const gap = 8.0;
    const estimatedTooltipHeight = 210.0;

    // 툴팁 수평 위치: 타겟 중앙 기준
    double left = targetRect.center.dx - tooltipMaxWidth / 2;
    if (left < margin) left = margin;
    if (left + tooltipMaxWidth > screenSize.width - margin) {
      left = screenSize.width - margin - tooltipMaxWidth;
    }

    // 툴팁 수직 위치: 자동 결정 (아래 공간 충분하면 below, 아니면 above)
    const fullTooltipHeight = 220.0; // body(~190) + arrow(10) + 여유(20)
    final spaceBelow = screenSize.height - targetRect.bottom - gap - arrowSize;
    final bool showBelow = spaceBelow >= estimatedTooltipHeight;

    // 항상 top 사용 (bottom은 오버레이 좌표계 불일치 가능)
    double tooltipTop;
    if (showBelow) {
      tooltipTop = targetRect.bottom + gap;
    } else {
      tooltipTop = targetRect.top - gap - fullTooltipHeight;
      if (tooltipTop < 0) tooltipTop = 0; // 화면 상단 보호
    }

    // 화살표 수평 위치 (타겟 중앙 기준)
    final double arrowLeft = targetRect.center.dx - left - arrowSize;

    return Positioned(
      left: left,
      top: tooltipTop,
      child: SizedBox(
        width: tooltipMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 위쪽 화살표 (below 모드)
            if (showBelow)
              Padding(
                padding: EdgeInsets.only(left: arrowLeft.clamp(16, tooltipMaxWidth - 32)),
                child: CustomPaint(
                  size: const Size(20, arrowSize),
                  painter: _ArrowPainter(isUp: true),
                ),
              ),

            // 툴팁 본체
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.brandPrimary, AppColors.brandDark],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.overlay30,
                    offset: Offset(0, 4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 단계 표시
                  Text(
                    '${_currentStep + 1}/${widget.steps.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.overlayWhite80,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 제목
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 본문
                  Text(
                    step.body,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: AppColors.overlayWhite90,
                      letterSpacing: -0.35,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 버튼 행
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Semantics(
                        button: true,
                        label: widget.skipLabel,
                        child: PressableScale(
                          onTap: _animateOut,
                          child: Text(
                            widget.skipLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppColors.overlayWhite60,
                              letterSpacing: -0.35,
                            ),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: isLastStep ? widget.gotItLabel : widget.nextLabel,
                        child: PressableScale(
                          onTap: _nextStep,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              isLastStep ? widget.gotItLabel : widget.nextLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.brandPrimary,
                                letterSpacing: -0.35,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 아래쪽 화살표 (above 모드)
            if (!showBelow)
              Padding(
                padding: EdgeInsets.only(left: arrowLeft.clamp(16, tooltipMaxWidth - 32)),
                child: CustomPaint(
                  size: const Size(20, arrowSize),
                  painter: _ArrowPainter(isUp: false),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// spotlight 구멍이 뚫린 반투명 배경
class _SpotlightPainter extends CustomPainter {
  final Rect targetRect;
  final double padding;
  final double borderRadius;

  _SpotlightPainter({
    required this.targetRect,
    this.padding = 8,
    this.borderRadius = 16,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final spotlightRect = targetRect.inflate(padding);

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(RRect.fromRectAndRadius(
        spotlightRect,
        Radius.circular(borderRadius),
      ));
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = AppColors.overlay50);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return targetRect != oldDelegate.targetRect;
  }
}

/// 툴팁 화살표
class _ArrowPainter extends CustomPainter {
  final bool isUp;

  _ArrowPainter({required this.isUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.brandPrimary
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return isUp != oldDelegate.isUp;
  }
}
