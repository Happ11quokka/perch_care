import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/pet/pet_service.dart';
import '../../models/pet.dart';
import '../../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _petService = PetService();
  Pet? _activePet;
  bool _isLoading = true;
  bool _isMonthlyView = true; // true: 매월 단위, false: 매주 단위
  int _selectedMonth = DateTime.now().month;
  int _selectedWeek = 1; // 선택된 주차 (1~5)

  // 데이터 유무 상태 (실제로는 서버에서 가져옴)
  bool _hasWeightData = false;
  bool _hasFoodData = false;
  bool _hasWaterData = false;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final activePet = await _petService.getActivePet();

      if (mounted) {
        setState(() {
          _activePet = activePet;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 스크롤 가능한 컨텐츠
                Column(
                  children: [
                    // 헤더 높이만큼 공간 확보
                    SizedBox(height: MediaQuery.of(context).padding.top + 140),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              // WCI 건강 상태 카드
                              _buildWCICard(),
                              const SizedBox(height: 12),
                              // 하단 4개 카드
                              _buildBottomCards(),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // 상단 헤더 (고정, 위에 표시)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildHeader(),
                ),
              ],
            ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            // 토글 버튼과 프로필 아이콘
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 토글 버튼 (중앙 정렬)
                  _buildViewToggle(),
                  // 프로필 아이콘 (오른쪽 정렬)
                  Positioned(
                    right: 0,
                    child: GestureDetector(
                      onTap: () {
                        context.pushNamed(RouteNames.profile);
                      },
                      child: const Icon(
                        Icons.person_outline,
                        size: 24,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 월/주 선택기 (애니메이션)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.1),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _isMonthlyView
                  ? _buildMonthSelector()
                  : _buildWeekSelector(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Center(
      child: Container(
        width: 170,
        height: 48,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            // 애니메이션되는 배경 pill
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: _isMonthlyView ? 0 : 83,
              top: 0,
              bottom: 0,
              child: Container(
                width: 83,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            // 텍스트 버튼들
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMonthlyView = true;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _isMonthlyView ? Colors.white : const Color(0xFF97928A),
                          letterSpacing: -0.35,
                        ),
                        child: const Text('매월 단위'),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMonthlyView = false;
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      alignment: Alignment.center,
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: !_isMonthlyView ? Colors.white : const Color(0xFF97928A),
                          letterSpacing: -0.35,
                        ),
                        child: const Text('매주 단위'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector() {
    final months = [2, 3, 4, 5, 6, 7, 8];

    return SizedBox(
      key: const ValueKey('month'),
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: months.map((month) {
          final isSelected = month == _selectedMonth;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedMonth = month;
              });
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: Text(
                '$month월',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWeekSelector() {
    final weeks = [1, 2, 3, 4, 5];

    return SizedBox(
      key: const ValueKey('week'),
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: weeks.map((week) {
          final isSelected = week == _selectedWeek;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedWeek = week;
              });
            },
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(100),
              ),
              alignment: Alignment.center,
              child: Text(
                '$week주',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : const Color(0xFF6B6B6B),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildWCICard() {
    final petName = _activePet?.name ?? '사랑이';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                        children: [
                          TextSpan(
                            text: 'WCI',
                            style: const TextStyle(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(
                            text: '*',
                            style: const TextStyle(
                              color: AppColors.brandPrimary,
                            ),
                          ),
                          const TextSpan(text: ' 건강 상태'),
                        ],
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 16,
                      color: Color(0xFF97928A),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '0분 전에 업데이트됨',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF97928A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 새 일러스트레이션
          SvgPicture.asset(
            'assets/images/home_vector/wci_bird_empty.svg',
            width: 119,
            height: 171,
          ),
          const SizedBox(height: 13),
          // 설명 텍스트
          Text(
            '데이터를 입력해 $petName의',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B6B6B),
              letterSpacing: -0.35,
              height: 24 / 14,
            ),
          ),
          const Text(
            '상태를 확인해 보세요.',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B6B6B),
              letterSpacing: -0.35,
              height: 24 / 14,
            ),
          ),
          const SizedBox(height: 24),
          // 진행도 바
          _buildProgressBars(),
          const SizedBox(height: 8),
          // 단계 표시
          const Text(
            '0단계',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              height: 20 / 16,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildProgressBars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildProgressBar(false),
        const SizedBox(width: 2),
        _buildProgressBar(false),
        const SizedBox(width: 2),
        // 중앙 인디케이터
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFF0F0F0),
              width: 2,
            ),
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 2),
        _buildProgressBar(false),
        const SizedBox(width: 2),
        _buildProgressBar(false),
      ],
    );
  }

  Widget _buildProgressBar(bool isActive) {
    return Container(
      width: 74,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? AppColors.brandPrimary : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(1),
        border: Border.all(
          color: const Color(0xFFF0F0F0),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildBottomCards() {
    return Column(
      children: [
        // 첫 번째 행: 체중, 사료
        Row(
          children: [
            Expanded(
              child: _buildDataCard(
                title: '체중',
                subtitle: '체중을 입력해주세요',
                iconPath: 'assets/images/home_vector/weight.svg',
                hasData: _hasWeightData,
                onTap: () {
                  context.pushNamed(RouteNames.weightDetail);
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildDataCard(
                title: '사료',
                subtitle: '취식량을 입력해주세요',
                iconPath: 'assets/images/home_vector/eat.svg',
                hasData: _hasFoodData,
                onTap: () {
                  // TODO: 사료 화면으로 이동
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 두 번째 행: 수분, 오늘의 건강 신호
        Row(
          children: [
            Expanded(
              child: _buildDataCard(
                title: '수분',
                subtitle: '음수량을 입력해주세요',
                iconPath: 'assets/images/home_vector/water.svg',
                hasData: _hasWaterData,
                onTap: () {
                  // TODO: 수분 화면으로 이동
                },
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildHealthSignalCard(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataCard({
    required String title,
    required String subtitle,
    required String iconPath,
    required bool hasData,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: -0.4,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Color(0xFF97928A),
                ),
              ],
            ),
            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            // 아이콘 (SVG에 이미 원형 테두리가 포함되어 있음)
            Align(
              alignment: Alignment.bottomRight,
              child: SvgPicture.asset(
                iconPath,
                width: 60,
                height: 60,
                colorFilter: hasData
                    ? const ColorFilter.mode(
                        AppColors.brandPrimary,
                        BlendMode.srcIn,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthSignalCard() {
    return GestureDetector(
      onTap: () {
        // TODO: 건강 신호 화면으로 이동
      },
      child: Container(
        height: 170,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment(-0.7, -0.7),
            end: Alignment(0.7, 0.7),
            colors: [
              Colors.white,
              Color(0xFFFFF5ED),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.brandPrimary,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.4,
                        height: 26 / 16,
                      ),
                    ),
                    Text(
                      '건강 신호',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.4,
                        height: 26 / 16,
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Color(0xFF97928A),
                ),
              ],
            ),
            const Spacer(),
            // 아이콘 (SVG에 이미 배경 원이 포함되어 있음)
            Align(
              alignment: Alignment.bottomRight,
              child: SvgPicture.asset(
                'assets/images/home_vector/daily_health.svg',
                width: 60,
                height: 60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
