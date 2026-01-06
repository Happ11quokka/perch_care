import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import 'widgets/country_selector_bottom_sheet.dart';

/// 프로필 설정 화면
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _fieldBorderColor = Color(0xFF97928A);
  static const _fieldRadius = 16.0;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();

  String? _selectedGender;
  Country _selectedCountry = Country.korea;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _phoneFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  // Form validation - currently not used but kept for future validation features
  // bool get _isFormValid {
  //   return _nameController.text.isNotEmpty &&
  //       _selectedGender != null &&
  //       _emailController.text.isNotEmpty &&
  //       _phoneController.text.isNotEmpty;
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            icon: SvgPicture.asset(
              'assets/images/back_arrow_icon.svg',
              width: 28,
              height: 28,
            ),
            onPressed: () => context.pop(),
          ),
        ),
        centerTitle: true,
        title: const Text(
          '프로필 설정',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
            height: 1.7,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // 프로필 이미지
                    _buildProfileImage(),
                    const SizedBox(height: 32),
                    // 입력 필드들
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildGenderField(),
                    const SizedBox(height: 16),
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildPhoneField(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // 하단 버튼들
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 프로필 아바타
          SvgPicture.asset(
            'assets/images/profile_avatar.svg',
            width: 120,
            height: 120,
          ),
          // 편집 버튼
          Positioned(
            bottom: -6,
            right: -6,
            child: GestureDetector(
              onTap: _handleEditPhoto,
              child: SvgPicture.asset(
                'assets/images/profile_edit_icon.svg',
                width: 24,
                height: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_fieldRadius),
        border: Border.all(
          color: _fieldBorderColor,
          width: 1,
        ),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: TextField(
          controller: _nameController,
          focusNode: _nameFocusNode,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.35,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            border: InputBorder.none,
            hintText: '이름을 입력해 주세요',
            hintStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF97928A),
              letterSpacing: -0.35,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderField() {
    return GestureDetector(
      onTap: _showGenderPicker,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_fieldRadius),
          border: Border.all(color: _fieldBorderColor, width: 1),
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedGender ?? '성별을 선택해 주세요',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: _selectedGender != null
                    ? const Color(0xFF1A1A1A)
                    : _fieldBorderColor,
                letterSpacing: -0.35,
              ),
            ),
            Transform.rotate(
              angle: 3.14159, // 180 degrees
              child: SvgPicture.asset(
                'assets/images/dropdown_arrow_icon.svg',
                width: 12,
                height: 8,
                colorFilter: const ColorFilter.mode(
                  Color(0xFF97928A),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_fieldRadius),
        border: Border.all(
          color: _fieldBorderColor,
          width: 1,
        ),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(
        child: TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.35,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            border: InputBorder.none,
            hintText: '이메일을 입력해 주세요',
            hintStyle: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF97928A),
              letterSpacing: -0.35,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_fieldRadius),
        border: Border.all(
          color: _fieldBorderColor,
          width: 1,
        ),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // 국가 선택
          GestureDetector(
            onTap: _showCountrySelector,
            child: Container(
              padding: const EdgeInsets.only(left: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 국기 이미지
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: SvgPicture.asset(
                      _selectedCountry.flagAsset,
                      width: 24,
                      height: 17,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Transform.rotate(
                    angle: 3.14159, // 180 degrees
                    child: SvgPicture.asset(
                      'assets/images/dropdown_arrow_icon.svg',
                      width: 12,
                      height: 8,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF97928A),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 전화번호 입력
          Expanded(
            child: TextField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              keyboardType: TextInputType.phone,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.35,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.only(right: 20),
                border: InputBorder.none,
                hintText: '전화번호를 입력해 주세요',
                hintStyle: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF97928A),
                  letterSpacing: -0.35,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 34),
      child: Row(
        children: [
          // 다음에 버튼
          Expanded(
            child: GestureDetector(
              onTap: _handleSkip,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF97928A),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '다음에',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF97928A),
                      letterSpacing: -0.45,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 입력완료 버튼
          Expanded(
            child: GestureDetector(
              onTap: _handleComplete,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    '입력완료',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.45,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEditPhoto() {
    // TODO: 사진 선택 기능 구현
  }

  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    '성별을 선택하세요',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.35,
                    ),
                  ),
                ),
                ListTile(
                  title: const Text(
                    '남',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedGender = '남');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text(
                    '여',
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedGender = '여');
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCountrySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return CountrySelectorBottomSheet(
          selectedCountry: _selectedCountry,
          onCountrySelected: (country) {
            setState(() => _selectedCountry = country);
          },
        );
      },
    );
  }

  void _handleSkip() {
    // 다음에 - 완료 화면으로 이동하지 않고 홈으로 이동
    context.goNamed(RouteNames.home);
  }

  void _handleComplete() {
    // TODO: 프로필 데이터 저장 로직
    // 완료 화면으로 이동
    context.goNamed(
      RouteNames.profileSetupComplete,
      extra: {'petName': _nameController.text.isNotEmpty ? _nameController.text : '점점이'},
    );
  }
}
