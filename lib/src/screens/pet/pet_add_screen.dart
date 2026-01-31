import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/colors.dart';
import '../../models/pet.dart';
import '../../services/pet/pet_service.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../widgets/bottom_nav_bar.dart';

/// 반려동물 등록/수정 화면 - Figma 디자인 기반
class PetAddScreen extends StatefulWidget {
  final String? petId; // null이면 등록, 값이 있으면 수정

  const PetAddScreen({
    super.key,
    this.petId,
  });

  @override
  State<PetAddScreen> createState() => _PetAddScreenState();
}

class _PetAddScreenState extends State<PetAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _speciesController = TextEditingController();

  final _imagePicker = ImagePicker();
  File? _selectedImage;
  Uint8List? _savedImageBytes;
  String? _selectedGender;
  String? _selectedGrowthStage;
  DateTime? _selectedBirthDate;
  DateTime? _selectedAdoptionDate;

  bool _isLoading = false;
  bool _isLoadingData = false;
  final _petCache = PetLocalCacheService();
  final _petService = PetService();
  Pet? _existingPet;

  final List<String> _genderOptions = ['수컷', '암컷', '모름'];
  final List<String> _growthStageOptions = ['빠른성장', '후속성장', '청년'];

  @override
  void initState() {
    super.initState();
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
      _selectedGender = _mapGenderToDisplay(pet.gender);
      _selectedGrowthStage = _mapGrowthStageToDisplay(pet.growthStage);
      _selectedBirthDate = pet.birthDate;

      // 로컬 저장된 펫 이미지 로드
      final imageBytes = await LocalImageStorageService.instance.getImage(
        ownerType: ImageOwnerType.petProfile,
        ownerId: pet.id,
      );
      _savedImageBytes = imageBytes;

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('펫 정보를 불러오는데 실패했습니다.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  String? _mapGenderToDisplay(String? gender) {
    switch (gender) {
      case 'male':
        return '수컷';
      case 'female':
        return '암컷';
      case 'unknown':
        return '모름';
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _speciesController.dispose();
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

    try {
      final petName = _nameController.text.trim().isEmpty
          ? '새'
          : _nameController.text.trim();
      final species = _speciesController.text.trim();
      final gender = _mapGenderValue(_selectedGender);
      final growthStage = _mapGrowthStageValue(_selectedGrowthStage);
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
          species: species.isEmpty ? '새' : species,
          breed: species.isEmpty ? null : species,
          birthDate: _selectedBirthDate,
          gender: gender,
          growthStage: growthStage,
          weight: weightValue,
          adoptionDate: _selectedAdoptionDate,
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(_existingPet != null ? '수정되었습니다.' : '등록되었습니다.')),
      );
      context.pop(true); // 결과 반환하여 이전 화면에서 새로고침 가능하게
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 중 오류가 발생했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _mapGrowthStageToDisplay(String? stage) {
    switch (stage) {
      case 'rapid_growth':
        return '빠른성장';
      case 'post_growth':
        return '후속성장';
      case 'adult':
        return '청년';
      default:
        return null;
    }
  }

  String? _mapGrowthStageValue(String? stage) {
    switch (stage) {
      case '빠른성장':
        return 'rapid_growth';
      case '후속성장':
        return 'post_growth';
      case '청년':
        return 'adult';
      default:
        return null;
    }
  }

  String? _mapGenderValue(String? gender) {
    switch (gender) {
      case '수컷':
        return 'male';
      case '암컷':
        return 'female';
      case '모름':
        return 'unknown';
      default:
        return null;
    }
  }

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
                                ? Center(
                                    child: SvgPicture.asset(
                                      'assets/images/pet_profile.svg',
                                      width: 60,
                                      height: 60,
                                      fit: BoxFit.contain,
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
                        hintText: '이름을 입력해 주세요',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '이름을 입력해 주세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // 성별
                      _buildDropdownField(
                        value: _selectedGender,
                        hint: '성별을 선택해 주세요',
                        items: _genderOptions,
                        onChanged: (value) {
                          setState(() => _selectedGender = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      // 몸무게
                      _buildTextField(
                        controller: _weightController,
                        hintText: '몸무게',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      // 생일
                      _buildDateField(
                        hint: '생일',
                        selectedDate: _selectedBirthDate,
                        onTap: () => _selectDate(context, true),
                      ),
                      const SizedBox(height: 16),
                      // 가족이 된 날
                      _buildDateField(
                        hint: '가족이 된 날',
                        selectedDate: _selectedAdoptionDate,
                        onTap: () => _selectDate(context, false),
                      ),
                      const SizedBox(height: 16),
                      // 종
                      _buildTextField(
                        controller: _speciesController,
                        hintText: '종',
                      ),
                      const SizedBox(height: 16),
                      // 성장 단계 (새 전용)
                      _buildGrowthStageDropdown(),
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
                      : const Text(
                          '저장',
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
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF97928A), width: 1),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
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
            contentPadding: EdgeInsets.zero,
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return GestureDetector(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('성별 선택'),
            children: items.map((item) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Text(item),
              );
            }).toList(),
          ),
        );
        if (selected != null) {
          onChanged(selected);
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF97928A), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value ?? hint,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: value == null
                      ? const Color(0xFF97928A)
                      : const Color(0xFF1A1A1A),
                  letterSpacing: -0.35,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF97928A),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrowthStageDropdown() {
    return GestureDetector(
      onTap: () async {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('성장 단계 선택'),
            children: _growthStageOptions.map((item) {
              return SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Text(item),
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
          border: Border.all(color: const Color(0xFF97928A), width: 1),
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedGrowthStage ?? '성장 단계를 선택해 주세요',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _selectedGrowthStage == null
                      ? const Color(0xFF97928A)
                      : const Color(0xFF1A1A1A),
                  letterSpacing: -0.35,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF97928A),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF97928A), width: 1),
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
                  color: selectedDate == null
                      ? const Color(0xFF97928A)
                      : const Color(0xFF1A1A1A),
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
