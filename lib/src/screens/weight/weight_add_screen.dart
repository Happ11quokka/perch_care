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
import '../../widgets/bottom_nav_bar.dart';

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
  final _petCache = PetLocalCacheService();
  bool _isLoading = false;
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
      await _loadExistingRecord();
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

  /// 기존 기록이 있으면 로드
  Future<void> _loadExistingRecord() async {
    if (_activePetId == null) return;

    final existingRecord = await _weightService.fetchLocalRecordByDate(
      widget.date,
      petId: _activePetId,
    );

    if (existingRecord != null && mounted) {
      setState(() {
        _weightController.text = existingRecord.weight.toStringAsFixed(1);
        _sliderWeight = existingRecord.weight.clamp(40, 90).toDouble();
        _bcsLevel = _mapWeightToBcsLevel(existingRecord.weight);
      });
    } else {
      _sliderWeight = _sliderWeight.clamp(40, 90);
    }
  }

  /// 저장 버튼 클릭
  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_activePetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '활성 펫을 찾을 수 없습니다.',
            style: AppTypography.bodyMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
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
      );

      // 로컬 캐시에 먼저 저장
      await _weightService.saveLocalWeightRecord(record);
      // 백엔드 API에도 저장
      try {
        await _weightService.saveWeightRecord(record);
      } catch (_) {
        debugPrint('[WeightAdd] 백엔드 저장 실패, 로컬에만 저장됨');
      }

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
          '체중',
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
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  Widget _buildTopContent() {
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
              '몸무게*',
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
        _buildBcsScale(),
      ],
    );
  }

  Widget _buildBcsScale() {
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
          '$_bcsLevel단계',
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
      onTap: () {
        setState(() {
          _sheetHeight = _sheetHeight == _peekHeight ? _expandedHeight : _peekHeight;
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
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(2.5),
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

  Widget _buildDateCard() {
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
                  '여기를 눌러 스티커를 추가해 보세요.',
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
    return TextFormField(
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
        labelText: '체중 입력 (g)',
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
    );
  }

  Widget _buildSaveButton(Size size) {
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
                '저장하기',
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
    final weekdays = ['일요일', '월요일', '화요일', '수요일', '목요일', '금요일', '토요일'];
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
    switch (level) {
      case 1:
        return '뼈가 쉽게 만져지고 옆에서 봐도 매우 마른 모습이에요.\n조금 더 영양을 챙겨 주세요.';
      case 2:
        return '갈비뼈가 잘 느껴지고 얇은 실루엣입니다.\n체중이 낮아진 편이라 조금 더 먹이를 늘려 주세요.';
      case 3:
        return '갈비뼈가 보이진 않지만 살짝 만지면 쉽게 느껴져요.\n옆에서 봤을 때 배가 쑥 들어간 부분이 보여요.';
      case 4:
        return '갈비뼈가 만져지지만 살짝 지방층이 느껴져요.\n옆모습이 둥글게 보이고 체중이 살짝 늘었어요.';
      case 5:
      default:
        return '갈비뼈가 잘 만져지지 않고 옆모습이 동그랗게 보입니다.\n먹이량을 줄이고 활동량을 늘려 주세요.';
    }
  }
  String _formatLunarDisplay(DateTime date) {
    final lunarMonth = (date.month - 1) % 12 + 1;
    final lunarDay = ((date.day + 15 - 1) % 30) + 1;
    return '음력 $lunarMonth월 $lunarDay일';
  }
}
