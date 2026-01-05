import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../widgets/bottom_nav_bar.dart';

/// 반려동물 프로필 목록 화면
class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key});

  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  // TODO: 실제 데이터는 상태 관리나 DB에서 가져와야 함
  final List<Map<String, dynamic>> pets = [
    {
      'id': '1',
      'name': '점점이',
      'species': '종이름넣어줘요',
      'age': '3년 1개월 23일',
      'gender': 'male',
      'isSelected': true,
    },
    {
      'id': '2',
      'name': '점점이',
      'species': '종이름넣어줘요',
      'age': '3년 1개월 23일',
      'gender': 'female',
      'isSelected': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          '프로필',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 프로필 섹션
                  _buildProfileSection(),
                  const SizedBox(height: 4),
                  // 구분선
                  Container(
                    height: 1,
                    color: const Color(0xFFF0F0F0),
                  ),
                  const SizedBox(height: 20),
                  // 나의 반려가족
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      '나의 반려가족',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.08,
                      ),
                    ),
                  ),
                  const SizedBox(height: 11),
                  // 반려동물 목록
                  ...pets.map((pet) => _buildPetCard(pet)),
                  const SizedBox(height: 12),
                  // 새로운 아이 등록하기
                  _buildAddPetButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 7, 32, 20),
      child: Row(
        children: [
          // 프로필 이미지
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFE0E0E0),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/default_profile.svg',
                width: 30,
                height: 30,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 닉네임
          const Text(
            '쿼카16978님',
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
              letterSpacing: 0.08,
            ),
          ),
          const Spacer(),
          // 설정 버튼
          GestureDetector(
            onTap: () {
              // TODO: 설정 화면으로 이동
            },
            child: SvgPicture.asset(
              'assets/images/settings_icon.svg',
              width: 24,
              height: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetCard(Map<String, dynamic> pet) {
    final isSelected = pet['isSelected'] as bool;

    return Container(
      margin: const EdgeInsets.only(left: 32, right: 32, bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF5ED) : const Color(0xFFF0F0F0),
        border: Border.all(
          color: isSelected ? const Color(0xFFFF9A42) : Colors.transparent,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 프로필 이미지
          Container(
            width: 62.64,
            height: 62.64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD9D9D9),
            ),
            child: Center(
              child: SvgPicture.asset(
                'assets/images/pet_profile.svg',
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 15),
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      pet['name'] as String,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.08,
                      ),
                    ),
                    const SizedBox(width: 1),
                    SvgPicture.asset(
                      pet['gender'] == 'male'
                          ? 'assets/images/gender_male.svg'
                          : 'assets/images/gender_female.svg',
                      width: 20,
                      height: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  pet['species'] as String,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B6B6B),
                    letterSpacing: 0.06,
                  ),
                ),
                Text(
                  pet['age'] as String,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B6B6B),
                    letterSpacing: 0.06,
                  ),
                ),
              ],
            ),
          ),
          // 수정 버튼
          GestureDetector(
            onTap: () {
              context.pushNamed(
                RouteNames.petAdd,
                extra: {'petId': pet['id']},
              );
            },
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFFFF9A42)
                    : const Color(0xFF97928A),
              ),
              child: const Icon(
                Icons.edit,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPetButton() {
    return GestureDetector(
      onTap: () {
        context.pushNamed(RouteNames.petAdd);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFF97928A),
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 14.15,
              height: 14.15,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF97928A),
              ),
              child: const Icon(
                Icons.add,
                size: 10,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '새로운 아이 등록하기',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF97928A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
