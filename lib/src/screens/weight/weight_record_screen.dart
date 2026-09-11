import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/weight_record.dart';
import '../../theme/colors.dart';
import '../../view_models/weight/weight_add_view_model.dart';
import '../../router/route_names.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/analog_time_picker.dart';
import '../../widgets/weight_range_indicator.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';
import '../../models/breed_standard.dart';
import '../../providers/pet_providers.dart';
import '../../providers/repository_providers.dart';
import '../../providers/service_providers.dart';
import '../../models/pet.dart';
import '../../../l10n/app_localizations.dart';

/// 활성 펫 구독 키 — 로딩 중(값 없음) / 에러(값 없음) / 펫 없음(null) / 펫 id·품종.
/// AsyncLoading.copyWithPrevious(이전 펫 유지)는 로딩으로 취급하지 않는다.
typedef _ActivePetKey = ({
  bool loading,
  bool failed,
  String? petId,
  String? breedId,
});

_ActivePetKey _activePetKey(AsyncValue<Pet?> s) {
  final pet = s.valueOrNull;
  return (
    loading: s.isLoading && !s.hasValue,
    failed: s.hasError && !s.hasValue,
    petId: pet?.id,
    breedId: pet?.breedId,
  );
}

class WeightRecordScreen extends ConsumerStatefulWidget {
  const WeightRecordScreen({super.key});

