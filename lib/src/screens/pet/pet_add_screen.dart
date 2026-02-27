import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../models/pet.dart';
import '../../router/route_names.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/pet/pet_service.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../services/weight/weight_service.dart';
import '../../models/weight_record.dart';
import '../../utils/error_handler.dart';
import '../../widgets/app_snack_bar.dart';

/// 반려동물 등록/수정 화면 - Figma 디자인 기반
class PetAddScreen extends StatefulWidget {
  final String? petId; // null이면 등록, 값이 있으면 수정
  final bool isInitialSetup; // 첫 로그인 설정 플로우 여부

  const PetAddScreen({
    super.key,
    this.petId,
    this.isInitialSetup = false,
  });

  @override
  State<PetAddScreen> createState() => _PetAddScreenState();
}

class _PetAddScreenState extends State<PetAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _speciesController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _weightFocusNode = FocusNode();
  final _speciesFocusNode = FocusNode();

  bool _nameHasFocus = false;
  bool _weightHasFocus = false;
  bool _speciesHasFocus = false;

  final _imagePicker = ImagePicker();
  File? _selectedImage;
  Uint8List? _savedImageBytes;
  String? _selectedGender;
  String? _selectedGrowthStage;
  DateTime? _selectedBirthDate;
  DateTime? _selectedAdoptionDate;

  bool _isLoading = false;
  bool _isLoadingData = false;
  final _petCache = PetLocalCacheService.instance;
  final _petService = PetService.instance;
  Pet? _existingPet;

  // 필드별 검증 에러 추적
  final Map<String, String?> _fieldErrors = {};

  // Raw values for gender and growth stage
  static const List<String> _genderValues = ['male', 'female', 'unknown'];
  static const List<String> _growthStageValues = ['rapid_growth', 'post_growth', 'adult'];

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() => setState(() => _nameHasFocus = _nameFocusNode.hasFocus));
    _weightFocusNode.addListener(() => setState(() => _weightHasFocus = _weightFocusNode.hasFocus));
    _speciesFocusNode.addListener(() => setState(() => _speciesHasFocus = _speciesFocusNode.hasFocus));
    if (widget.petId != null) {
      _loadExistingPet();
    }
  }

  Future<void> _loadExistingPet() async {
    setState(() => _isLoadingData = true);
    try {
      final pet = await _petService.getPetById(widget.petId!);
      if (pet == null) throw Exception('Pet not found');

      _existingPet = pet;
      _nameController.text = pet.name;
      _speciesController.text = pet.breed ?? '';
      _selectedGender = pet.gender;
      _selectedGrowthStage = pet.growthStage;
      _selectedBirthDate = pet.birthDate;
      _selectedAdoptionDate = pet.adoptionDate;
      if (pet.weight != null) {
        _weightController.text = pet.weight!.toStringAsFixed(1);
      }

      // 로컬 저장된 펫 이미지 로드
      final imageBytes = await LocalImageStorageService.instance.getImage(
        ownerType: ImageOwnerType.petProfile,
        ownerId: pet.id,
      );
      _savedImageBytes = imageBytes;

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AppSnackBar.error(context, message: l10n.pet_loadError);
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
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

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _speciesController.dispose();
    _nameFocusNode.dispose();
    _weightFocusNode.dispose();
    _speciesFocusNode.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isBirthDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF9A42),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1A1A1A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _selectedBirthDate = picked;
        } else {
          _selectedAdoptionDate = picked;
        }
      });
    }
  }

  Future<void> _handlePickImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context);

    try {
      final petName = _nameController.text.trim().isEmpty
          ? l10n.pet_defaultName
          : _nameController.text.trim();
      final species = _speciesController.text.trim();
      final gender = _selectedGender;
      final growthStage = _selectedGrowthStage;
      final weightText = _weightController.text.trim();
      final double? weightValue = weightText.isNotEmpty ? double.tryParse(weightText) : null;

      Pet savedPet;

      if (_existingPet != null) {
        // 기존 펫 수정
        savedPet = await _petService.updatePet(
          petId: _existingPet!.id,
          name: petName,
          species: species.isEmpty ? null : species,
          breed: species.isEmpty ? null : species,
          birthDate: _selectedBirthDate,
          gender: gender,
          growthStage: growthStage,
          weight: weightValue,
          adoptionDate: _selectedAdoptionDate,
        );
      } else {
        // 새 펫 생성
        savedPet = await _petService.createPet(
          name: petName,
          species: species.isEmpty ? l10n.pet_defaultName : species,
          breed: species.isEmpty ? null : species,
          birthDate: _selectedBirthDate,
          gender: gender,
          growthStage: growthStage,
          weight: weightValue,
          adoptionDate: _selectedAdoptionDate,
        );
      }

      // 새 펫 생성 시 초기 체중을 WeightRecord로 자동 생성
      if (weightValue != null && _existingPet == null) {
        try {
          final weightService = WeightService();
          final record = WeightRecord(
            petId: savedPet.id,
            date: DateTime.now(),
            weight: weightValue,
          );
          await weightService.saveLocalWeightRecord(record);
          try {
            await weightService.saveWeightRecord(record);
          } catch (_) {
            debugPrint('[PetAdd] Backend weight save failed, local only');
          }
        } catch (e) {
          debugPrint('[PetAdd] Initial weight record failed: $e');
        }
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

      // 로컬 캐시도 업데이트
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

      AppSnackBar.success(context, message: _existingPet != null ? l10n.common_updated : l10n.common_registered);
      if (_existingPet == null) {
        AnalyticsService.instance.logPetRegistered(_speciesController.text.trim());
      }

      if (widget.isInitialSetup) {
        context.goNamed(RouteNames.home);
      } else {
        context.pop(true); // 결과 반환하여 이전 화면에서 새로고침 가능하게
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[PetAdd] Save error: $e');
      AppSnackBar.error(
        context,
        message: ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.petSave),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _mapGrowthStageToDisplay(String? stage, AppLocalizations l10n) {
    switch (stage) {
      case 'rapid_growth':
        return l10n.pet_growthRapid;
      case 'post_growth':
        return l10n.pet_growthPost;
      case 'adult':
        return l10n.pet_growthAdult;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                onPressed: () => context.pop(),
              ),
        automaticallyImplyLeading: !widget.isInitialSetup,
        centerTitle: true,
        title: Text(
          l10n.pet_profile,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 34),
                      // 프로필 이미지
                      Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFD9D9D9),
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
                                ? const Center(
                                    child: Icon(
                                      Icons.pets,
                                      size: 60,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: _handlePickImage,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFFF9A42),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // 이름
                      _buildTextField(
                        controller: _nameController,
                        focusNode: _nameFocusNode,
                        hasFocus: _nameHasFocus,
                        hintText: l10n.pet_name_hint,
                        fieldKey: 'name',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.pet_name_hint;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // 성별
                      _buildGenderDropdown(l10n),
                      const SizedBox(height: 16),
                      // 몸무게
                      _buildTextField(
                        controller: _weightController,
                        focusNode: _weightFocusNode,
                        hasFocus: _weightHasFocus,
                        hintText: l10n.pet_weight_hint,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      // 생일
                      _buildDateField(
                        hint: l10n.pet_birthday_hint,
                        selectedDate: _selectedBirthDate,
                        onTap: () => _selectDate(context, true),
                      ),
                      const SizedBox(height: 16),
                      // 가족이 된 날
                      _buildDateField(
                        hint: l10n.pet_adoptionDate_hint,
                        selectedDate: _selectedAdoptionDate,
                        onTap: () => _selectDate(context, false),
                      ),
                      const SizedBox(height: 16),
                      // 종
                      _buildTextField(
                        controller: _speciesController,
                        focusNode: _speciesFocusNode,
                        hasFocus: _speciesHasFocus,
                        hintText: l10n.pet_species_hint,
                      ),
                      const SizedBox(height: 16),
                      // 성장 단계 (새 전용)
                      _buildGrowthStageDropdown(l10n),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // 저장 버튼
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
            child: GestureDetector(
              onTap: _isLoading ? null : _handleSave,
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
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          l10n.common_save,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasFocus,
    required String hintText,
    String? fieldKey,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final hasValue = controller.text.isNotEmpty;
    final isActive = hasFocus || hasValue;
    final errorText = fieldKey != null ? _fieldErrors[fieldKey] : null;
    final hasError = errorText != null;
    final borderColor = hasError
        ? const Color(0xFFFF572D)
        : isActive
            ? const Color(0xFFFF9A42)
            : const Color(0xFF97928A);
    final bgColor = (hasFocus && hasValue)
        ? const Color(0xFFFF9A42).withValues(alpha: 0.1)
        : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: borderColor, width: 1),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              validator: (value) {
                final result = validator?.call(value);
                if (fieldKey != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _fieldErrors[fieldKey] != result) {
                      setState(() => _fieldErrors[fieldKey] = result);
                    }
                  });
                }
                return result;
              },
              onChanged: (_) {
                if (fieldKey != null && _fieldErrors[fieldKey] != null) {
                  setState(() => _fieldErrors[fieldKey] = null);
                } else {
                  setState(() {});
                }
              },
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.35,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF97928A),
                  letterSpacing: -0.35,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                errorStyle: const TextStyle(height: 0, fontSize: 0),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              errorText,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFFFF572D),
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGenderDropdown(AppLocalizations l10n) {
    final displayValue = _mapGenderToDisplay(_selectedGender, l10n);
    final hasValue = _selectedGender != null;
    final borderColor = hasValue ? const Color(0xFFFF9A42) : const Color(0xFF97928A);

    return GestureDetector(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.dialog_selectGender),
            children: _genderValues.map((rawValue) {
              final displayText = _mapGenderToDisplay(rawValue, l10n) ?? rawValue;
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, rawValue),
                child: Text(displayText),
              );
            }).toList(),
          ),
        );
        if (selected != null) {
          setState(() => _selectedGender = selected);
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayValue ?? l10n.pet_gender_hint,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: hasValue
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF97928A),
                  letterSpacing: -0.35,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: hasValue ? const Color(0xFFFF9A42) : const Color(0xFF97928A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthStageDropdown(AppLocalizations l10n) {
    final displayValue = _mapGrowthStageToDisplay(_selectedGrowthStage, l10n);
    final hasValue = _selectedGrowthStage != null;
    final borderColor = hasValue ? const Color(0xFFFF9A42) : const Color(0xFF97928A);

    return GestureDetector(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(l10n.dialog_selectGrowthStage),
            children: _growthStageValues.map((rawValue) {
              final displayText = _mapGrowthStageToDisplay(rawValue, l10n) ?? rawValue;
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, rawValue),
                child: Text(displayText),
              );
            }).toList(),
          ),
        );
        if (selected != null) {
          setState(() => _selectedGrowthStage = selected);
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayValue ?? l10n.pet_growthStage_hint,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: hasValue
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF97928A),
                  letterSpacing: -0.35,
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: hasValue ? const Color(0xFFFF9A42) : const Color(0xFF97928A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String hint,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    final hasValue = selectedDate != null;
    final borderColor = hasValue ? const Color(0xFFFF9A42) : const Color(0xFF97928A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                selectedDate == null
                    ? hint
                    : '${selectedDate.year}.${selectedDate.month.toString().padLeft(2, '0')}.${selectedDate.day.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: hasValue
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFF97928A),
                  letterSpacing: -0.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
