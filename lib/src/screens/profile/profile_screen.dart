import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../widgets/bottom_nav_bar.dart';

/// 프로필 화면 - 반려동물 프로필 목록
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _unselectedCardColor = Color(0xFFE7E5E1);
  final _petCache = PetLocalCacheService();
  // TODO: 실제 데이터로 대체
  final String _userName = '쿼카16978님';
  int? _selectedPetIndex = 0; // 현재 기록 중인 프로필
  List<PetProfileCache> _cachedPets = [];
  bool _isLoadingPets = true;

  // TODO: 실제 반려동물 데이터로 대체
  final List<Map<String, dynamic>> _pets = [
    {
      'name': '점점이',
      'species': '종이름넣어줘요',
      'age': '3년 1개월 23일',
      'gender': 'female', // 'male' or 'female'
    },
    {
      'name': '점점이',
      'species': '종이름넣어줘요',
      'age': '3년 1개월 23일',
      'gender': 'male',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final pets = await _petCache.getPets();
    if (!mounted) return;
    setState(() {
      _cachedPets = pets;
      _isLoadingPets = false;
      if (_cachedPets.isNotEmpty) {
        _selectedPetIndex = 0;
      }
    });
  }

  List<Map<String, dynamic>> get _displayPets {
    if (_cachedPets.isEmpty) return _pets;
    return _cachedPets.map(_mapCacheToDisplay).toList();
  }

  Map<String, dynamic> _mapCacheToDisplay(PetProfileCache pet) {
    return {
      'id': pet.id,
      'name': pet.name,
      'species': pet.species?.isNotEmpty == true ? pet.species! : '종 정보 없음',
      'age': _formatAge(pet.birthDate),
      'gender': pet.gender,
      'isCached': true,
    };
  }

  String _formatAge(DateTime? birthDate) {
    if (birthDate == null) return '나이 정보 없음';
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    int days = now.day - birthDate.day;

    if (days < 0) {
      final prevMonth = DateTime(now.year, now.month, 0);
      days += prevMonth.day;
      months -= 1;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    final segments = <String>[];
    if (years > 0) segments.add('${years}년');
    if (months > 0) segments.add('${months}개월');
    if (days > 0) segments.add('${days}일');
    return segments.isEmpty ? '0일' : segments.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 앱바
            _buildAppBar(),

            // 스크롤 가능한 컨텐츠
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 프로필 섹션
                    _buildUserProfileSection(),

                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      color: const Color(0xFFF0F0F0),
                    ),

                    // "나의 반려가족" 타이틀
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        '나의 반려가족',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                          height: 22 / 16,
                          letterSpacing: 0.08,
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    // 반려동물 프로필 카드들
                    if (_isLoadingPets)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: LinearProgressIndicator(minHeight: 2),
                      )
                    else
                      ..._displayPets.asMap().entries.map((entry) {
                        return _buildPetProfileCard(
                          index: entry.key,
                          pet: entry.value,
                        );
                      }),

                    const SizedBox(height: 12),

                    // 새로운 아이 등록하기 버튼
                    _buildAddPetButton(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: -1), // 선택 상태 없음
    );
  }

  /// 상단 앱바
  Widget _buildAppBar() {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 뒤로가기 버튼
            Positioned(
              left: 0,
              child: GestureDetector(
                onTap: () => context.goNamed(RouteNames.home),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: SvgPicture.asset(
                    'assets/images/profile/back_arrow.svg',
                  ),
                ),
              ),
            ),

            // 제목
            Text(
              '프로필',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
                height: 34 / 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 사용자 프로필 섹션
  Widget _buildUserProfileSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(37, 12, 32, 0),
      child: Row(
        children: [
          // 프로필 아이콘과 편집 버튼
          GestureDetector(
            onTap: () {
              context.pushNamed(RouteNames.profileSetup);
            },
            child: SizedBox(
              width: 50,
              height: 50,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 프로필 아이콘
                  SvgPicture.asset(
                    'assets/images/profile/profile.svg',
                    width: 50,
                    height: 50,
                  ),
                  // 편집 아이콘
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/images/profile/edit.svg',
                          width: 10,
                          height: 10,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 사용자 이름
          Text(
            _userName,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A1A1A),
              height: 22 / 16,
              letterSpacing: 0.08,
            ),
          ),
        ],
      ),
    );
  }

  /// 반려동물 프로필 카드
  Widget _buildPetProfileCard({
    required int index,
    required Map<String, dynamic> pet,
  }) {
    final isSelected = index == _selectedPetIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPetIndex = index;
        });
        final petId = pet['id'] as String?;
        if (petId != null) {
          _petCache.setActivePetId(petId);
        }
      },
      child: Container(
        height: 120,
        margin: const EdgeInsets.fromLTRB(32, 0, 32, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF5ED) : _unselectedCardColor,
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : Colors.transparent,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // 프로필 이미지
            SvgPicture.asset(
              'assets/images/profile/pet_profile_placeholder.svg',
              width: 62.64,
              height: 62.64,
            ),

            const SizedBox(width: 15),

            // 정보
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 이름과 성별
                  Row(
                    children: [
                      Text(
                        pet['name'],
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF1A1A1A),
                          height: 22 / 16,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(width: 1),
                      if (pet['gender'] == 'male' ||
                          pet['gender'] == 'female')
                        SvgPicture.asset(
                          pet['gender'] == 'male'
                              ? 'assets/images/profile/gender_male.svg'
                              : 'assets/images/profile/gender_female.svg',
                          width: 20,
                          height: 20,
                        )
                      else
                        const SizedBox(width: 20, height: 20),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // 종
                  Text(
                    pet['species'],
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B6B6B),
                      height: 22 / 12,
                      letterSpacing: 0.06,
                    ),
                  ),

                  // 나이
                  Text(
                    pet['age'],
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B6B6B),
                      height: 22 / 12,
                      letterSpacing: 0.06,
                    ),
                  ),
                ],
              ),
            ),

            // 편집 아이콘
            GestureDetector(
              onTap: () async {
                await context.pushNamed(RouteNames.petProfileDetail);
                await _loadPets();
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.brandPrimary : const Color(0xFF97928A),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/images/profile/edit.svg',
                    width: 14,
                    height: 14,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 새로운 아이 등록하기 버튼
  Widget _buildAddPetButton() {
    return GestureDetector(
      onTap: () async {
        await context.pushNamed(RouteNames.petProfileDetail);
        await _loadPets();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        child: _DashedBorder(
          color: const Color(0xFF97928A),
          radius: 16,
          strokeWidth: 1,
          dashWidth: 6,
          dashGap: 6,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 플러스 아이콘
                Container(
                  width: 14.15,
                  height: 14.15,
                  decoration: const BoxDecoration(
                    color: Color(0xFF97928A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add,
                    size: 10,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(width: 8),

                // 텍스트
                Text(
                  '새로운 아이 등록하기',
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF97928A),
                    height: 34 / 16,
                    letterSpacing: -0.5,
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

class _DashedBorder extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  const _DashedBorder({
    required this.child,
    required this.radius,
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dashWidth: dashWidth,
        dashGap: dashGap,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  const _DashedBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashGap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final double next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.radius != radius ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashGap != dashGap;
  }
}
