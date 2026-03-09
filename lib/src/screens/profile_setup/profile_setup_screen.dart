import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:country_picker/country_picker.dart';
import '../../utils/image_crop_helper.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../services/auth/auth_service.dart';
import '../../services/api/token_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import 'widgets/country_selector_bottom_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

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

  final _authService = AuthService();
  File? _selectedImage;
  Uint8List? _savedImageBytes;
  bool _isSaving = false;

  String? _selectedGender;
  Country _selectedCountry = CountryParser.parseCountryCode('KR'); // 대한민국

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() => setState(() {}));
    _emailFocusNode.addListener(() => setState(() {}));
    _phoneFocusNode.addListener(() => setState(() {}));
    _loadUserProfile();
    _loadSavedImage();
  }

  Future<void> _loadSavedImage() async {
    final userId = TokenService.instance.userId;
    if (userId == null) return;
    try {
      final bytes = await LocalImageStorageService.instance.getImage(
        ownerType: ImageOwnerType.userProfile,
        ownerId: userId,
      );
      if (bytes != null && mounted) {
        setState(() => _savedImageBytes = bytes);
      }
    } catch (_) {}
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _authService.getProfile();
      if (profile != null && mounted) {
        setState(() {
          final email = profile['email'] as String?;
          if (email != null && email.isNotEmpty) {
            _emailController.text = email;
          }
          final nickname = profile['nickname'] as String?;
          if (nickname != null && nickname.isNotEmpty) {
            _nameController.text = nickname;
          }
        });
      }
    } catch (_) {
      // 프로필 로드 실패 시 무시
    }
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

  String _genderDisplayText(AppLocalizations l10n) {
    if (_selectedGender == null) return l10n.pet_gender_hint;
    return _selectedGender == 'male'
        ? l10n.profileSetup_genderMale
        : l10n.profileSetup_genderFemale;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 앱바
            Container(
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
                      l10n.profileSetup_title,
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
            ),

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
                    _buildNameField(l10n),
                    const SizedBox(height: 16),
                    _buildGenderField(l10n),
                    const SizedBox(height: 16),
                    _buildEmailField(l10n),
                    const SizedBox(height: 16),
                    _buildPhoneField(l10n),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            // 하단 버튼들
            _buildBottomButtons(l10n),
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
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              shape: BoxShape.circle,
              image: _selectedImage != null
                  ? DecorationImage(
                      image: FileImage(_selectedImage!),
                      fit: BoxFit.cover,
                    )
                  : _savedImageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_savedImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
            ),
            child: _selectedImage == null && _savedImageBytes == null
                ? Center(
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: const Color(0xFF6B6B6B),
                    ),
                  )
                : null,
          ),
          // 편집 버튼
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _handleEditPhoto,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.edit,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(AppLocalizations l10n) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _fieldBorderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      alignment: Alignment.centerLeft,
      child: Theme(
        data: ThemeData(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColors.brandPrimary,
          ),
        ),
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
            filled: false,
            fillColor: Colors.transparent,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: l10n.input_name_hint,
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

  Widget _buildGenderField(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _showGenderPicker(l10n),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _fieldBorderColor, width: 1),
          borderRadius: BorderRadius.circular(_fieldRadius),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _genderDisplayText(l10n),
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

  Widget _buildEmailField(AppLocalizations l10n) {
    final hasEmail = _emailController.text.isNotEmpty;
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: hasEmail ? const Color(0xFFF5F5F5) : Colors.white,
        border: Border.all(
          color: _fieldBorderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      alignment: Alignment.centerLeft,
      child: Theme(
        data: ThemeData(
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: AppColors.brandPrimary,
          ),
        ),
        child: TextField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType: TextInputType.emailAddress,
          readOnly: hasEmail,
          enabled: !hasEmail,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: hasEmail ? const Color(0xFF97928A) : const Color(0xFF1A1A1A),
            letterSpacing: -0.35,
          ),
          decoration: InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: l10n.input_email_hint,
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

  Widget _buildPhoneField(AppLocalizations l10n) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: _fieldBorderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(_fieldRadius),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 국가 선택
          GestureDetector(
            onTap: _showCountrySelector,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 국기 이모지
                Text(
                  _selectedCountry.flagEmoji,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: const Color(0xFF97928A),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // 전화번호 입력
          Expanded(
            child: Theme(
              data: ThemeData(
                textSelectionTheme: TextSelectionThemeData(
                  cursorColor: AppColors.brandPrimary,
                ),
              ),
              child: TextField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                textAlignVertical: TextAlignVertical.center,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.35,
                ),
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: l10n.profileSetup_phoneHint,
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
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButtons(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
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
                child: Center(
                  child: Text(
                    l10n.common_later,
                    style: const TextStyle(
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
                child: Center(
                  child: Text(
                    l10n.profileSetup_complete,
                    style: const TextStyle(
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

  Future<void> _handleEditPhoto() async {
    final file = await ImageCropHelper.pickAndCropImage(context);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final userId = TokenService.instance.userId;
    if (userId != null) {
      await LocalImageStorageService.instance.saveImage(
        ownerType: ImageOwnerType.userProfile,
        ownerId: userId,
        imageBytes: bytes,
      );
    }
    if (!mounted) return;
    setState(() {
      _selectedImage = file;
      _savedImageBytes = bytes;
    });
  }

  void _showGenderPicker(AppLocalizations l10n) {
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    l10n.profileSetup_genderSelectTitle,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.35,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    l10n.profileSetup_genderMale,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedGender = 'male');
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: Text(
                    l10n.profileSetup_genderFemale,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  onTap: () {
                    setState(() => _selectedGender = 'female');
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
    // 다음에 - 펫 등록 화면으로 이동 (초기 설정 플로우)
    context.goNamed(RouteNames.petAdd, extra: {'isInitialSetup': true});
  }

  Future<void> _handleComplete() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      await _authService.updateProfile(
        nickname: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
      );
      if (!mounted) return;
      // 프로필 저장 후 펫 등록 화면으로 이동 (초기 설정 플로우)
      context.goNamed(RouteNames.petAdd, extra: {'isInitialSetup': true});
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.profileSetup_saveError);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
