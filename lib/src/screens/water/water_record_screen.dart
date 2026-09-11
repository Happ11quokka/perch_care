import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../repositories/save_outcome.dart';
import '../../theme/colors.dart';
import '../../view_models/water/water_record_view_model.dart';
import '../../router/route_names.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';
import '../../providers/pet_providers.dart';
import '../../models/pet.dart';
import '../../../l10n/app_localizations.dart';

/// 활성 펫 구독 키 — 로딩 중(값 없음) / 펫 없음(null) / 펫 id 를 구분한다.
/// AsyncLoading.copyWithPrevious(이전 펫 유지)는 로딩으로 취급하지 않는다.
typedef _ActivePetKey = ({bool loading, String? petId});

_ActivePetKey _activePetKey(AsyncValue<Pet?> s) =>
    (loading: s.isLoading && !s.hasValue, petId: s.valueOrNull?.id);

class WaterRecordScreen extends ConsumerStatefulWidget {
  const WaterRecordScreen({super.key});

  @override
  ConsumerState<WaterRecordScreen> createState() => _WaterRecordScreenState();
}

class _WaterRecordScreenState extends ConsumerState<WaterRecordScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _activePetId;
  bool _isLoading = true;

  /// 마지막으로 처리한 활성 펫 키 — 동일 키 재발행은 무시.
  _ActivePetKey? _lastPetKey;

  /// 로드 시퀀스 — 이전 펫/날짜의 in-flight 결과를 폐기하기 위한 가드.
  int _loadSeq = 0;
  bool _coachMarksChecked = false;

  double _totalMl = 0;
  int _count = 0;
  final double _goalMl = 270;

  // 코치마크 GlobalKeys
  final _waterIconKey = GlobalKey();
  final _targetCardKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // 초기값은 동기 read, 이후 변경은 build()의 ref.listen 으로 구독한다.
    _onActivePetChanged(_activePetKey(ref.read(activePetProvider)));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 활성 펫 확정/전환 시 호출 — 로딩 중이면 대기, 펫이 바뀌면 재로드.
  void _onActivePetChanged(_ActivePetKey next) {
    if (next.loading) return;
    if (next == _lastPetKey) return;
    _lastPetKey = next;
    _activePetId = next.petId;
    _setLoading(true);
    _loadRecord();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    setState(() => _isLoading = value);
  }

  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenWaterRecord)) return;
    await Future.delayed(AppDurations.coachMarkDelay);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    CoachMarkOverlay.show(
      context,
      scrollController: _scrollController,
      steps: [
        CoachMarkStep(
          targetKey: _waterIconKey,
          title: l10n.coach_waterIcon_title,
          body: l10n.coach_waterIcon_body,
        ),
        CoachMarkStep(
          targetKey: _targetCardKey,
          title: l10n.coach_waterTarget_title,
          body: l10n.coach_waterTarget_body,
        ),
      ],
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () => service.markSeen(CoachMarkService.screenWaterRecord),
    );
  }

  /// 현재 펫·날짜의 기록 로드. 로드 중 펫/날짜가 바뀌면 결과를 폐기한다.
  Future<void> _loadRecord() async {
    final seq = ++_loadSeq;
    final petId = _activePetId;
    ({double totalMl, int count})? result;
    if (petId != null) {
      try {
        result = await ref
            .read(waterRecordViewModelProvider.notifier)
            .loadByDate(petId: petId, date: _selectedDate);
      } catch (_) {
        result = null;
      }
    }
    if (!mounted || seq != _loadSeq) return;
    setState(() {
      _totalMl = result?.totalMl ?? 0;
      _count = result?.count ?? 0;
      _isLoading = false;
    });
    if (!_coachMarksChecked) {
      _coachMarksChecked = true;
      _maybeShowCoachMarks();
    }
  }

  /// 저장 시도. 활성 펫이 없으면 경고 스낵바 후 false 반환 (성공 스낵바 금지).
  Future<bool> _saveRecord() async {
    final petId = _activePetId;
    final l10n = AppLocalizations.of(context);
    if (petId == null) {
      AppSnackBar.warning(context, message: l10n.error_noPetFound);
      return false;
    }
    final outcome = await ref.read(waterRecordViewModelProvider.notifier).save(
          petId: petId,
          date: _selectedDate,
          totalMl: _totalMl,
          targetMl: _goalMl,
          count: _count,
        );
    if (mounted && outcome == SaveOutcome.offline) {
      AppSnackBar.info(context, message: l10n.snackbar_savedOffline);
    }
    return true;
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
    await _loadRecord();
  }


  double get _perDrink => _count == 0 ? 0 : _totalMl / _count;

  Future<void> _openEditor() async {
    final l10n = AppLocalizations.of(context);
    final totalController = TextEditingController(
      text: _totalMl == 0 ? '' : _totalMl.toStringAsFixed(0),
    );
    final countController = TextEditingController(
      text: _count == 0 ? '' : _count.toString(),
    );

    final result = await showModalBottomSheet<_WaterEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.beige,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l10n.water_inputTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: l10n.water_totalIntake,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: l10n.water_intakeCount,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(l10n.common_cancel),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final total = double.tryParse(
                          totalController.text.trim(),
                        );
                        final count = int.tryParse(countController.text.trim());
                        if (total == null || count == null) return;
                        Navigator.pop(
                          context,
                          _WaterEditResult(totalMl: total, count: count),
                        );
                      },
                      child: Text(l10n.btn_save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;
    setState(() {
      _totalMl = result.totalMl;
      _count = result.count;
    });
    await _saveRecord();
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
    final hasData = _totalMl > 0;
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
          l10n.water_title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.45,
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: AppDurations.of(context, AppDurations.normal),
        switchInCurve: AppCurves.enter,
        child: _isLoading
            ? KeyedSubtree(
                key: const ValueKey('water-loading'),
                child: AppLoading.fullPage(),
              )
            : SafeArea(
              key: const ValueKey('water-content'),
              top: false,
              child: SingleChildScrollView(
                controller: _scrollController,
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
                        l10n.water_routine,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.water_water,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: l10n.water_water,
                      child: GestureDetector(
                      key: _waterIconKey,
                      onTap: _openEditor,
                      child: Column(
                        children: [
                          SvgPicture.asset(
                            'assets/images/home_vector/water.svg',
                            width: 80,
                            height: 80,
                            colorFilter: ColorFilter.mode(
                              hasData
                                  ? AppColors.brandPrimary
                                  : AppColors.gray300,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_totalMl.toStringAsFixed(0)}ml',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: hasData
                                  ? AppColors.nearBlack
                                  : AppColors.gray400,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit,
                                size: 14,
                                color: AppColors.gray400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                hasData
                                    ? l10n.water_tapToEdit
                                    : l10n.water_tapToInput,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.gray400,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      key: _targetCardKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.lightGray),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.water_dailyTarget,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.nearBlack,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.water_recommendedRange(
                                    _goalMl.toStringAsFixed(0),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.brandTextOnLight,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.water_dailyCount,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.nearBlack,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.water_perDrink(
                                    _perDrink.toStringAsFixed(0),
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.gray600,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${_totalMl.toStringAsFixed(2)}ml',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.nearBlack,
                                  letterSpacing: -0.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                l10n.water_timesCount(_count),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.nearBlack,
                                  letterSpacing: -0.45,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Semantics(
                      button: true,
                      label: l10n.btn_save,
                      child: GestureDetector(
                      onTap: () async {
                        final saved = await _saveRecord();
                        if (!saved || !context.mounted) return;
                        AppSnackBar.success(
                          context,
                          message: l10n.snackbar_saved,
                        );
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [AppColors.brandPrimary, AppColors.brandDark],
                          ),
                        ),
                        child: Center(
                          child: Text(
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
      ),
    );
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

class _WaterEditResult {
  final double totalMl;
  final int count;

  const _WaterEditResult({required this.totalMl, required this.count});
}
