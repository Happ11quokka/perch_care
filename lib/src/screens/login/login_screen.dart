import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';

/// 로그인 화면
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const double _designWidth = 393.0;
  static const double _designHeight = 852.0;

  // 바텀시트 높이 상태
  double _sheetHeight = 60.0; // 초기에는 살짝만 보임
  final double _peekHeight = 60.0; // 살짝 보이는 높이
  final double _expandedHeight = 428.0; // 완전히 확장된 높이

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          // 배경 원형들
          _buildBackgroundCircles(),

          // 중앙 그라데이션 원
          _buildGradientCircle(),

          // 메인 콘텐츠 (새, 나무, 브랜드명, 슬로건)
          _buildMainContent(),

          // 하단 바텀시트 영역
          _buildBottomSheet(),

          // 상단 상태바 영역
          _buildStatusBar(),
        ],
      ),
    );
  }

  /// 배경 원형들 (3개의 큰 원)
  Widget _buildBackgroundCircles() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenSize.height;

    final double circleCenterX = w(200);

    final double largeRingSize = w(622);
    final double largeRingCenterY = h(272);
    final double largeRingLeft = circleCenterX - (largeRingSize / 2);
    final double largeRingTop = largeRingCenterY - (largeRingSize / 2);

    final double outerRingSize = w(439);
    final double outerRingCenterY = h(265.5);
    final double outerRingLeft = circleCenterX - (outerRingSize / 2);
    final double outerRingTop = outerRingCenterY - (outerRingSize / 2);

    final double middleRingSize = w(268);
    final double middleRingCenterY = h(254);
    final double middleRingLeft = circleCenterX - (middleRingSize / 2);
    final double middleRingTop = middleRingCenterY - (middleRingSize / 2);

    return Stack(
      children: [
        // 가장 큰 링 (Ellipse 120)
        Positioned(
          left: largeRingLeft,
          top: largeRingTop,
          child: SvgPicture.asset(
            'assets/images/login_vector/Ellipse_120.svg',
            width: largeRingSize,
            height: largeRingSize,
            fit: BoxFit.contain,
          ),
        ),

        // 맨 외부 원환 (Ellipse 69)
        Positioned(
          left: outerRingLeft,
          top: outerRingTop,
          child: SvgPicture.asset(
            'assets/images/login_vector/Ellipse_69.svg',
            width: outerRingSize,
            height: outerRingSize,
            fit: BoxFit.contain,
          ),
        ),

        // 중간 원환 (Ellipse 68)
        Positioned(
          left: middleRingLeft,
          top: middleRingTop,
          child: SvgPicture.asset(
            'assets/images/login_vector/Ellipse_68.svg',
            width: middleRingSize,
            height: middleRingSize,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  /// 중앙 그라데이션 원
  Widget _buildGradientCircle() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenSize.height;

    final double circleCenterX = w(200);

    final double gradientCircleSize = w(242);
    final double gradientCircleCenterY = h(254);
    final double gradientCircleLeft = circleCenterX - (gradientCircleSize / 2);
    final double gradientCircleTop =
        gradientCircleCenterY - (gradientCircleSize / 2);

    return Positioned(
      left: gradientCircleLeft,
      top: gradientCircleTop,
      child: SvgPicture.asset(
        'assets/images/login_vector/Ellipse_114.svg',
        width: gradientCircleSize,
        height: gradientCircleSize,
        fit: BoxFit.contain,
      ),
    );
  }

  /// 메인 콘텐츠 (새, 나무, 브랜드명, 슬로건)
  Widget _buildMainContent() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenSize.height;

    // 시안 좌표를 기반으로 주요 요소의 크기와 위치 계산
    final birdWidth = w(263);
    final birdHeight = birdWidth * (224.0 / 263.0);
    final birdLeft = w(133);
    final birdTop = h(157);

    final treeWidth = w(487);
    final treeLeft = w(-58);
    final treeTop = birdTop + (birdHeight * 0.54);

    final brandLogoWidth = w(230);
    final brandLogoLeft = (screenWidth - brandLogoWidth) / 2;
    final brandLogoTop = h(573);

    final sloganWidth = w(257);
    final sloganLeft = (screenWidth - sloganWidth) / 2;
    final sloganTop = h(618);

    final arrowTop = h(720);

    return Positioned.fill(
      child: Stack(
        children: [
          // 새 이미지 (꼬리까지 전체)
          Positioned(
            left: birdLeft,
            top: birdTop,
            child: SvgPicture.asset(
              'assets/images/login_bird.svg',
              width: birdWidth,
              height: birdHeight,
            ),
          ),

          // 나무 이미지
          Positioned(
            left: treeLeft,
            top: treeTop,
            child: SvgPicture.asset('assets/images/tree.svg', width: treeWidth),
          ),

          // 브랜드명 (p.e.r.c.h)
          Positioned(
            left: brandLogoLeft,
            top: brandLogoTop,
            child: SvgPicture.asset(
              'assets/images/p.e.r.c.h.svg',
              width: brandLogoWidth,
            ),
          ),

          // 슬로건
          Positioned(
            left: sloganLeft,
            top: sloganTop,
            child: Image.asset(
              'assets/images/slogan.png',
              width: sloganWidth,
              height: sloganWidth * (22.0 / 257.0),
            ),
          ),
          // 하단 화살표 (업 인디케이터)
          Positioned(
            left: 0,
            right: 0,
            top: arrowTop,
            child: Center(
              child: Icon(
                Icons.keyboard_arrow_up,
                color: AppColors.brandPrimary.withOpacity(0.5),
                size: 48,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 하단 바텀시트 영역
  Widget _buildBottomSheet() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          setState(() {
            // 위로 드래그 (음수) = 시트 확장
            _sheetHeight -= details.delta.dy;
            // 최소/최대 높이 제한
            _sheetHeight = _sheetHeight.clamp(_peekHeight, _expandedHeight);
          });
        },
        onVerticalDragEnd: (details) {
          // 드래그 속도에 따라 자동으로 접기/펼치기
          setState(() {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -500) {
                // 빠르게 위로 드래그 = 완전히 펼치기
                _sheetHeight = _expandedHeight;
              } else if (details.primaryVelocity! > 500) {
                // 빠르게 아래로 드래그 = 완전히 접기
                _sheetHeight = _peekHeight;
              } else {
                // 중간 지점 기준으로 펼치기/접기
                final midPoint = (_peekHeight + _expandedHeight) / 2;
                _sheetHeight = _sheetHeight > midPoint
                    ? _expandedHeight
                    : _peekHeight;
              }
            }
          });
        },
        onTap: () {
          // 탭하면 펼치기/접기 토글
          setState(() {
            _sheetHeight = _sheetHeight == _peekHeight
                ? _expandedHeight
                : _peekHeight;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: _sheetHeight,
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),

              // 드래그 핸들
              Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFA4A4A4),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),

              const SizedBox(height: 20),

              // 여기에 로그인 버튼 등 추가 가능
              if (_sheetHeight > 100) // 시트가 펼쳐졌을 때만 보이기
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    child: _buildLoginSheetContent(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 상단 상태바 영역
  Widget _buildStatusBar() {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Container(
        height: 44,
        color: AppColors.white,
        child: const SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Text(
                  '9:41',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.50,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 하단 시트 로그인 콘텐츠
  Widget _buildLoginSheetContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 4),
        const Text(
          '만나서 반가워요!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        const Text(
          '단순한 기록을 넘어, AI 분석으로\n앵무새의 상태를 더 깊이 이해해 보세요.',
          style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.gray600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: 311,
          child: _buildGradientButton(
            label: '로그인',
            onPressed: () {
              // TODO: 로그인 액션 연결
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '아직 회원이 아니신가요? ',
              style: TextStyle(fontSize: 14, color: AppColors.gray600),
            ),
            TextButton(
              onPressed: () {
                context.pushNamed(RouteNames.signup);
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '회원가입',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          '또는',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.gray500,
          ),
        ),
        const SizedBox(height: 16),
        _buildSocialLoginButtons(),
      ],
    );
  }

  /// 공통 그라데이션 버튼
  Widget _buildGradientButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    final borderRadius = BorderRadius.circular(12);
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      elevation: 0,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: Ink(
          decoration: ShapeDecoration(
            gradient: const LinearGradient(
              begin: Alignment(0.00, 0.50),
              end: Alignment(1.00, 0.50),
              colors: [Color(0xFFFF9A42), Color(0xFFFF7B29)],
            ),
            shape: RoundedRectangleBorder(borderRadius: borderRadius),
            shadows: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 4,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: SizedBox(
            height: 50,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// SNS 로그인 버튼 모음
  Widget _buildSocialLoginButtons() {
    final socialButtons = <_SocialLoginButtonData>[
      _SocialLoginButtonData(
        assetPath: 'assets/images/btn_google/btn_google.svg',
        semanticLabel: 'Google로 로그인',
        onTap: () {
          // TODO: 구글 로그인 연동
        },
      ),
      _SocialLoginButtonData(
        assetPath: 'assets/images/btn_apple/btn_apple.svg',
        semanticLabel: 'Apple로 로그인',
        onTap: () {
          // TODO: 애플 로그인 연동
        },
      ),
      _SocialLoginButtonData(
        assetPath: 'assets/images/btn_naver/btn_naver.svg',
        semanticLabel: '네이버로 로그인',
        onTap: () {
          // TODO: 네이버 로그인 연동
        },
      ),
      _SocialLoginButtonData(
        assetPath: 'assets/images/btn_kakao/btn_kakao.svg',
        semanticLabel: '카카오로 로그인',
        onTap: () {
          // TODO: 카카오 로그인 연동
        },
      ),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 18,
      runSpacing: 12,
      children: socialButtons
          .map((button) => _SocialLoginIconButton(data: button))
          .toList(growable: false),
    );
  }
}

class _SocialLoginButtonData {
  const _SocialLoginButtonData({
    required this.assetPath,
    required this.semanticLabel,
    required this.onTap,
  });

  final String assetPath;
  final String semanticLabel;
  final VoidCallback onTap;
}

class _SocialLoginIconButton extends StatelessWidget {
  const _SocialLoginIconButton({required this.data});

  final _SocialLoginButtonData data;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: data.semanticLabel,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: data.onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: SvgPicture.asset(data.assetPath, width: 28, height: 28),
            ),
          ),
        ),
      ),
    );
  }
}