  @override
  ConsumerState<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends ConsumerState<WeightRecordScreen> {
  final _weightController = TextEditingController();
  final _weightFocusNode = FocusNode();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String? _activePetId;
  bool _isLoading = true;
  bool _isSaving = false;
  List<WeightRecord> _records = [];
  BreedStandard? _breedStandard;

  // 코치마크 GlobalKeys
  final _wciGaugeKey = GlobalKey();
  final _weightInputKey = GlobalKey();
  final _timeCardKey = GlobalKey();
  final _saveButtonKey = GlobalKey();

  /// 마지막으로 처리한 활성 펫 키 — 동일 키 재발행은 무시.
  _ActivePetKey? _lastPetKey;

  /// 로드 시퀀스 — 이전 펫의 in-flight 결과를 폐기하기 위한 가드.
  int _loadSeq = 0;
  bool _coachMarksChecked = false;

  @override
  void initState() {
    super.initState();
    // 초기값은 동기 read, 이후 변경은 build()의 ref.listen 으로 구독한다.
    _onActivePetChanged(_activePetKey(ref.read(activePetProvider)));
  }

  @override
  void dispose() {
    _weightController.dispose();
    _weightFocusNode.dispose();
    super.dispose();
  }

  /// 활성 펫 확정/전환 시 호출 — 로딩 중이면 대기, 펫이 바뀌면 재로드.
  void _onActivePetChanged(_ActivePetKey next) {
    if (next.loading) return;
    if (next == _lastPetKey) return;
    _lastPetKey = next;
    _activePetId = next.petId;
    _setLoading(true);
    _loadForPet(next);
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    setState(() => _isLoading = value);
  }

  /// 펫 확정/전환 시 품종 + 기록 재로드. provider 에러면 로컬 캐시 폴백.
  Future<void> _loadForPet(_ActivePetKey key) async {
    final seq = ++_loadSeq;
    var petId = key.petId;
    var breedId = key.breedId;
    if (petId == null && key.failed) {
      try {
        final cachedPet =
            await ref.read(petRepositoryProvider).getActivePetFromLocalCache();
        petId = cachedPet?.id;
        breedId = cachedPet?.breedId;
      } catch (_) {}
      if (!mounted || seq != _loadSeq) return;
      _activePetId = petId;
    }

    BreedStandard? breed;
    var records = <WeightRecord>[];
    if (petId != null) {
      if (breedId != null) {
        try {
          breed = await ref.read(breedServiceProvider).fetchBreedById(breedId);
        } catch (_) {}
      }
      try {
        records =
            await ref.read(weightRepositoryProvider).fetchLocal(petId: petId);
      } catch (_) {}
    }
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _breedStandard = breed;
      _records = records;
      _isLoading = false;
    });
    _syncWeightController();
    if (!_coachMarksChecked) {
      _coachMarksChecked = true;
      _maybeShowCoachMarks();
    }
  }

  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenWeightRecord)) return;
    await Future.delayed(AppDurations.coachMarkDelay);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    CoachMarkOverlay.show(
      context,
      steps: [
        CoachMarkStep(
          targetKey: _wciGaugeKey,
          title: l10n.coach_weightGauge_title,
          body: l10n.coach_weightGauge_body,
        ),
        CoachMarkStep(
          targetKey: _weightInputKey,
          title: l10n.coach_weightInput_title,
          body: l10n.coach_weightInput_body,
        ),
        CoachMarkStep(
          targetKey: _timeCardKey,
          title: l10n.coach_weightTime_title,
          body: l10n.coach_weightTime_body,
        ),
        CoachMarkStep(
          targetKey: _saveButtonKey,
          title: l10n.coach_weightSave_title,
          body: l10n.coach_weightSave_body,
          isScrollable: false,
        ),
      ],
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () => service.markSeen(CoachMarkService.screenWeightRecord),
    );
  }

  /// 저장 후 기록 재로드. 로드 중 펫이 바뀌면 결과 폐기.
  Future<void> _loadRecords() async {
    final petId = _activePetId;
    if (petId == null) return;
    final records =
        await ref.read(weightRepositoryProvider).fetchLocal(petId: petId);
    if (!mounted || petId != _activePetId) return;
    setState(() {
      _records = records;
    });
    _syncWeightController();
  }

  void _syncWeightController() {
    // 다중 기록이므로 기존 값 자동 로드하지 않음 (빈 상태로 새 기록 입력 대기)
    _weightController.clear();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
    });
    _syncWeightController();
  }

  /// 해당 날짜의 모든 기록 반환 (다중 기록 지원)
  List<WeightRecord> _recordsForDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return _records.where((record) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return recordDate == normalized;
    }).toList();
  }

  /// 해당 날짜의 일평균 체중 반환
  double? _dailyAverageForDate(DateTime date) {
    final dayRecords = _recordsForDate(date);
    if (dayRecords.isEmpty) return null;
    final sum = dayRecords.fold(0.0, (total, r) => total + r.weight);
    return sum / dayRecords.length;
  }

  /// 하위 호환용: 단일 기록 반환 (WCI 계산 등)
  WeightRecord? _recordForDate(DateTime date) {
    final dayRecords = _recordsForDate(date);
    if (dayRecords.isEmpty) return null;
    // 일평균을 가상 기록으로 반환
    final avg = _dailyAverageForDate(date)!;
    return dayRecords.first.copyWith(weight: avg);
  }

  WeightRecord? _baselineRecord(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final previous = _records.where((record) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      return recordDate.isBefore(normalized);
    }).toList()..sort((a, b) => b.date.compareTo(a.date));

    if (previous.isNotEmpty) {
      return previous.first;
    }
    return _recordForDate(date);
  }

  double? _calculateWci(WeightRecord? current, WeightRecord? baseline) {
    if (current == null || baseline == null) return null;
    if (baseline.weight == 0) return null;
    return ((current.weight - baseline.weight) / baseline.weight) * 100;
  }

  _WciLevel _resolveLevel(double? wci) {
    final l10n = AppLocalizations.of(context);
    if (wci == null) {
      return _WciLevel(
        level: 0,
        title: l10n.weight_level0Title,
        description: l10n.weight_level0Desc,
      );
    }
    if (wci <= -7) {
      return _WciLevel(
        level: 1,
        title: l10n.weight_level1Title,
        description: l10n.weight_level1Desc,
      );
    }
    if (wci <= -3) {
      return _WciLevel(
        level: 2,
        title: l10n.weight_level2Title,
        description: l10n.weight_level2Desc,
      );
    }
    if (wci < 3) {
      return _WciLevel(
        level: 3,
        title: l10n.weight_level3Title,
        description: l10n.weight_level3Desc,
      );
    }
    if (wci < 8) {
      return _WciLevel(
        level: 4,
        title: l10n.weight_level4Title,
        description: l10n.weight_level4Desc,
      );
    }
    return _WciLevel(
      level: 5,
      title: l10n.weight_level5Title,
      description: l10n.weight_level5Desc,
    );
  }

  double _wciToProgress(double? wci) {
    if (wci == null) return 0;
    const min = -10.0;
    const max = 10.0;
    final clamped = wci.clamp(min, max);
    return (clamped - min) / (max - min);
  }

  Future<void> _saveWeight() async {
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    final petId = _activePetId;
    if (petId == null) {
      AppSnackBar.warning(context, message: l10n.error_noPetFound);
      return;
    }
    final weight = double.tryParse(_weightController.text.trim());
    if (weight == null || weight <= 0) {
      _weightFocusNode.requestFocus();
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final record = WeightRecord(
        petId: petId,
        date: _selectedDate,
        weight: weight,
        recordedHour: _selectedTime.hour,
        recordedMinute: _selectedTime.minute,
      );
      // ViewModel: 로컬 저장 + 백엔드 fire-and-forget + 실패 시 enqueue 처리
      await ref.read(weightAddViewModelProvider.notifier).saveRecord(record);

      await _loadRecords();
      if (mounted) {
        setState(() {
          _selectedTime = TimeOfDay.now();
        });
        AppSnackBar.success(context, message: l10n.snackbar_saved);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.home);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<_ActivePetKey>(
      activePetProvider.select(_activePetKey),
      (_, next) => _onActivePetChanged(next),
    );
    final l10n = AppLocalizations.of(context);
    final current = _recordForDate(_selectedDate);
    final baseline = _baselineRecord(_selectedDate);
    final wci = _calculateWci(current, baseline);
    final level = _resolveLevel(wci);
    final progress = _wciToProgress(wci);
    final hasData = current != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: _handleBack,
        ),
        centerTitle: true,
        title: Text(
          l10n.weight_title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.45,
          ),
        ),
      ),
      body: _isLoading
          ? AppLoading.fullPage()
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Semantics(
                      button: true,
                      label: _formatDate(_selectedDate),
                      child: GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gray300),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            letterSpacing: -0.35,
                          ),
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.weight_wciHealthStatus,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.weight_title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Column(
                      key: _wciGaugeKey,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 130,
                          // 날짜 변경 시 게이지 바늘이 순간이동하지 않고 이동
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: progress),
                            duration: AppDurations.of(
                                context, AppDurations.gauge),
                            curve: AppCurves.enter,
                            builder: (context, animatedProgress, _) =>
                                CustomPaint(
                              painter: _WciGaugePainter(
                                progress: animatedProgress,
                                activeColor: AppColors.brandPrimary,
                                trackColor: AppColors.gray200,
                                hasData: hasData,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(current?.weight ?? 0).toStringAsFixed(2)}g',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: hasData
                                ? AppColors.nearBlack
                                : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasData ? level.title : 'Level 0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: hasData
                            ? AppColors.nearBlack
                            : AppColors.mediumGray,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      level.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mediumGray,
                        height: 1.6,
                        letterSpacing: -0.3,
                      ),
                    ),
                    // 품종 체중 범위 표시 (breed_id가 있을 때만)
                    if (_breedStandard != null && hasData) ...[
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.weight_breedRange,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.nearBlack,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_breedStandard!.displayName}  •  ${l10n.weight_breedRangeIdeal(_breedStandard!.weightIdealMinG, _breedStandard!.weightIdealMaxG)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: AppColors.gray600,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            WeightRangeIndicator(
                              currentWeight: current.weight,
                              minG: _breedStandard!.weightMinG,
                              idealMinG: _breedStandard!.weightIdealMinG,
                              idealMaxG: _breedStandard!.weightIdealMaxG,
                              maxG: _breedStandard!.weightMaxG,
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.gray100Alt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.weight_formula,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.nearBlack,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.weight_formulaText,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.gray600,
                              height: 1.5,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.weight_calculation,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.nearBlack,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _buildCalculationText(current, baseline, wci),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.gray600,
                              height: 1.5,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 해당 날짜의 기존 기록 목록
                    _buildExistingRecordsList(),
                    const SizedBox(height: 16),
                    // 시간 선택 카드
                    _buildTimeCard(l10n),
                    const SizedBox(height: 16),
                    TextField(
                      key: _weightInputKey,
                      controller: _weightController,
                      focusNode: _weightFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onTapOutside: (event) => FocusScope.of(context).unfocus(),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,1}'),
                        ),
                      ],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.4,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.weight_inputWeight,
                        labelStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.mediumGray,
                        ),
                        hintText: l10n.weight_inputHint,
                        suffixText: 'g',
                        suffixStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mediumGray,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.gray300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.brandPrimary,
                            width: 2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.gray300,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: l10n.btn_save,
                      child: GestureDetector(
                      key: _saveButtonKey,
                      onTap: _isSaving ? null : _saveWeight,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: _isSaving
                                ? [AppColors.lightGray, AppColors.mediumGray]
                                : [
                                    AppColors.brandPrimary,
                                    AppColors.brandDark,
                                  ],
                          ),
                        ),
                        child: Center(
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  l10n.btn_save,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                        ),
                      ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTimeCard(AppLocalizations l10n) {
    final isAM = _selectedTime.hour < 12;
    final displayHour = _selectedTime.hour == 0
        ? 12
        : (_selectedTime.hour > 12
              ? _selectedTime.hour - 12
              : _selectedTime.hour);
    final period = isAM ? l10n.weight_amPeriod : l10n.weight_pmPeriod;
    final timeText =
        '$period $displayHour:${_selectedTime.minute.toString().padLeft(2, '0')}';

    return Semantics(
      button: true,
      label: l10n.weight_selectTime,
      child: GestureDetector(
      key: _timeCardKey,
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gray300),
          borderRadius: BorderRadius.circular(12),
        ),
        // 라벨은 남는 폭을 차지하며 줄어들고(Spacer 역할 겸함), 값도 좁은 화면에서
        // 함께 줄어든다. 320px 영어에서 고정 폭 조합이 넘치던 문제(F09) 대응.
        child: Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 20,
              color: AppColors.brandPrimary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.weight_selectTime,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.35,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                timeText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mediumGray,
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildExistingRecordsList() {
    final l10n = AppLocalizations.of(context);
    final dayRecords = _recordsForDate(_selectedDate);
    if (dayRecords.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.weight_multipleRecords(dayRecords.length),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.nearBlack,
                letterSpacing: -0.35,
              ),
            ),
            Text(
              '${l10n.weight_dailyAverage} ${_dailyAverageForDate(_selectedDate)?.toStringAsFixed(1) ?? '-'}g',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.brandTextOnLight,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...dayRecords.map((record) {
          final timeStr = record.hasTime
              ? _formatRecordTime(record, l10n)
              : l10n.weight_timeNotRecorded;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.gray100Alt,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 14, color: AppColors.mediumGray),
                const SizedBox(width: 6),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mediumGray,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '${record.weight.toStringAsFixed(1)}g',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                    letterSpacing: -0.35,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatRecordTime(WeightRecord record, AppLocalizations l10n) {
    if (!record.hasTime) return '';
    final hour = record.recordedHour!;
    final minute = record.recordedMinute!;
    final isAM = hour < 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = isAM ? l10n.weight_amPeriod : l10n.weight_pmPeriod;
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }

  String _buildCalculationText(
    WeightRecord? current,
    WeightRecord? baseline,
    double? wci,
  ) {
    final l10n = AppLocalizations.of(context);
    if (current == null || baseline == null || wci == null) {
      return l10n.weight_noData;
    }
    final currentValue = current.weight.toStringAsFixed(1);
    final baseValue = baseline.weight.toStringAsFixed(1);
    final wciValue = wci.toStringAsFixed(1);
    return '($currentValue - $baseValue) / $baseValue × 100 = $wciValue%';
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context);
    final weekdays = [
      l10n.datetime_weekday_mon,
      l10n.datetime_weekday_tue,
      l10n.datetime_weekday_wed,
      l10n.datetime_weekday_thu,
      l10n.datetime_weekday_fri,
      l10n.datetime_weekday_sat,
      l10n.datetime_weekday_sun,
    ];
    final weekday = weekdays[date.weekday - 1];
    return l10n.datetime_dateFormat(date.year, date.month, date.day, weekday);
  }
}

class _WciLevel {
  final int level;
  final String title;
  final String description;

  _WciLevel({
    required this.level,
    required this.title,
    required this.description,
  });
}

class _WciGaugePainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color trackColor;
  final bool hasData;

  _WciGaugePainter({
    required this.progress,
    required this.activeColor,
    required this.trackColor,
    this.hasData = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 12.0;
    final radius = (size.width - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height - 4);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 배경 트랙 (회색 반원)
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final startAngle = math.pi;
    final sweepAngle = math.pi;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    // 활성 아크 (오렌지)
    if (hasData && progress > 0) {
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle * progress,
        false,
        activePaint,
      );
    }

    // 포인터 위치 계산
    final pointerAngle = startAngle + sweepAngle * progress;
    final pointerX = center.dx + radius * math.cos(pointerAngle);
    final pointerY = center.dy + radius * math.sin(pointerAngle);
    final pointerOffset = Offset(pointerX, pointerY);

    if (hasData) {
      // 데이터 있을 때: 바늘 + 중심 원 + 포인터 원
      final needlePaint = Paint()
        ..color = activeColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(center, pointerOffset, needlePaint);

      // 중심 원
      final centerDotPaint = Paint()..color = activeColor;
      canvas.drawCircle(center, 6, centerDotPaint);

      // 포인터 끝 원 (아크 위의 현재 위치)
      canvas.drawCircle(pointerOffset, 7, Paint()..color = activeColor);
      canvas.drawCircle(pointerOffset, 4, Paint()..color = Colors.white);
    } else {
      // 데이터 없을 때: 상단 중앙에 작은 오렌지 점만
      final topCenter = Offset(center.dx, center.dy - radius);
      canvas.drawCircle(topCenter, 5, Paint()..color = activeColor);
    }
  }

  @override
  bool shouldRepaint(covariant _WciGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.hasData != hasData;
  }
}
