import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../models/weight_record.dart';
import '../../services/weight/weight_service.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../services/analytics/analytics_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/analog_time_picker.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

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
  final _petCache = PetLocalCacheService.instance;
  bool _isLoading = false;
  TimeOfDay _selectedTime = TimeOfDay.now();
  double _sheetHeight = 0;
  final double _peekHeight = 260.0;
  double _expandedHeight = 0;
  int _bcsLevel = 3;
  double _sliderWeight = 65;
  String? _activePetId;

  @override
  void initState() {
    super.initState();
    _weightController.addListener(_onWeightChanged);
    Future.microtask(() async {
      await _loadActivePet();
    });
  }

  @override
  void dispose() {
    _weightController.removeListener(_onWeightChanged);
    _weightController.dispose();
    super.dispose();
  }

  void _onWeightChanged() {
    final weight = double.tryParse(_weightController.text);
    if (weight != null) {
      final double clamped = weight.clamp(40, 90).toDouble();
      final mappedLevel = _mapWeightToBcsLevel(clamped);
      if (!mounted) return;
      setState(() {
        _sliderWeight = clamped;
        _bcsLevel = mappedLevel;
      });
    } else {
      if (mounted) setState(() {});
    }
  }

  /// 활성 펫 ID 로드
  Future<void> _loadActivePet() async {
    try {
      final activePet = await _petCache.getActivePet();
      if (activePet != null && mounted) {
        setState(() {
          _activePetId = activePet.id;
        });
      }
    } catch (e) {
      // 에러 처리는 saveWeightRecord에서 사용자에게 알림
    }
  }

  /// 저장 버튼 클릭
  Future<void> _onSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_activePetId == null) {
      final l10n = AppLocalizations.of(context);
      AppSnackBar.warning(context, message: l10n.error_noPetFound);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final weight = double.parse(_weightController.text);
      final record = WeightRecord(
        petId: _activePetId!,
        date: widget.date,
        weight: weight,
        recordedHour: _selectedTime.hour,
        recordedMinute: _selectedTime.minute,
      );

      // 로컬 캐시에 먼저 저장
      await _weightService.saveLocalWeightRecord(record);
      // 백엔드 API에도 저장
      try {
        await _weightService.saveWeightRecord(record);
      } catch (_) {
        debugPrint('[WeightAdd] 백엔드 저장 실패, 로컬에만 저장됨');
      }

      debugPrint('[WeightAdd] Save success, mounted=$mounted');
      if (mounted) {
        // 성공 메시지
        final l10n = AppLocalizations.of(context);
        debugPrint('[WeightAdd] Showing success snackbar...');
        AppSnackBar.success(context, message: l10n.weight_recordSuccess);
        AnalyticsService.instance.logWeightRecorded(_activePetId!);
        debugPrint('[WeightAdd] Snackbar shown, waiting 1.2s before pop...');

        // 스낵바를 사용자가 확인할 수 있도록 딜레이 후 이전 화면으로 돌아감
        await Future.delayed(const Duration(milliseconds: 1200));
        debugPrint('[WeightAdd] Delay done, mounted=$mounted, popping...');
        if (mounted) context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        debugPrint('[WeightAdd] Save error: $e');
        AppSnackBar.error(
          context,
          message: ErrorHandler.getUserMessage(e, l10n, context: ErrorContext.weightSave),
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
    final l10n = AppLocalizations.of(context);
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
          l10n.weight_title,
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
            final padding = MediaQuery.of(context).padding;
            final calculatedExpanded = constraints.maxHeight * 0.6;
            final maxHeightLimit = constraints.maxHeight - AppSpacing.md;
            final safeUpperBound = maxHeightLimit < _peekHeight ? _peekHeight : maxHeightLimit;
            _expandedHeight = calculatedExpanded.clamp(_peekHeight, safeUpperBound);
            if (_sheetHeight == 0) {
              _sheetHeight = _expandedHeight;
            } else {
              _sheetHeight = _sheetHeight.clamp(_peekHeight, _expandedHeight);
            }

            return Form(
              key: _formKey,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.md,
                        top: AppSpacing.xl,
                        bottom: _peekHeight + AppSpacing.xl,
                      ),
                      child: _buildTopContent(),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildBottomSheet(MediaQuery.of(context).size, padding),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopContent() {
    final l10n = AppLocalizations.of(context);
    final displayWeight = _weightController.text.isEmpty
        ? '0.00'
        : _weightController.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.weight_bodyWeight,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.nearBlack,
              ),
            ),
            Text(
              '$displayWeight g',
              style: AppTypography.h3.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.brandPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Text(
              'BCS*',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.nearBlack,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.info_outline, color: AppColors.brandPrimary, size: 18),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: SizedBox(
            height: 160,
            child: SvgPicture.asset(
              'assets/images/login_bird.svg',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              _getBcsDescription(_bcsLevel),
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mediumGray,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildBcsScale(l10n),
      ],
    );
  }

  Widget _buildBcsScale(AppLocalizations l10n) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Row(
              children: List.generate(5, (index) {
                final isActive = index < _bcsLevel;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    color: isActive ? AppColors.brandPrimary : AppColors.lightGray,
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbColor: Colors.white,
                  trackShape: const RoundedRectSliderTrackShape(),
                  inactiveTickMarkColor: Colors.transparent,
                  activeTickMarkColor: Colors.transparent,
                ),
                child: Slider(
                  value: _sliderWeight,
                  min: 40,
                  max: 90,
                  divisions: 50,
                  onChanged: (value) {
                    final newWeight = value.roundToDouble();
                    if ((newWeight - _sliderWeight).abs() <= 0.1) return;
                    setState(() {
                      _sliderWeight = newWeight;
                      final formatted = newWeight.toStringAsFixed(1);
                      if (_weightController.text != formatted) {
                        _weightController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                      _bcsLevel = _mapWeightToBcsLevel(newWeight);
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.bhi_stageNumber(_bcsLevel),
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(Size size, EdgeInsets padding) {
    return GestureDetector(
      onVerticalDragUpdate: (details) {
        setState(() {
          _sheetHeight -= details.delta.dy;
          _sheetHeight = _sheetHeight.clamp(_peekHeight, _expandedHeight);
        });
      },
      onVerticalDragEnd: (details) {
        setState(() {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! < -500) {
              _sheetHeight = _expandedHeight;
              return;
            } else if (details.primaryVelocity! > 500) {
              _sheetHeight = _peekHeight;
              return;
            }
          }

          final midPoint = (_peekHeight + _expandedHeight) / 2;
          _sheetHeight = _sheetHeight > midPoint ? _expandedHeight : _peekHeight;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        height: _sheetHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.lg),
            topRight: Radius.circular(AppRadius.lg),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _sheetHeight = _sheetHeight == _peekHeight ? _expandedHeight : _peekHeight;
                });
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.lightGray,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: padding.bottom + AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDateCard(),
                    const SizedBox(height: AppSpacing.md),
                    _buildTimeCard(),
                    const SizedBox(height: AppSpacing.xl),
                    _buildWeightField(),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSaveButton(size),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    final l10n = AppLocalizations.of(context);
    final isAM = _selectedTime.hour < 12;
    final displayHour = _selectedTime.hour == 0
        ? 12
        : (_selectedTime.hour > 12 ? _selectedTime.hour - 12 : _selectedTime.hour);
    final period = isAM ? l10n.weight_amPeriod : l10n.weight_pmPeriod;
    final timeText = '$period $displayHour:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () async {
        final picked = await showAnalogTimePicker(
          context: context,
          initialTime: _selectedTime,
        );
        if (picked != null && mounted) {
          setState(() {
            _selectedTime = picked;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.lightGray),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 20,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              l10n.weight_selectTime,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mediumGray,
              ),
            ),
            const Spacer(),
            Text(
              timeText,
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.nearBlack,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mediumGray,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateCard() {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDateDisplay(widget.date),
            style: AppTypography.h5.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _formatLunarDisplay(widget.date),
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.lightGray,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.mediumGray, style: BorderStyle.solid, width: 1.5),
                  ),
                  child: const Icon(Icons.add, color: AppColors.mediumGray),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.weight_addStickerHint,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightField() {
    final l10n = AppLocalizations.of(context);
    return TextFormField(
      controller: _weightController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onTapOutside: (event) => FocusScope.of(context).unfocus(),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
      ],
      style: AppTypography.h3.copyWith(
        color: AppColors.nearBlack,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: l10n.weight_inputLabel,
        labelStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.mediumGray,
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
          return l10n.validation_enterWeight;
        }
        final weight = double.tryParse(value);
        if (weight == null) {
          return l10n.validation_enterValidNumber;
        }
        if (weight <= 0) {
          return l10n.validation_weightGreaterThanZero;
        }
        return null;
      },
    );
  }

  Widget _buildSaveButton(Size size) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: _isLoading ? null : _onSave,
      child: Container(
        width: size.width,
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
                l10n.btn_saveRecord,
                textAlign: TextAlign.center,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  String _formatDateDisplay(DateTime date) {
    final l10n = AppLocalizations.of(context);
    final weekdays = [
      l10n.datetime_weekdayFull_sun,
      l10n.datetime_weekdayFull_mon,
      l10n.datetime_weekdayFull_tue,
      l10n.datetime_weekdayFull_wed,
      l10n.datetime_weekdayFull_thu,
      l10n.datetime_weekdayFull_fri,
      l10n.datetime_weekdayFull_sat,
    ];
    final weekday = weekdays[(date.weekday % 7)];
    return '${date.day} $weekday';
  }

  int _mapWeightToBcsLevel(double weight) {
    if (weight < 50) {
      return 1;
    } else if (weight < 60) {
      return 2;
    } else if (weight < 70) {
      return 3;
    } else if (weight < 80) {
      return 4;
    } else if (weight < 90) {
      return 5;
    } else {
      return 5;
    }
  }

  String _getBcsDescription(int level) {
    final l10n = AppLocalizations.of(context);
    switch (level) {
      case 1:
        return l10n.weight_bcs1;
      case 2:
        return l10n.weight_bcs2;
      case 3:
        return l10n.weight_bcs3;
      case 4:
        return l10n.weight_bcs4;
      case 5:
      default:
        return l10n.weight_bcs5;
    }
  }
  String _formatLunarDisplay(DateTime date) {
    final l10n = AppLocalizations.of(context);
    final lunarMonth = (date.month - 1) % 12 + 1;
    final lunarDay = ((date.day + 15 - 1) % 30) + 1;
    return l10n.datetime_lunar(lunarMonth, lunarDay);
  }
}
