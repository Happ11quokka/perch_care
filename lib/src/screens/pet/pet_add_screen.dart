import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../services/pet/pet_service.dart';
import '../../router/route_names.dart';

class PetAddScreen extends StatefulWidget {
  const PetAddScreen({super.key});

  @override
  State<PetAddScreen> createState() => _PetAddScreenState();
}

class _PetAddScreenState extends State<PetAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _petService = PetService();

  // Form controllers
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();

  // Form values - 앵무새 전용이므로 species는 항상 'bird'
  final String _selectedSpecies = 'bird';
  String _selectedGender = 'unknown';
  DateTime? _selectedBirthDate;

  bool _isLoading = false;

  // Gender options
  final Map<String, String> _genderOptions = {
    'male': '수컷',
    'female': '암컷',
    'unknown': '모름',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.brandPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.nearBlack,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _petService.createPet(
        name: _nameController.text.trim(),
        species: _selectedSpecies,
        breed: _breedController.text.trim().isEmpty
            ? null
            : _breedController.text.trim(),
        birthDate: _selectedBirthDate,
        gender: _selectedGender,
      );

      if (mounted) {
        // Navigate to home screen
        context.go(RouteNames.home);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_nameController.text.trim()}이(가) 등록되었습니다!'),
            backgroundColor: AppColors.brandPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('등록 중 오류가 발생했습니다: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '앵무새 등록하기',
          style: AppTypography.h5.copyWith(color: AppColors.brandPrimary),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header text
                Text(
                  '소중한 앵무새의\n정보를 입력해주세요',
                  style: AppTypography.h4.copyWith(
                    color: AppColors.nearBlack,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),

                // Pet name input
                _buildLabel('이름 *'),
                SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _nameController,
                  hintText: '예: 사랑이',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '이름을 입력해주세요';
                    }
                    return null;
                  },
                ),
                SizedBox(height: AppSpacing.lg),

                // Breed input (앵무새 품종)
                _buildLabel('품종 (선택)'),
                SizedBox(height: AppSpacing.sm),
                _buildTextField(
                  controller: _breedController,
                  hintText: '예: 유황앵무, 코뉴어, 사랑앵무, 회색앵무 등',
                ),
                SizedBox(height: AppSpacing.lg),

                // Birth date picker
                _buildLabel('생년월일 (선택)'),
                SizedBox(height: AppSpacing.sm),
                _buildDatePicker(),
                SizedBox(height: AppSpacing.lg),

                // Gender selector
                _buildLabel('성별'),
                SizedBox(height: AppSpacing.sm),
                _buildDropdown(
                  value: _selectedGender,
                  items: _genderOptions,
                  onChanged: (value) {
                    setState(() {
                      _selectedGender = value!;
                    });
                  },
                ),
                SizedBox(height: screenHeight * 0.06),

                // Submit button
                _buildSubmitButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTypography.labelLarge.copyWith(
        color: AppColors.nearBlack,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      textInputAction: TextInputAction.next,
      enableIMEPersonalizedLearning: true,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.nearBlack),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.lightGray,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.brandPrimary, width: 2),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.entries.map((entry) {
          return DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value),
          );
        }).toList(),
        onChanged: onChanged,
        style: AppTypography.bodyLarge.copyWith(color: AppColors.nearBlack),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          border: InputBorder.none,
        ),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.brandPrimary),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: _selectBirthDate,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.brandPrimary, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedBirthDate == null
                  ? '생년월일을 선택해주세요'
                  : '${_selectedBirthDate!.year}년 ${_selectedBirthDate!.month}월 ${_selectedBirthDate!.day}일',
              style: AppTypography.bodyLarge.copyWith(
                color: _selectedBirthDate == null
                    ? AppColors.lightGray
                    : AppColors.nearBlack,
              ),
            ),
            const Icon(Icons.calendar_today, color: AppColors.brandPrimary),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gradientTop, AppColors.brandPrimary],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  '등록하기',
                  style: AppTypography.labelLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
