import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/colors.dart';

/// 스플래시 스크린
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _innerCircleScale;
  late Animation<double> _middleCircleScale;
  late Animation<double> _outerCircleScale;
  late Animation<double> _logoOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // 중앙 원 - 가장 먼저 시작 (0.0 ~ 0.4초)
    _innerCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    // 중간 원 - 약간 지연 (0.15 ~ 0.6초)
    _middleCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.6, curve: Curves.easeOut),
      ),
    );

    // 바깥 원 - 가장 늦게 시작 (0.3 ~ 0.8초)
    _outerCircleScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    // 로고 - 원들이 확장된 후 나타남 (0.6 ~ 1.0초)
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandPrimary,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              children: [
                // 배경 원형 링들 (바깥쪽) - 애니메이션 (화면을 벗어남)
                Center(
                  child: Transform.scale(
                    scale: _outerCircleScale.value,
                    child: Opacity(
                      opacity: _outerCircleScale.value * 0.25,
                      child: SvgPicture.asset(
                        'assets/images/ellipse-67.svg',
                        width: 700,
                        height: 700,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withValues(alpha: 0.25),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),
                // 중간 원형 링 - 애니메이션
                Center(
                  child: Transform.scale(
                    scale: _middleCircleScale.value,
                    child: Opacity(
                      opacity: _middleCircleScale.value * 0.5,
                      child: SvgPicture.asset(
                        'assets/images/ellipse-67.svg',
                        width: 420,
                        height: 420,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withValues(alpha: 0.5),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                ),

                // 중앙 원형 + 브랜드 로고 - 애니메이션
                Center(
                  child: Transform.scale(
                    scale: _innerCircleScale.value,
                    child: SizedBox(
                      width: 196,
                      height: 196,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SvgPicture.asset(
                            'assets/images/ellipse-67.svg',
                            width: 196,
                            height: 196,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: SvgPicture.asset(
                              'assets/images/brand.svg',
                              width: 180,
                              height: 180,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
