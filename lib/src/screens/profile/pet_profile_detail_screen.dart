import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../widgets/bottom_nav_bar.dart';

/// 반려동물 프로필 상세/편집 화면
class PetProfileDetailScreen extends StatefulWidget {
  const PetProfileDetailScreen({super.key});

  @override
  State<PetProfileDetailScreen> createState() => _PetProfileDetailScreenState();
}

class _PetProfileDetailScreenState extends State<PetProfileDetailScreen> {
  final _formKey = GlobalKey<FormState>();

  // TODO: 실제 데이터로 대체
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _speciesController = TextEditingController();
  String? _selectedGender;
  DateTime? _birthday;
  DateTime? _adoptionDate;

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _speciesController.dispose();
    super.dispose();
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 34),

                      // 프로필 이미지
                      _buildProfileImage(),

                      const SizedBox(height: 32),

                      // 입력 필드들
                      _buildInputFields(),

                      const SizedBox(height: 32),

                      // 저장 버튼
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: _buildSaveButton(),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: -1),
    );
  }

  /// 상단 앱바
  Widget _buildAppBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Stack(
        children: [
          // 뒤로가기 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => context.pop(),
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
          Center(
            child: Text(
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
          ),
        ],
      ),
    );
  }

  /// 프로필 이미지
  Widget _buildProfileImage() {
    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 프로필 이미지 플레이스홀더
            SvgPicture.asset(
              'assets/images/profile/pet_profile_placeholder.svg',
              width: 120,
              height: 120,
            ),

            // 편집 버튼
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  // TODO: 이미지 업로드 기능
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/images/profile/edit.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 입력 필드들
  Widget _buildInputFields() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // 이름
          _buildTextField(
            controller: _nameController,
            hintText: '이름을 입력해 주세요',
          ),

          const SizedBox(height: 16),

          // 성별
          _buildGenderSelector(),

          const SizedBox(height: 16),

          // 몸무게
          _buildTextField(
            controller: _weightController,
            hintText: '몸무게',
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 16),

          // 생일
          _buildDateSelector(
            hintText: '생일',
            selectedDate: _birthday,
            onTap: () => _selectDate(context, isAdoptionDate: false),
          ),

          const SizedBox(height: 16),

          // 가족이 된 날
          _buildDateSelector(
            hintText: '가족이 된 날',
            selectedDate: _adoptionDate,
            onTap: () => _selectDate(context, isAdoptionDate: true),
          ),

          const SizedBox(height: 16),

          // 종
          _buildTextField(
            controller: _speciesController,
            hintText: '종',
          ),
        ],
      ),
    );
  }

  /// 텍스트 입력 필드
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF97928A),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Center(
        child: Theme(
          data: ThemeData(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: AppColors.brandPrimary,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1A1A1A),
              height: 20 / 14,
              letterSpacing: -0.35,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF97928A),
                height: 20 / 14,
                letterSpacing: -0.35,
              ),
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
            ),
          ),
        ),
      ),
    );
  }

  /// 성별 선택기
  Widget _buildGenderSelector() {
    return GestureDetector(
      onTap: () => _showGenderPicker(),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFF97928A),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _selectedGender ?? '성별을 선택해 주세요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _selectedGender != null
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF97928A),
                height: 20 / 14,
                letterSpacing: -0.35,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: const Color(0xFF97928A),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 날짜 선택기
  Widget _buildDateSelector({
    required String hintText,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFF97928A),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              selectedDate != null
                  ? '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')}'
                  : hintText,
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: selectedDate != null
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF97928A),
                height: 20 / 14,
                letterSpacing: -0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 저장 버튼
  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandPrimary, const Color(0xFFFF7C2A)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleSave,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Text(
              '저장',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 26 / 18,
                letterSpacing: -0.45,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 성별 선택 모달
  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('수컷'),
              onTap: () {
                setState(() {
                  _selectedGender = '수컷';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('암컷'),
              onTap: () {
                setState(() {
                  _selectedGender = '암컷';
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 날짜 선택
  Future<void> _selectDate(BuildContext context, {required bool isAdoptionDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isAdoptionDate ? (_adoptionDate ?? DateTime.now()) : (_birthday ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isAdoptionDate) {
          _adoptionDate = picked;
        } else {
          _birthday = picked;
        }
      });
    }
  }

  /// 저장 처리
  void _handleSave() {
    // TODO: 실제 저장 로직 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다.')),
    );
    context.pop();
  }
}
