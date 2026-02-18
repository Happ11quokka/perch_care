import 'package:flutter/material.dart';

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
class CoachMarkOverlay {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required List<CoachMarkStep> steps,
    required String nextLabel,
    required String gotItLabel,
    required String skipLabel,
    ScrollController? scrollController,
    VoidCallback? onComplete,
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _CoachMarkWidget(
        steps: steps,
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
  }

  static void dismiss() {
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    // initState에서는 MediaQuery 사용 불가 → 첫 프레임 이후 실행
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTargetAndShow(0);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
                color: const Color(0x80000000),
              ),

            // 배경 탭으로 다음 단계
            Positioned.fill(
              child: GestureDetector(
                onTap: _nextStep,
                behavior: HitTestBehavior.translucent,
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
                  colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
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
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xCCFFFFFF),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 제목
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
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
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xE6FFFFFF),
                      letterSpacing: -0.35,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 버튼 행
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: _animateOut,
                        child: Text(
                          widget.skipLabel,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0x99FFFFFF),
                            letterSpacing: -0.35,
                          ),
                        ),
                      ),
                      GestureDetector(
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
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFF9A42),
                              letterSpacing: -0.35,
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

    canvas.drawPath(path, Paint()..color = const Color(0x80000000));
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
      ..color = const Color(0xFFFF9A42)
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
