import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth/auth_service.dart';

/// 로그인 화면
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  // Auth state for email login
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoginLoading = false;
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  StreamSubscription<AuthState>? _authStateSubscription;
  bool _hasNavigatedAfterLogin = false;

  static const double _designWidth = 393.0;
  static const double _designHeight = 852.0;

  static const double _treeDesignWidth = 495.0;
  static const double _treeDesignHeight = 500.0;
  static const double _treeDesignLeft = 0.0;
  static const double _treeDesignTop = 123.0;
  static const double _treeScale = 0.8;

  static const double _birdDesignWidth = 274.0;
  static const double _birdDesignHeight = 287.0;
  static const double _birdDesignLeft = 165.0;
  static const double _birdDesignTop = 166.0;

  late AnimationController _arrowAnimationController;

  @override
  void initState() {
    super.initState();
    _arrowAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _authStateSubscription =
        _authService.authStateChanges.listen(_handleAuthStateChange);
  }
  // 바텀시트 높이 상태
  double _sheetHeight = 60.0; // 초기에는 살짝만 보임
  final double _peekHeight = 60.0; // 살짝 보이는 높이
  final double _expandedHeight = 428.0; // 완전히 확장된 높이

  @override
  void dispose() {
    _arrowAnimationController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = MediaQuery.of(context).size;
          return Stack(
            children: [
              _buildBackgroundCircles(
                screenSize.width,
                screenSize.height,
              ),
              _buildGradientCircle(),
              _buildMainContent(),
              _buildBottomSheet(),
              _buildStatusBar(),
            ],
          );
        },
      ),
    );
  }

  /// 배경 원형들 (3개의 큰 원)
  Widget _buildBackgroundCircles(double screenWidth, double screenHeight) {
    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenHeight;

    final double circleCenterX = w(200);

    final double largeRingScale = 1.05;
    final double middleRingScale = 1.02;
    final double innerRingScale = 1.03;

    final double largeRingSize = w(622) * largeRingScale;
    final double largeRingCenterY = h(272);
    final double largeRingLeft =
        circleCenterX - (largeRingSize / 2) + w(80);
    final double largeRingTop = largeRingCenterY - (largeRingSize / 2);

    final double outerRingSize = w(439) * middleRingScale;
    final double outerRingCenterY = h(265.5);
    final double outerRingLeft =
        circleCenterX - (outerRingSize / 2) + w(10);
    final double outerRingTop = outerRingCenterY - (outerRingSize / 2);

    final double middleRingSize = w(268) * innerRingScale;
    final double middleRingCenterY = h(254);
    final double middleRingLeft = circleCenterX - (middleRingSize / 2);
    final double middleRingTop = middleRingCenterY - (middleRingSize / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
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

    final treeWidth = w(_treeDesignWidth) * _treeScale;
    final treeHeight = treeWidth * (_treeDesignHeight / _treeDesignWidth);
    final treeLeft = w(_treeDesignLeft);
    final treeTop = h(_treeDesignTop);

    double relX(double designX) =>
        (designX - _treeDesignLeft) / _treeDesignWidth * treeWidth;
    double relY(double designY) =>
        (designY - _treeDesignTop) / _treeDesignHeight * treeHeight;
    double relW(double designWidth) =>
        designWidth / _treeDesignWidth * treeWidth;
    double relH(double designHeight) =>
        designHeight / _treeDesignHeight * treeHeight;

    final birdWidth = relW(_birdDesignWidth);
    final birdHeight = relH(_birdDesignHeight);
    final birdOffsetLeft = relX(_birdDesignLeft);
    final birdOffsetTop = relY(_birdDesignTop);

    final leaf1173Left = relX(9); //완료
    final leaf1173Top = relY(319);
    final leaf1173Width = relW(20);
    final leaf1173Height = relH(198);

    final leaf1165Left = relX(260); //완료 - 순서 수정
    final leaf1165Top = relY(418);
    final leaf1165Width = relW(20);
    final leaf1165Height = relH(37);

    final leaf1164Left = relX(397); //완료
    final leaf1164Top = relY(445);
    final leaf1164Width = relW(20);
    final leaf1164Height = relH(26);

    final leaf1147Left = relX(31);  //완료
    final leaf1147Top = relY(263);
    final leaf1147Width = relW(20);
    final leaf1147Height = relH(53);

    final leaf1154Left = relX(26);  //완료
    final leaf1154Top = relY(365.5);
    final leaf1154Width = relW(20);
    final leaf1154Height = relH(45);

    final leaf1155Left = relX(137); //완료
    final leaf1155Top = relY(369);
    final leaf1155Width = relW(20);
    final leaf1155Height = relH(43);

    final leaf1156Left = relX(95);  //완료
    final leaf1156Top = relY(458);
    final leaf1156Width = relW(20);
    final leaf1156Height = relH(25.5);

    final leaf1157Left = relX(49);  //완료
    final leaf1157Top = relY(448);
    final leaf1157Width = relW(20);
    final leaf1157Height = relH(26);

    final leaf1158Left = relX(142); //완료
    final leaf1158Top = relY(470);
    final leaf1158Width = relW(20);
    final leaf1158Height = relH(27.5);

    final leaf1159Left = relX(133); //완료
    final leaf1159Top = relY(482);
    final leaf1159Width = relW(20);
    final leaf1159Height = relH(20);

    final leaf1160Left = relX(131); //완료
    final leaf1160Top = relY(466);
    final leaf1160Width = relW(20);
    final leaf1160Height = relH(12);

    final leaf1161Left = relX(81.5); //완료
    final leaf1161Top = relY(443);
    final leaf1161Width = relW(20);
    final leaf1161Height = relH(12);

    final leaf1162Left = relX(106); //완료
    final leaf1162Top = relY(479);
    final leaf1162Width = relW(20);
    final leaf1162Height = relH(13.5);

    final branch1114Left = relX(120); //완료
    final branch1114Top = relY(439);
    final branch1114Width = relW(20);
    final branch1114Height = relH(54);

    final branch1112Left = relX(105); //완료 - 순서 수정
    final branch1112Top = relY(284);
    final branch1112Width = relW(20);
    final branch1112Height = relH(65);

    final branch1113Left = relX(90);  //완료
    final branch1113Top = relY(310);
    final branch1113Width = relW(20);
    final branch1113Height = relH(15);

    final branch1115Left = relX(313); //완료
    final branch1115Top = relY(370);
    final branch1115Width = relW(20);
    final branch1115Height = relH(54);
    
    final branch1175Left = relX(304); //완료
    final branch1175Top = relY(381);
    final branch1175Width = relW(20);
    final branch1175Height = relH(23);

    final leaf1148Left = relX(95);  //완료
    final leaf1148Top = relY(258);
    final leaf1148Width = relW(20);
    final leaf1148Height = relH(50);

    final leaf1149Left = relX(83);  //완료
    final leaf1149Top = relY(281);
    final leaf1149Width = relW(20);
    final leaf1149Height = relH(40.5);

    final leaf1172Left = relX(110); //완료
    final leaf1172Top = relY(305);
    final leaf1172Width = relW(20);
    final leaf1172Height = relH(16.5);

    final leaf1168Left = relX(220); //완료
    final leaf1168Top = relY(378);
    final leaf1168Width = relW(20);
    final leaf1168Height = relH(50);

    final leaf1169Left = relX(270); //완료
    final leaf1169Top = relY(380);
    final leaf1169Width = relW(20);
    final leaf1169Height = relH(33);

    final leaf1170Left = relX(240); //완료
    final leaf1170Top = relY(335);
    final leaf1170Width = relW(20);
    final leaf1170Height = relH(45);

    final leaf1151Left = relX(23);  //완료
    final leaf1151Top = relY(245);
    final leaf1151Width = relW(20);
    final leaf1151Height = relH(44);

    final leaf1153Left = relX(90); //완료
    final leaf1153Top = relY(348);
    final leaf1153Width = relW(20);
    final leaf1153Height = relH(23);

    final leaf1180Left = relX(45);  //완료
    final leaf1180Top = relY(390);
    final leaf1180Width = relW(20);
    final leaf1180Height = relH(19.5);

    final leaf1171Left = relX(280); //완료
    final leaf1171Top = relY(325);
    final leaf1171Width = relW(20);
    final leaf1171Height = relH(27);

    // final leaf1152Left = relX(90); 
    // final leaf1152Top = relY(348);
    // final leaf1152Width = relW(20);
    // final leaf1152Height = relH(23);

    // final leaf1167Left = relX(45);  
    // final leaf1167Top = relY(390);
    // final leaf1167Width = relW(20);
    // final leaf1167Height = relH(19.5);


    final brandLogoWidth = w(230);
    final brandLogoLeft = (screenWidth - brandLogoWidth) / 2;
    final brandLogoTop = h(573);

    final sloganWidth = w(257)*0.9;
    final sloganLeft = (screenWidth - sloganWidth) / 2;
    final sloganTop = h(645);

    final arrowTop = h(690);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: treeLeft,
            top: treeTop,
            child: SizedBox(
              width: treeWidth,
              height: treeHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: birdOffsetLeft,
                    top: birdOffsetTop,
                    child: SvgPicture.asset(
                      'assets/images/login_bird.svg',
                      width: birdWidth,
                      height: birdHeight,
                    ),
                  ),
                  SvgPicture.asset(
                    'assets/images/tree.svg',
                    width: treeWidth,
                    height: treeHeight,
                  ),
                  Positioned(
                    left: leaf1173Left,
                    top: leaf1173Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1173.svg',
                      width: leaf1173Width,
                      height: leaf1173Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1165Left,
                    top: leaf1165Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1165.svg',
                      width: leaf1165Width,
                      height: leaf1165Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1164Left,
                    top: leaf1164Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1164.svg',
                      width: leaf1164Width,
                      height: leaf1164Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1147Left,
                    top: leaf1147Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1147.svg',
                      width: leaf1147Width,
                      height: leaf1147Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1154Left,
                    top: leaf1154Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1154.svg',
                      width: leaf1154Width,
                      height: leaf1154Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1155Left,
                    top: leaf1155Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1155.svg',
                      width: leaf1155Width,
                      height: leaf1155Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1156Left,
                    top: leaf1156Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1156.svg',
                      width: leaf1156Width,
                      height: leaf1156Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1157Left,
                    top: leaf1157Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1157.svg',
                      width: leaf1157Width,
                      height: leaf1157Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1158Left,
                    top: leaf1158Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1158.svg',
                      width: leaf1158Width,
                      height: leaf1158Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1159Left,
                    top: leaf1159Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1159.svg',
                      width: leaf1159Width,
                      height: leaf1159Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1160Left,
                    top: leaf1160Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1160.svg',
                      width: leaf1160Width,
                      height: leaf1160Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1161Left,
                    top: leaf1161Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1161.svg',
                      width: leaf1161Width,
                      height: leaf1161Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1162Left,
                    top: leaf1162Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1162.svg',
                      width: leaf1162Width,
                      height: leaf1162Height,
                    ),
                  ),
                  Positioned(
                    left: branch1114Left,
                    top: branch1114Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1114.svg',
                      width: branch1114Width,
                      height: branch1114Height,
                    ),
                  ),
                  Positioned(
                    left: branch1112Left,
                    top: branch1112Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1112.svg',
                      width: branch1112Width,
                      height: branch1112Height,
                    ),
                  ),
                  Positioned(
                    left: branch1113Left,
                    top: branch1113Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1113.svg',
                      width: branch1113Width,
                      height: branch1113Height,
                    ),
                  ),
                  Positioned(
                    left: branch1175Left,
                    top: branch1175Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1175.svg',
                      width: branch1175Width,
                      height: branch1175Height,
                    ),
                  ),
                  Positioned(
                    left: branch1115Left,
                    top: branch1115Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1115.svg',
                      width: branch1115Width,
                      height: branch1115Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1148Left,
                    top: leaf1148Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1148.svg',
                      width: leaf1148Width,
                      height: leaf1148Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1149Left,
                    top: leaf1149Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1149.svg',
                      width: leaf1149Width,
                      height: leaf1149Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1172Left,
                    top: leaf1172Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1172.svg',
                      width: leaf1172Width,
                      height: leaf1172Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1168Left,
                    top: leaf1168Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1168.svg',
                      width: leaf1168Width,
                      height: leaf1168Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1169Left,
                    top: leaf1169Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1169.svg',
                      width: leaf1169Width,
                      height: leaf1169Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1170Left,
                    top: leaf1170Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1170.svg',
                      width: leaf1170Width,
                      height: leaf1170Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1151Left,
                    top: leaf1151Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1151.svg',
                      width: leaf1151Width,
                      height: leaf1151Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1153Left,
                    top: leaf1153Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1153.svg',
                      width: leaf1153Width,
                      height: leaf1153Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1180Left,
                    top: leaf1180Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1180.svg',
                      width: leaf1180Width,
                      height: leaf1180Height,
                    ),
                  ),
                  Positioned(
                    left: leaf1171Left,
                    top: leaf1171Top,
                    child: SvgPicture.asset(
                      'assets/images/login_vector/Vector_1171.svg',
                      width: leaf1171Width,
                      height: leaf1171Height,
                    ),
                  ),
                  // Positioned(
                  //   left: leaf1152Left,
                  //   top: leaf1152Top,
                  //   child: SvgPicture.asset(
                  //     'assets/images/login_vector/Vector_1152.svg',
                  //     width: leaf1152Width,
                  //     height: leaf1152Height,
                  //   ),
                  // ),
                  // Positioned(
                  //   left: leaf1167Left,
                  //   top: leaf1167Top,
                  //   child: SvgPicture.asset(
                  //     'assets/images/login_vector/Vector_1167.svg',
                  //     width: leaf1167Width,
                  //     height: leaf1167Height,
                  //   ),
                  // ),
                ],
              ),
            ),
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
          // 하단 화살표 (업 인디케이터) - 물결 효과 애니메이션
          Positioned(
            left: 0,
            right: 0,
            top: arrowTop,
            child: AnimatedBuilder(
              animation: _arrowAnimationController,
              builder: (context, child) {
                return SizedBox(
                  height: h(60),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      _buildAnimatedArrow(
                        assetPath: 'assets/images/login_vector/Vector_1214.svg',
                        delay: 0.0,
                        baseOpacity: 0.45,
                        offsetY: 0,
                        h: h,
                      ),
                      _buildAnimatedArrow(
                        assetPath: 'assets/images/login_vector/Vector_1212.svg',
                        delay: 0.2,
                        baseOpacity: 0.6,
                        offsetY: 12,
                        h: h,
                      ),
                      _buildAnimatedArrow(
                        assetPath: 'assets/images/login_vector/Vector_1213.svg',
                        delay: 0.4,
                        baseOpacity: 0.75,
                        offsetY: 24,
                        h: h,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 개별 화살표 애니메이션 빌더
  Widget _buildAnimatedArrow({
    required String assetPath,
    required double delay,
    required double baseOpacity,
    required double offsetY,
    required double Function(double) h,
  }) {
    // 사인 곡선을 이용해 위로 솟았다가 돌아오는 물결 모션 생성
    final wave = (math.sin((_arrowAnimationController.value + delay) * 2 * math.pi) + 1) / 2;
    final translateY = -6 * wave;
    final opacity = baseOpacity + (1 - baseOpacity) * wave;

    return Positioned(
      top: h(offsetY),
      child: Transform.translate(
        offset: Offset(0, translateY),
        child: Opacity(
          opacity: opacity,
          child: SvgPicture.asset(assetPath),
        ),
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
            onPressed: _showEmailLoginSheet,
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
        const SizedBox(height: 24),
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
          if (_isGoogleLoading) return;
          _handleGoogleLogin();
        },
      ),
      _SocialLoginButtonData(
        assetPath: 'assets/images/btn_apple/btn_apple.svg',
        semanticLabel: 'Apple로 로그인',
        onTap: () {
          if (_isAppleLoading) return;
          _handleAppleLogin();
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

  // Login helpers
  void _showEmailLoginSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 24,
          ),
          child: Form(
            key: _loginFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '이메일로 로그인',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _loginEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일',
                    hintText: 'example@email.com',
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _loginPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    hintText: '비밀번호를 입력하세요',
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _isLoginLoading ? null : _handleEmailLogin,
                  child: _isLoginLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('로그인'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleAuthStateChange(AuthState state) {
    if (state.session == null) return;
    if (state.event == AuthChangeEvent.signedIn ||
        state.event == AuthChangeEvent.initialSession) {
      _navigateToHomeAfterLogin();
    }
  }

  void _navigateToHomeAfterLogin({bool closeEmailSheet = false}) {
    if (!mounted || _hasNavigatedAfterLogin) return;
    _hasNavigatedAfterLogin = true;
    if (closeEmailSheet) {
      Navigator.of(context).pop();
    }
    context.goNamed(RouteNames.home);
  }

  Future<void> _handleEmailLogin() async {
    FocusScope.of(context).unfocus();
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoginLoading = true);
    try {
      await _authService.signInWithEmailPassword(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
      _navigateToHomeAfterLogin(closeEmailSheet: true);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) setState(() => _isLoginLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    try {
      await _authService.signInWithGoogle();
      _navigateToHomeAfterLogin();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google 로그인 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleAppleLogin() async {
    if (_isAppleLoading) return;
    setState(() => _isAppleLoading = true);
    try {
      await _authService.signInWithApple();
      _navigateToHomeAfterLogin();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Apple 로그인 중 오류가 발생했습니다.')));
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return '이메일을 입력해 주세요.';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value.trim())) return '올바른 이메일 형식이 아닙니다.';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
    if (value.length < 8) return '비밀번호는 최소 8자 이상입니다.';
    return null;
  }

  /// Supabase AuthException을 한글 메시지로 변환
  String _getLocalizedAuthErrorMessage(AuthException e) {
    final message = e.message.toLowerCase();

    // 로그인 관련 에러
    if (message.contains('invalid login credentials') ||
        message.contains('invalid email or password')) {
      return '이메일 또는 비밀번호가 올바르지 않습니다.';
    }

    // 이메일 관련 에러
    if (message.contains('email not confirmed')) {
      return '이메일 인증이 필요합니다. 이메일을 확인해주세요.';
    }

    if (message.contains('user not found')) {
      return '존재하지 않는 계정입니다.';
    }

    // 비밀번호 관련 에러
    if (message.contains('password')) {
      return '비밀번호가 올바르지 않습니다.';
    }

    // 네트워크 관련 에러
    if (message.contains('network') || message.contains('connection')) {
      return '네트워크 연결을 확인해주세요.';
    }

    // 일반적인 에러 (원본 메시지 반환)
    return e.message;
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
