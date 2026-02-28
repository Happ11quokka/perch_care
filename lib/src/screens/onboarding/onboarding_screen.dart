import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../../l10n/app_localizations.dart';

/// 온보딩 화면 - 앱 소개 및 시작하기
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
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

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Stack(
        children: [
          _buildBackgroundCircles(screenWidth, screenHeight),
          _buildGradientCircle(screenWidth, screenHeight),
          _buildMainContent(screenWidth, screenHeight),
          _buildBottomContent(screenWidth, screenHeight),
        ],
      ),
    );
  }

  /// 배경 원형들 (2개의 원)
  Widget _buildBackgroundCircles(double screenWidth, double screenHeight) {
    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenHeight;

    final double circleCenterX = w(200);

    final double middleRingScale = 1.02;
    final double innerRingScale = 1.03;

    final double outerRingSize = w(439) * middleRingScale;
    final double outerRingCenterY = h(265.5);
    final double outerRingLeft = circleCenterX - (outerRingSize / 2) + w(10);
    final double outerRingTop = outerRingCenterY - (outerRingSize / 2);

    final double middleRingSize = w(268) * innerRingScale;
    final double middleRingCenterY = h(254);
    final double middleRingLeft = circleCenterX - (middleRingSize / 2);
    final double middleRingTop = middleRingCenterY - (middleRingSize / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
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
  Widget _buildGradientCircle(double screenWidth, double screenHeight) {
    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenHeight;

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

  /// 메인 콘텐츠 (새, 나무, 나뭇잎)
  Widget _buildMainContent(double screenWidth, double screenHeight) {
    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenHeight;

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

    final leaf1173Left = relX(9);
    final leaf1173Top = relY(319);
    final leaf1173Width = relW(20);
    final leaf1173Height = relH(198);

    final leaf1165Left = relX(260);
    final leaf1165Top = relY(418);
    final leaf1165Width = relW(20);
    final leaf1165Height = relH(37);

    final leaf1164Left = relX(397);
    final leaf1164Top = relY(445);
    final leaf1164Width = relW(20);
    final leaf1164Height = relH(26);

    final leaf1147Left = relX(31);
    final leaf1147Top = relY(263);
    final leaf1147Width = relW(20);
    final leaf1147Height = relH(53);

    final leaf1154Left = relX(26);
    final leaf1154Top = relY(365.5);
    final leaf1154Width = relW(20);
    final leaf1154Height = relH(45);

    final leaf1155Left = relX(137);
    final leaf1155Top = relY(369);
    final leaf1155Width = relW(20);
    final leaf1155Height = relH(43);

    final leaf1156Left = relX(95);
    final leaf1156Top = relY(458);
    final leaf1156Width = relW(20);
    final leaf1156Height = relH(25.5);

    final leaf1157Left = relX(49);
    final leaf1157Top = relY(448);
    final leaf1157Width = relW(20);
    final leaf1157Height = relH(26);

    final leaf1158Left = relX(142);
    final leaf1158Top = relY(470);
    final leaf1158Width = relW(20);
    final leaf1158Height = relH(27.5);

    final leaf1159Left = relX(133);
    final leaf1159Top = relY(482);
    final leaf1159Width = relW(20);
    final leaf1159Height = relH(20);

    final leaf1160Left = relX(131);
    final leaf1160Top = relY(466);
    final leaf1160Width = relW(20);
    final leaf1160Height = relH(12);

    final leaf1161Left = relX(81.5);
    final leaf1161Top = relY(443);
    final leaf1161Width = relW(20);
    final leaf1161Height = relH(12);

    final leaf1162Left = relX(106);
    final leaf1162Top = relY(479);
    final leaf1162Width = relW(20);
    final leaf1162Height = relH(13.5);

    final branch1114Left = relX(120);
    final branch1114Top = relY(439);
    final branch1114Width = relW(20);
    final branch1114Height = relH(54);

    final branch1112Left = relX(105);
    final branch1112Top = relY(284);
    final branch1112Width = relW(20);
    final branch1112Height = relH(65);

    final branch1113Left = relX(90);
    final branch1113Top = relY(310);
    final branch1113Width = relW(20);
    final branch1113Height = relH(15);

    final branch1115Left = relX(313);
    final branch1115Top = relY(370);
    final branch1115Width = relW(20);
    final branch1115Height = relH(54);

    final branch1175Left = relX(304);
    final branch1175Top = relY(381);
    final branch1175Width = relW(20);
    final branch1175Height = relH(23);

    final leaf1148Left = relX(95);
    final leaf1148Top = relY(258);
    final leaf1148Width = relW(20);
    final leaf1148Height = relH(50);

    final leaf1149Left = relX(83);
    final leaf1149Top = relY(281);
    final leaf1149Width = relW(20);
    final leaf1149Height = relH(40.5);

    final leaf1172Left = relX(110);
    final leaf1172Top = relY(305);
    final leaf1172Width = relW(20);
    final leaf1172Height = relH(16.5);

    final leaf1168Left = relX(220);
    final leaf1168Top = relY(378);
    final leaf1168Width = relW(20);
    final leaf1168Height = relH(50);

    final leaf1169Left = relX(270);
    final leaf1169Top = relY(380);
    final leaf1169Width = relW(20);
    final leaf1169Height = relH(33);

    final leaf1170Left = relX(240);
    final leaf1170Top = relY(335);
    final leaf1170Width = relW(20);
    final leaf1170Height = relH(45);

    final leaf1151Left = relX(23);
    final leaf1151Top = relY(245);
    final leaf1151Width = relW(20);
    final leaf1151Height = relH(44);

    final leaf1153Left = relX(90);
    final leaf1153Top = relY(348);
    final leaf1153Width = relW(20);
    final leaf1153Height = relH(23);

    final leaf1180Left = relX(45);
    final leaf1180Top = relY(390);
    final leaf1180Width = relW(20);
    final leaf1180Height = relH(19.5);

    final leaf1171Left = relX(280);
    final leaf1171Top = relY(325);
    final leaf1171Width = relW(20);
    final leaf1171Height = relH(27);

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: treeLeft,
            top: treeTop,
            child: RepaintBoundary(
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
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }

  /// 하단 콘텐츠 (제목, 설명, 인디케이터, 버튼)
  Widget _buildBottomContent(double screenWidth, double screenHeight) {
    double w(double value) => (value / _designWidth) * screenWidth;
    double h(double value) => (value / _designHeight) * screenHeight;
    final l10n = AppLocalizations.of(context)!;

    return Positioned(
      left: 0,
      right: 0,
      bottom: h(48),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: w(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 제목
            Text(
              l10n.onboarding_title,
              style: TextStyle(
                fontSize: w(28),
                fontWeight: FontWeight.w700,
                color: AppColors.nearBlack,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: h(12)),

            // 설명
            Text(
              l10n.onboarding_description,
              style: TextStyle(
                fontSize: w(15),
                height: 1.6,
                color: AppColors.gray600,
              ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: h(48)),

            // 시작하기 버튼
            _buildStartButton(w, h, l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildStartButton(
      double Function(double) w, double Function(double) h, AppLocalizations l10n) {
    final borderRadius = BorderRadius.circular(w(12));

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: () {
          context.goNamed(RouteNames.login);
        },
        borderRadius: borderRadius,
        child: Ink(
          width: double.infinity,
          height: h(56),
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
          child: Center(
            child: Text(
              l10n.btn_start,
              style: TextStyle(
                fontSize: w(18),
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
