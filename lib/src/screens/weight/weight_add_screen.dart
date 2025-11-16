import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../models/weight_record.dart';
import '../../services/weight/weight_service.dart';

class WeightAddScreen extends StatefulWidget {
  final DateTime date;

  const WeightAddScreen({
    super.key,
    required this.date,
  });

  @override
  State<WeightAddScreen> createState() => _WeightAddScreenState();
}

class _WeightAddScreenState extends State<WeightAddScreen> {
  final _weightController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _weightService = WeightService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExistingRecord();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  /// 기존 기록이 있으면 로드
  void _loadExistingRecord() {
    final existingRecord = _weightService.getRecordByDate(widget.date);
    if (existingRecord != null) {
      _weightController.text = existingRecord.weight.toStringAsFixed(1);
    }
  }

  /// 저장 버튼 클릭
  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final weight = double.parse(_weightController.text);
      final record = WeightRecord(
        date: widget.date,
        weight: weight,
      );

      await _weightService.saveWeightRecord(record);

      if (mounted) {
        // 성공 메시지
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '오늘의 체중이 기록되었습니다!',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.brandPrimary,
            duration: const Duration(seconds: 2),
          ),
        );

        // 이전 화면으로 돌아가며 refresh 신호 전달
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '저장에 실패했습니다. 다시 시도해 주세요.',
              style: AppTypography.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.red,
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
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.nearBlack),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '체중 기록하기',
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.brandPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth > 600
                ? (constraints.maxWidth - 600) / 2
                : AppSpacing.md;

            return Padding(
              padding: EdgeInsets.only(
                left: horizontalPadding,
                right: horizontalPadding,
                top: AppSpacing.xl,
                bottom: padding.bottom + AppSpacing.md,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 날짜 표시
                    Center(
                      child: Text(
                        _formatDate(widget.date),
                        style: AppTypography.h4.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.nearBlack,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // 체중 입력 필드
                    Text(
                      '체중 (g)',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
                      ],
                      style: AppTypography.h3.copyWith(
                        color: AppColors.nearBlack,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: '57.9',
                        hintStyle: AppTypography.h3.copyWith(
                          color: AppColors.lightGray,
                          fontWeight: FontWeight.w400,
                        ),
                        suffixText: 'g',
                        suffixStyle: AppTypography.bodyLarge.copyWith(
                          color: AppColors.mediumGray,
                          fontWeight: FontWeight.w600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.lightGray),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                            color: AppColors.brandPrimary,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(color: AppColors.lightGray),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '체중을 입력해주세요.';
                        }
                        final weight = double.tryParse(value);
                        if (weight == null) {
                          return '올바른 숫자를 입력해주세요.';
                        }
                        if (weight <= 0) {
                          return '체중은 0보다 커야 합니다.';
                        }
                        return null;
                      },
                    ),

                    const Spacer(),

                    // 저장 버튼
                    GestureDetector(
                      onTap: _isLoading ? null : _onSave,
                      child: Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 600),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _isLoading
                                ? [AppColors.lightGray, AppColors.mediumGray]
                                : [AppColors.gradientTop, AppColors.brandPrimary],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: _isLoading
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: _isLoading
                            ? const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Text(
                                '저장하기',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 날짜 포맷팅 (예: 2023년 08월 12일 체중 기록)
  String _formatDate(DateTime date) {
    return '${date.year}년 ${date.month.toString().padLeft(2, '0')}월 ${date.day.toString().padLeft(2, '0')}일 체중 기록';
  }
}
