import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/colors.dart';

/// 로그인 화면
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

    // 중앙 원의 중심점을 화면 상단에서 36~38% 지점에 배치 (37% 사용)
    final centerCircleY = screenHeight * 0.37;

    // 원의 크기 정의 (화면 너비 기준)
    final centerCircleSize = screenWidth * 0.85; // 중앙 원
    final middleCircleSize = screenWidth * 1.35; // 중간 원환
    final outerCircleSize = screenWidth * 1.95; // 맨 외부 원환

    // 중앙 정렬을 위한 left 위치 계산
    final centerCircleLeft = (screenWidth - centerCircleSize) / 2;
    final middleCircleLeft = (screenWidth - middleCircleSize) / 2;
    final outerCircleLeft = (screenWidth - outerCircleSize) / 2;

    // top 위치 계산 (중심점 기준)
    final centerCircleTop = centerCircleY - (centerCircleSize / 2);
    final middleCircleTop = centerCircleY - (middleCircleSize / 2);
    final outerCircleTop = centerCircleY - (outerCircleSize / 2);

    return Stack(
      children: [
        // 맨 외부 원환 (Ellipse 69)
        Positioned(
          left: outerCircleLeft,
          top: outerCircleTop,
          child: SvgPicture.asset(
            'assets/images/login_vector/Ellipse_69.svg',
            width: outerCircleSize,
            height: outerCircleSize,
            fit: BoxFit.contain,
          ),
        ),

        // 중간 원환 (Ellipse 86)
        Positioned(
          left: middleCircleLeft,
          top: middleCircleTop,
          child: SvgPicture.asset(
            'assets/images/login_vector/Ellipse_86.svg',
            width: middleCircleSize,
            height: middleCircleSize,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  /// 중앙 그라데이션 원
  Widget _buildGradientCircle() {
    final screenSize = MediaQuery.of(context).size;
    final screenHeight = screenSize.height;
    final screenWidth = screenSize.width;

    // 중앙 원의 중심점을 화면 상단에서 36~38% 지점에 배치 (37% 사용)
    final centerCircleY = screenHeight * 0.37;

    // 중앙 그라데이션 원 크기 (중앙 원의 약 90% 크기)
    final gradientCircleSize = screenWidth * 0.76;

    // 중앙 정렬을 위한 left 위치 계산
    final gradientCircleLeft = (screenWidth - gradientCircleSize) / 2;

    // top 위치 계산 (중심점 기준)
    final gradientCircleTop = centerCircleY - (gradientCircleSize / 2);

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
    return Stack(
      children: [
        // 새 이미지 (꼬리까지 전체) - SafeArea 고려하여 위치 조정
        Positioned(
          left: 133,
          top: 100, // 파란색 박스 영역으로 이동
          child: SvgPicture.asset(
            'assets/images/login_bird.svg',
            width: 263,
            height: 224,
          ),
        ),

        // 나무 이미지
        Positioned(
          left: 0,
          right: 0,
          top: 220, // 새에 맞춰 위로 이동
          child: Center(
            child: SvgPicture.asset(
              'assets/images/tree.svg',
              width: 300,
            ),
          ),
        ),

        // 브랜드명 (p.e.r.c.h)
        Positioned(
          left: 0,
          right: 0,
          top: 500, // 위로 이동
          child: Center(
            child: SvgPicture.asset(
              'assets/images/p.e.r.c.h.svg',
              width: 230,
            ),
          ),
        ),

        // 슬로건
        Positioned(
          left: 0,
          right: 0,
          top: 545, // 위로 이동
          child: Center(
            child: Image.asset(
              'assets/images/slogan.png',
              width: 257,
              height: 22,
            ),
          ),
        ),

        // 하단 화살표 (업 인디케이터)
        Positioned(
          left: 0,
          right: 0,
          bottom: 120,
          child: Center(
            child: Icon(
              Icons.keyboard_arrow_up,
              color: AppColors.brandPrimary.withOpacity(0.5),
              size: 48,
            ),
          ),
        ),
      ],
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
                _sheetHeight = _sheetHeight > midPoint ? _expandedHeight : _peekHeight;
              }
            }
          });
        },
        onTap: () {
          // 탭하면 펼치기/접기 토글
          setState(() {
            _sheetHeight = _sheetHeight == _peekHeight ? _expandedHeight : _peekHeight;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          height: _sheetHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: const Alignment(0.50, 0.00),
              end: const Alignment(0.50, 1.00),
              colors: [
                AppColors.white,
                AppColors.gray500,
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3F000000),
                blurRadius: 10,
                offset: Offset(0, 0),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const Text(
                          '로그인',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        // 여기에 로그인 폼 추가 예정
                      ],
                    ),
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
}
