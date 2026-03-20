import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../utils/image_crop_helper.dart';
import '../../theme/colors.dart';
import '../../models/pet.dart';
import '../../router/route_names.dart';
import '../../services/pet/pet_service.dart';
import '../../services/pet/pet_local_cache_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/pet_providers.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';

/// 반려동물 프로필 상세/편집 화면
class PetProfileDetailScreen extends ConsumerStatefulWidget {
  const PetProfileDetailScreen({super.key});

  @override
  ConsumerState<PetProfileDetailScreen> createState() => _PetProfileDetailScreenState();
}

class _PetProfileDetailScreenState extends ConsumerState<PetProfileDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _petCache = PetLocalCacheService.instance;
  final _petService = PetService.instance;

  File? _selectedImage;
  Uint8List? _savedImageBytes;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _speciesController = TextEditingController();
  String? _selectedGender;
  DateTime? _birthday;
  DateTime? _adoptionDate;
  String? _existingPetId;
  bool _isLoading = false;
  bool _isLoadingData = true;

  // Coach mark keys
  final GlobalKey _profileImageKey = GlobalKey();
  final GlobalKey _genderSelectorKey = GlobalKey();
  final GlobalKey _saveButtonKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadExistingPet();
  }

  String? _mapGenderToDisplay(String? gender, AppLocalizations l10n) {
    switch (gender) {
      case 'male':
        return l10n.pet_genderMale;
      case 'female':
        return l10n.pet_genderFemale;
      case 'unknown':
        return l10n.pet_genderUnknown;
      default:
        return null;
    }
  }

  Future<void> _loadExistingPet() async {
    try {
      // API에서 활성 펫 조회 (UUID 형식 보장)
      final apiPet = ref.read(activePetProvider).valueOrNull;
      if (!mounted) return;

      if (apiPet != null) {
        _existingPetId = apiPet.id;

        // 로컬 저장된 펫 이미지 로드
        final imageBytes = await LocalImageStorageService.instance.getImage(
          ownerType: ImageOwnerType.petProfile,
          ownerId: apiPet.id,
        );
        _savedImageBytes = imageBytes;

        // 로컬 캐시도 동기화
        await _petCache.upsertPet(
          PetProfileCache(
            id: apiPet.id,
            name: apiPet.name,
            species: apiPet.breed,
            gender: apiPet.gender,
            birthDate: apiPet.birthDate,
          ),
          setActive: true,
        );

        setState(() {
          _nameController.text = apiPet.name;
          _speciesController.text = apiPet.breed ?? '';
          _selectedGender = apiPet.gender;
          _birthday = apiPet.birthDate;
          _adoptionDate = apiPet.adoptionDate;
          if (apiPet.weight != null) {
            _weightController.text = apiPet.weight.toString();
          }
          _isLoadingData = false;
        });
      } else {
        // API에 활성 펫 없으면 신규 등록 모드
        if (mounted) setState(() => _isLoadingData = false);
      }
    } catch (_) {
      // API 실패 시 로컬 캐시 폴백
      try {
        final activePet = await _petCache.getActivePet();
        if (!mounted) return;
        if (activePet != null) {
          _existingPetId = activePet.id;
          setState(() {
            _nameController.text = activePet.name;
            _speciesController.text = activePet.species ?? '';
            _selectedGender = activePet.gender;
            _birthday = activePet.birthDate;
            _isLoadingData = false;
          });
        } else {
          setState(() => _isLoadingData = false);
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingData = false);
      }
    }

    _maybeShowCoachMarks();
  }

  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    final hasSeen = await service.hasSeen(CoachMarkService.screenPetProfileDetail);
    if (hasSeen || !mounted) return;

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final steps = <CoachMarkStep>[
      CoachMarkStep(
        targetKey: _profileImageKey,
        title: l10n.coach_petDetailImage_title,
        body: l10n.coach_petDetailImage_body,
      ),
      CoachMarkStep(
        targetKey: _genderSelectorKey,
        title: l10n.coach_petDetailInfo_title,
        body: l10n.coach_petDetailInfo_body,
      ),
      CoachMarkStep(
        targetKey: _saveButtonKey,
        title: l10n.coach_petDetailSave_title,
        body: l10n.coach_petDetailSave_body,
        isScrollable: false,
      ),
    ];

    if (mounted) {
      CoachMarkOverlay.show(
        context,
        scrollController: _scrollController,
        steps: steps,
        nextLabel: l10n.coach_next,
        gotItLabel: l10n.coach_gotIt,
        skipLabel: l10n.coach_skip,
        onComplete: () => service.markSeen(CoachMarkService.screenPetProfileDetail),
      );
    }
  }

  Future<void> _handlePickImage() async {
    final file = await ImageCropHelper.pickAndCropImage(context);
    if (file != null) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _nameController.dispose();
    _weightController.dispose();
    _speciesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoadingData
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            // 상단 앱바
            _buildAppBar(l10n),

            // 스크롤 가능한 컨텐츠
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 34),

                      // 프로필 이미지
                      _buildProfileImage(),

                      const SizedBox(height: 32),

                      // 입력 필드들
                      _buildInputFields(l10n),

                      const SizedBox(height: 32),

                      // 저장 버튼
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: _buildSaveButton(l10n),
                      ),

                      const SizedBox(height: 12),

                      // 삭제 버튼
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: GestureDetector(
                          onTap: _isLoading ? null : _handleDelete,
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFF572D)),
                            ),
                            child: Center(
                              child: Text(
                                l10n.pet_delete,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFF572D),
                                  letterSpacing: -0.45,
                                ),
                              ),
                            ),
                          ),
                        ),
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
    );
  }

  /// 상단 앱바
  Widget _buildAppBar(AppLocalizations l10n) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Stack(
        children: [
          // 뒤로가기 버튼
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.goNamed(RouteNames.home);
                }
              },
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
              l10n.pet_profile,
              style: TextStyle(
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
          key: _profileImageKey,
          clipBehavior: Clip.none,
          children: [
            // 프로필 이미지
            if (_selectedImage != null)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else if (_savedImageBytes != null)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: MemoryImage(_savedImageBytes!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
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
                onTap: _handlePickImage,
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
  Widget _buildInputFields(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // 이름
          _buildTextField(
            controller: _nameController,
            hintText: l10n.pet_name_hint,
          ),

          const SizedBox(height: 16),

          // 성별
          _buildGenderSelector(l10n),

          const SizedBox(height: 16),

          // 몸무게
          _buildTextField(
            controller: _weightController,
            hintText: l10n.pet_weight_hint,
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 16),

          // 생일
          _buildDateSelector(
            hintText: l10n.pet_birthday_hint,
            selectedDate: _birthday,
            onTap: () => _selectDate(context, isAdoptionDate: false),
          ),

          const SizedBox(height: 16),

          // 가족이 된 날
          _buildDateSelector(
            hintText: l10n.pet_adoptionDate_hint,
            selectedDate: _adoptionDate,
            onTap: () => _selectDate(context, isAdoptionDate: true),
          ),

          const SizedBox(height: 16),

          // 종
          _buildTextField(
            controller: _speciesController,
            hintText: l10n.pet_species_hint,
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
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF1A1A1A),
              height: 20 / 14,
              letterSpacing: -0.35,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
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
  Widget _buildGenderSelector(AppLocalizations l10n) {
    final displayGender = _mapGenderToDisplay(_selectedGender, l10n);
    return GestureDetector(
      key: _genderSelectorKey,
      onTap: () => _showGenderPicker(l10n),
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
              displayGender ?? l10n.pet_gender_hint,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: displayGender != null
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
  Widget _buildSaveButton(AppLocalizations l10n) {
    return Container(
      key: _saveButtonKey,
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
          onTap: _isLoading ? null : _handleSave,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    l10n.common_save,
                    style: TextStyle(
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
  void _showGenderPicker(AppLocalizations l10n) {
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
              title: Text(l10n.pet_genderMale),
              onTap: () {
                setState(() {
                  _selectedGender = 'male';
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.pet_genderFemale),
              onTap: () {
                setState(() {
                  _selectedGender = 'female';
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

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.pet_deleteConfirmTitle),
        content: Text(l10n.pet_deleteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.pet_deleteConfirmButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _petService.deletePet(_existingPetId!);
      AnalyticsService.instance.logPetDeleted();
      await _petCache.removePet(_existingPetId!);
      if (!mounted) return;
      final remainingPets = await _petCache.getPets();
      if (remainingPets.isNotEmpty) {
        ref.read(activePetProvider.notifier).switchPet(remainingPets.first.id);
      }
      if (!mounted) return;
      AppSnackBar.success(context, message: l10n.snackbar_deleted);
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.error_noPetFound);
    }
  }

  /// 저장 처리
  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context);

    try {
      final petName = _nameController.text.trim().isEmpty
          ? l10n.pet_defaultName
          : _nameController.text.trim();
      final species = _speciesController.text.trim();
      final gender = _selectedGender;
      final weightText = _weightController.text.trim();
      final double? weightValue = weightText.isNotEmpty ? double.tryParse(weightText) : null;

      Pet savedPet;

      if (_existingPetId != null) {
        // 서버에 수정
        savedPet = await _petService.updatePet(
          petId: _existingPetId!,
          name: petName,
          species: species.isEmpty ? null : species,
          breed: species.isEmpty ? null : species,
          birthDate: _birthday,
          gender: gender,
          weight: weightValue,
          adoptionDate: _adoptionDate,
        );
      } else {
        // 서버에 생성
        savedPet = await _petService.createPet(
          name: petName,
          species: species.isEmpty ? l10n.pet_defaultName : species,
          breed: species.isEmpty ? null : species,
          birthDate: _birthday,
          gender: gender,
          weight: weightValue,
          adoptionDate: _adoptionDate,
        );
      }

      // 이미지를 SQLite에 저장
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        await LocalImageStorageService.instance.saveImage(
          ownerType: ImageOwnerType.petProfile,
          ownerId: savedPet.id,
          imageBytes: bytes,
        );
      }

      // 로컬 캐시도 동기화
      await _petCache.upsertPet(
        PetProfileCache(
          id: savedPet.id,
          name: savedPet.name,
          species: savedPet.breed,
          gender: savedPet.gender,
          birthDate: savedPet.birthDate,
        ),
        setActive: true,
      );

      if (!mounted) return;
      AppSnackBar.success(context, message: l10n.common_saveSuccess);
      if (context.canPop()) {
        context.pop();
      } else {
        context.goNamed(RouteNames.home);
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[PetProfileDetail] Save error: $e');
      AppSnackBar.error(
        context,
        message: ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.petSave),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
