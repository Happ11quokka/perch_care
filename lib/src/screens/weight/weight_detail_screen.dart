import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../models/pet.dart';
import '../../models/weight_record.dart';
import '../../models/schedule_record.dart';
import '../../services/weight/weight_service.dart';
import '../../services/schedule/schedule_service.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../services/pet/pet_service.dart';
import '../../services/pet/active_pet_notifier.dart';
import '../../router/route_names.dart';
import '../../widgets/add_schedule_bottom_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../../l10n/app_localizations.dart';

class WeightDetailScreen extends StatefulWidget {
  const WeightDetailScreen({super.key});

  @override
  State<WeightDetailScreen> createState() => _WeightDetailScreenState();
}

class _WeightDetailScreenState extends State<WeightDetailScreen> {
  final _weightService = WeightService();
  final _scheduleService = ScheduleService();
  final _petCache = PetLocalCacheService.instance;
  final _petService = PetService.instance;
  final _scrollController = ScrollController();

  // Coach mark target keys
  final _toggleKey = GlobalKey();
  final _chartKey = GlobalKey();
  final _calendarKey = GlobalKey();
  final _addBtnKey = GlobalKey();

  bool _isWeeklyView = true; // true: 주, false: 월
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  final int _selectedDay = DateTime.now().day;
  List<WeightRecord> _weightRecords = [];
  List<ScheduleRecord> _scheduleRecords = [];
  String _petName = '';
  String? _activePetId;
  bool _isLoading = true;
  List<Pet> _petList = [];
  bool _isRecordsExpanded = false;

  // Cached calculation results
  Map<DateTime, double>? _cachedMonthlyAverages;
  Map<int, double>? _cachedWeeklyData;

  @override
  void initState() {
    super.initState();
    _loadActivePet();
    ActivePetNotifier.instance.addListener(_onActivePetChanged);
  }

  @override
  void dispose() {
    ActivePetNotifier.instance.removeListener(_onActivePetChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onActivePetChanged() {
    final petId = ActivePetNotifier.instance.activePetId;
    if (petId != null && petId != _activePetId) {
      // petList에서 해당 펫을 찾아 _switchPet 호출
      final pet = _petList.where((p) => p.id == petId).firstOrNull;
      if (pet != null) {
        _switchPet(pet);
      } else {
        // petList에 없으면 전체 리로드
        _loadActivePet();
      }
    }
  }

  Future<void> _loadActivePet() async {
    try {
      // 펫 목록 + 활성 펫 동시 로드
      final results = await Future.wait([
        _petService.getMyPets(),
        _petService.getActivePet(),
      ]);
      if (!mounted) return;

      final pets = results[0] as List<Pet>;
      final apiPet = results[1] as Pet?;

      setState(() {
        _petList = pets;
      });

      if (apiPet != null) {
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
          _activePetId = apiPet.id;
          _petName = apiPet.name;
        });
      } else {
        // API 실패 시 로컬 캐시 폴백
        final cachedPet = await _petCache.getActivePet();
        if (!mounted) return;
        setState(() {
          _activePetId = cachedPet?.id;
          _petName = cachedPet?.name ?? _petName;
        });
      }

      if (_activePetId != null) {
        await Future.wait([
          _loadWeightData(),
          _loadScheduleData(),
        ]);
        _maybeShowCoachMarks();
      }
    } catch (_) {
      // API 실패 시 로컬 캐시 폴백
      try {
        final cachedPet = await _petCache.getActivePet();
        if (!mounted) return;
        setState(() {
          _activePetId = cachedPet?.id;
          _petName = cachedPet?.name ?? _petName;
        });
        if (_activePetId != null) {
          await Future.wait([
            _loadWeightData(),
            _loadScheduleData(),
          ]);
        }
      } catch (_) {
        // Handle error
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _switchPet(Pet pet) async {
    if (pet.id == _activePetId) return;
    setState(() {
      _activePetId = pet.id;
      _petName = pet.name;
      _weightRecords = [];
      _scheduleRecords = [];
      _cachedMonthlyAverages = null;
      _cachedWeeklyData = null;
    });
    _petCache.setActivePetId(pet.id);
    try {
      await _petService.setActivePet(pet.id);
    } catch (_) {}
    try {
      await Future.wait([
        _loadWeightData(),
        _loadScheduleData(),
      ]);
    } catch (_) {
      // 개별 로드 함수 내부에서 에러 처리
    }
  }

  Future<void> _loadScheduleData() async {
    if (_activePetId == null) return;
    try {
      final schedules = await _scheduleService.fetchSchedulesByMonth(
        petId: _activePetId!,
        year: _selectedYear,
        month: _selectedMonth,
      );
      if (mounted) {
        setState(() {
          _scheduleRecords = schedules;
        });
      }
    } catch (_) {
      // Handle error
    }
  }

  Future<void> _loadWeightData() async {
    if (_activePetId == null) return;
    try {
      // 서버에서 전체 기록 로드 (로컬 캐시도 자동 업데이트됨)
      final records = await _weightService.fetchAllRecords(petId: _activePetId);
      if (mounted) {
        setState(() {
          _weightRecords = records;
          _cachedMonthlyAverages = null;
          _cachedWeeklyData = null;
        });
      }
    } catch (_) {
      // 서버 실패 시 로컬 캐시 폴백
      try {
        final records = await _weightService.fetchLocalRecords(petId: _activePetId);
        if (mounted) {
          setState(() {
            _weightRecords = records;
            _cachedMonthlyAverages = null;
            _cachedWeeklyData = null;
          });
        }
      } catch (_) {}
    }
  }

  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    if (await service.hasSeenRecordsCoachMarks()) return;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final steps = [
      CoachMarkStep(
        targetKey: _toggleKey,
        title: l10n.coach_recordToggle_title,
        body: l10n.coach_recordToggle_body,
      ),
      CoachMarkStep(
        targetKey: _chartKey,
        title: l10n.coach_recordChart_title,
        body: l10n.coach_recordChart_body,
      ),
      CoachMarkStep(
        targetKey: _calendarKey,
        title: l10n.coach_recordCalendar_title,
        body: l10n.coach_recordCalendar_body,
      ),
      CoachMarkStep(
        targetKey: _addBtnKey,
        title: l10n.coach_recordAddBtn_title,
        body: l10n.coach_recordAddBtn_body,
        isScrollable: false,
      ),
    ];
    CoachMarkOverlay.show(
      context,
      steps: steps,
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      scrollController: _scrollController,
      onComplete: () => service.markRecordsCoachMarksSeen(),
    );
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.goNamed(RouteNames.home);
  }

  int get _totalRecordDays {
    final uniqueDays = <String>{};
    for (final record in _weightRecords) {
      uniqueDays.add('${record.date.year}-${record.date.month}-${record.date.day}');
    }
    return uniqueDays.length;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_activePetId == null) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: Center(
          child: Text(l10n.weightDetail_noPet),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  if (_petList.length > 1) ...[
                    const SizedBox(height: 12),
                    _buildPetSelector(),
                  ],
                  const SizedBox(height: 24),
                  _buildHeaderText(),
                  const SizedBox(height: 24),
                  _buildPeriodToggle(),
                  const SizedBox(height: 16),
                  _buildChart(),
                  const SizedBox(height: 8),
                  _buildRecordSummary(),
                  const SizedBox(height: 16),
                  _buildCalendarCard(),
                  const SizedBox(height: 16),
                  _buildWeightRecordsList(),
                  const SizedBox(height: 16),
                  _buildScheduleList(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildAddRecordButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.nearBlack),
        onPressed: _handleBack,
      ),
      centerTitle: true,
      title: Text(
        l10n.weightDetail_title,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: AppColors.nearBlack,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            l10n.weightDetail_headerLine1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              height: 1.5,
              letterSpacing: -0.6,
            ),
          ),
          Text(
            l10n.weightDetail_headerLine2(_petName.isNotEmpty ? _petName : l10n.pet_defaultName),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              height: 1.5,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.weightDetail_subLine1,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              height: 1.5,
            ),
          ),
          Text(
            l10n.weightDetail_subLine2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodToggle() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          key: _toggleKey,
          height: 33,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.brandPrimary, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isWeeklyView = true),
                child: Container(
                  width: 30,
                  height: 29,
                  decoration: BoxDecoration(
                    color: _isWeeklyView ? AppColors.brandPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: Text(
                      l10n.weightDetail_toggleWeek,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isWeeklyView ? Colors.white : AppColors.mediumGray,
                        letterSpacing: -0.325,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                onTap: () => setState(() => _isWeeklyView = false),
                child: Container(
                  width: 30,
                  height: 29,
                  decoration: BoxDecoration(
                    color: !_isWeeklyView ? AppColors.brandPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Center(
                    child: Text(
                      l10n.weightDetail_toggleMonth,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !_isWeeklyView ? Colors.white : AppColors.mediumGray,
                        letterSpacing: -0.325,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChart() {
    return SizedBox(
      key: _chartKey,
      height: 260,
      child: _isWeeklyView
          ? _buildWeeklyDaysChart()
          : _buildMonthlyOverviewChart(),
    );
  }

  /// fl_chart 데이터 좌표를 픽셀 좌표로 변환 (X축)
  double _dataXToPixel(double dataX, double minX, double maxX, double width) {
    return (dataX - minX) / (maxX - minX) * width;
  }

  /// fl_chart 데이터 좌표를 픽셀 좌표로 변환 (Y축, 화면 좌표계는 위가 0)
  double _dataYToPixel(double dataY, double minY, double maxY, double height) {
    return height - (dataY - minY) / (maxY - minY) * height;
  }

  /// 공통 pill + dashed-line 차트 빌더
  Widget _buildPillChart({
    required List<FlSpot> spots,
    required int selectedSpotIndex,
    required double selectedValue,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required int totalLabels,
    required List<String> labels,
    required int selectedLabelIdx,
  }) {
    if (spots.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return Center(
        child: Text(
          l10n.common_noData,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            color: AppColors.mediumGray,
          ),
        ),
      );
    }

    const pillWidth = 56.0;
    const pillHeight = 180.0;
    const dotSize = 20.0;
    const labelHeight = 28.0;
    const totalHeight = 260.0;
    const chartAreaHeight = totalHeight - labelHeight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth;

          // 선택된 데이터 포인트의 픽셀 좌표 계산 (fl_chart와 동일한 공식)
          final selectedSpot = spots[selectedSpotIndex];
          final dotPixelX = _dataXToPixel(selectedSpot.x, minX, maxX, chartWidth);
          final dotPixelY = _dataYToPixel(selectedSpot.y, minY, maxY, chartAreaHeight);

          // pill 위치: dot 중심을 기준으로 pill 배치
          // dot은 pill 내에서 상단 텍스트(~35px) 아래, 세로 중앙~약간 위에 위치
          // pill top = dotY - (dot이 pill 상단에서 떨어진 거리)
          const dotOffsetFromPillTop = pillHeight * 0.55;
          var pillTop = dotPixelY - dotOffsetFromPillTop;

          // pill이 차트 영역을 벗어나지 않도록 클램핑
          if (pillTop < 0) pillTop = 0;
          if (pillTop + pillHeight > chartAreaHeight) {
            pillTop = chartAreaHeight - pillHeight;
          }

          // dot의 pill 내부 상대 위치 (pill top 기준)
          final dotRelativeY = dotPixelY - pillTop;

          return SizedBox(
            height: totalHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1) 오렌지 pill 배경
                Positioned(
                  left: dotPixelX - pillWidth / 2,
                  top: pillTop,
                  child: SizedBox(
                    width: pillWidth,
                    height: pillHeight,
                    child: Stack(
                      children: [
                        // pill 배경
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                              ),
                            ),
                          ),
                        ),
                        // 값 텍스트 (pill 상단)
                        Positioned(
                          top: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              '${selectedValue.toStringAsFixed(1)} g',
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                        // 도트 (데이터 포인트와 정확히 일치하는 Y 위치)
                        Positioned(
                          top: dotRelativeY - dotSize / 2,
                          left: (pillWidth - dotSize) / 2,
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: AppColors.brandPrimary,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 2) 라인 차트 (점선 + 도트)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: labelHeight,
                  child: LineChart(
                    LineChartData(
                      minX: minX,
                      maxX: maxX,
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData.none(),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.4,
                          color: const Color(0xFFBBBBBB),
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dashArray: [6, 4],
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              if (index == selectedSpotIndex) {
                                return FlDotCirclePainter(
                                  radius: 0,
                                  color: Colors.transparent,
                                  strokeWidth: 0,
                                  strokeColor: Colors.transparent,
                                );
                              }
                              return FlDotCirclePainter(
                                radius: 4,
                                color: const Color(0xFFBBBBBB),
                                strokeWidth: 0,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                      titlesData: const FlTitlesData(show: false),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                    ),
                  ),
                ),
                // 3) 라벨 (하단)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: labelHeight,
                  child: Stack(
                    children: List.generate(totalLabels, (index) {
                      final labelCenterX = _dataXToPixel(
                        index.toDouble(), minX, maxX, chartWidth,
                      );
                      final isSelected = index == selectedLabelIdx;
                      return Positioned(
                        left: labelCenterX - 20,
                        top: 0,
                        child: SizedBox(
                          width: 40,
                          height: labelHeight,
                          child: Center(
                            child: Text(
                              labels[index],
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.brandPrimary
                                    : AppColors.mediumGray,
                                letterSpacing: -0.13,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonthlyOverviewChart() {
    final months = _generateDisplayMonths();
    final monthlyAverages = _calculateMonthlyAverages();
    final spots = _getChartSpots(months, monthlyAverages);

    final selectedSpotIndex = spots.isNotEmpty ? spots.length - 1 : 0;
    final selectedMonthIdx = spots.isNotEmpty ? spots.last.x.toInt() : (months.length - 1);
    final selectedValue = spots.isNotEmpty ? spots.last.y : 0.0;

    final l10n = AppLocalizations.of(context);
    final labels = months.map((m) => l10n.weightDetail_monthChartLabel(m.month)).toList();

    return _buildPillChart(
      spots: spots,
      selectedSpotIndex: selectedSpotIndex,
      selectedValue: selectedValue,
      minX: -0.5,
      maxX: 5.5,
      minY: _getMinY(monthlyAverages, months),
      maxY: _getMaxY(monthlyAverages, months),
      totalLabels: 6,
      labels: labels,
      selectedLabelIdx: selectedMonthIdx,
    );
  }

  Widget _buildWeeklyDaysChart() {
    final l10n = AppLocalizations.of(context);
    final weekdays = [l10n.datetime_weekday_sun, l10n.datetime_weekday_mon, l10n.datetime_weekday_tue, l10n.datetime_weekday_wed, l10n.datetime_weekday_thu, l10n.datetime_weekday_fri, l10n.datetime_weekday_sat];
    final weeklyData = _calculateWeeklyData();
    final spots = weeklyData.entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    final selectedSpotIndex = spots.isNotEmpty ? spots.length - 1 : 0;
    final selectedDayIdx = spots.isNotEmpty ? spots.last.x.toInt() : 0;
    final selectedValue = spots.isNotEmpty ? spots.last.y : 0.0;

    return _buildPillChart(
      spots: spots,
      selectedSpotIndex: selectedSpotIndex,
      selectedValue: selectedValue,
      minX: -0.5,
      maxX: 6.5,
      minY: _getMinYFromMap(weeklyData),
      maxY: _getMaxYFromMap(weeklyData),
      totalLabels: 7,
      labels: weekdays,
      selectedLabelIdx: selectedDayIdx,
    );
  }

  List<DateTime> _generateDisplayMonths() {
    final now = DateTime.now();
    return List.generate(6, (index) {
      return DateTime(now.year, now.month - 5 + index);
    });
  }

  Map<DateTime, double> _calculateMonthlyAverages() {
    // Return cached result if available
    if (_cachedMonthlyAverages != null) {
      return _cachedMonthlyAverages!;
    }

    final Map<DateTime, List<double>> monthlyData = {};
    for (final record in _weightRecords) {
      final monthKey = DateTime(record.date.year, record.date.month);
      monthlyData.putIfAbsent(monthKey, () => []);
      monthlyData[monthKey]!.add(record.weight);
    }
    final Map<DateTime, double> averages = {};
    monthlyData.forEach((month, weights) {
      averages[month] = weights.reduce((a, b) => a + b) / weights.length;
    });

    // Cache the result
    _cachedMonthlyAverages = averages;
    return averages;
  }

  Map<int, double> _calculateWeeklyData() {
    // Return cached result if available
    if (_cachedWeeklyData != null) {
      return _cachedWeeklyData!;
    }

    final Map<int, List<double>> weeklyData = {};
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));

    for (final record in _weightRecords) {
      final daysDiff = record.date.difference(startOfWeek).inDays;
      if (daysDiff >= 0 && daysDiff < 7) {
        weeklyData.putIfAbsent(daysDiff, () => []);
        weeklyData[daysDiff]!.add(record.weight);
      }
    }

    final Map<int, double> averages = {};
    for (int i = 0; i < 7; i++) {
      if (weeklyData.containsKey(i)) {
        averages[i] = weeklyData[i]!.reduce((a, b) => a + b) / weeklyData[i]!.length;
      }
    }

    // Cache the result
    _cachedWeeklyData = averages;
    return averages;
  }

  List<FlSpot> _getChartSpots(List<DateTime> months, Map<DateTime, double> averages) {
    final spots = <FlSpot>[];
    for (int i = 0; i < months.length; i++) {
      final value = averages[months[i]];
      if (value != null) {
        spots.add(FlSpot(i.toDouble(), value));
      }
    }
    return spots;
  }

  double _getMinY(Map<DateTime, double> averages, List<DateTime> months) {
    final values = months.map((m) => averages[m]).whereType<double>().toList();
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a < b ? a : b) - 3;
  }

  double _getMaxY(Map<DateTime, double> averages, List<DateTime> months) {
    final values = months.map((m) => averages[m]).whereType<double>().toList();
    if (values.isEmpty) return 100;
    return values.reduce((a, b) => a > b ? a : b) + 3;
  }

  double _getMinYFromMap(Map<int, double> data) {
    if (data.isEmpty) return 0;
    return data.values.reduce((a, b) => a < b ? a : b) - 5;
  }

  double _getMaxYFromMap(Map<int, double> data) {
    if (data.isEmpty) return 100;
    return data.values.reduce((a, b) => a > b ? a : b) + 5;
  }

  Widget _buildRecordSummary() {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        l10n.weightDetail_recordSummary(_petName, _totalRecordDays),
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.nearBlack,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      key: _calendarKey,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          const SizedBox(height: 8),
          _buildCalendarWeekdays(),
          _buildCalendarDays(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _previousMonth,
            child: const Icon(Icons.chevron_left, size: 20, color: AppColors.nearBlack),
          ),
          const SizedBox(width: 10),
          Text(
            AppLocalizations.of(context).weightDetail_yearMonth(_selectedYear, _selectedMonth),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _nextMonth,
            child: const Icon(Icons.chevron_right, size: 20, color: AppColors.nearBlack),
          ),
        ],
      ),
    );
  }

  void _previousMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedMonth = 12;
        _selectedYear--;
      } else {
        _selectedMonth--;
      }
    });
    _loadScheduleData();
  }

  void _nextMonth() {
    setState(() {
      if (_selectedMonth == 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else {
        _selectedMonth++;
      }
    });
    _loadScheduleData();
  }

  Widget _buildCalendarWeekdays() {
    final l10n = AppLocalizations.of(context);
    final weekdays = [l10n.datetime_weekday_sun, l10n.datetime_weekday_mon, l10n.datetime_weekday_tue, l10n.datetime_weekday_wed, l10n.datetime_weekday_thu, l10n.datetime_weekday_fri, l10n.datetime_weekday_sat];
    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                day,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF97928A),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarDays() {
    final firstDayOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = lastDayOfMonth.day;

    // Previous month days
    final prevMonth = DateTime(_selectedYear, _selectedMonth, 0);
    final prevMonthDays = prevMonth.day;

    final List<Widget> rows = [];
    final List<Widget> currentRow = [];

    // Add days from previous month
    for (int i = startWeekday - 1; i >= 0; i--) {
      final day = prevMonthDays - i;
      currentRow.add(_buildDayCell(day, isOtherMonth: true));
    }

    // Add days of current month
    for (int day = 1; day <= daysInMonth; day++) {
      final hasRecord = _hasRecordOnDay(day);
      final isSelected = day == _selectedDay &&
          _selectedYear == DateTime.now().year &&
          _selectedMonth == DateTime.now().month;
      final isSunday = (startWeekday + day - 1) % 7 == 0;

      currentRow.add(_buildDayCell(
        day,
        hasRecord: hasRecord,
        isSelected: isSelected,
        isSunday: isSunday,
      ));

      if (currentRow.length == 7) {
        rows.add(Row(children: List.from(currentRow)));
        currentRow.clear();
      }
    }

    // Add days from next month
    if (currentRow.isNotEmpty) {
      int nextDay = 1;
      while (currentRow.length < 7) {
        currentRow.add(_buildDayCell(nextDay++, isOtherMonth: true));
      }
      rows.add(Row(children: List.from(currentRow)));
    }

    return Column(children: rows);
  }

  bool _hasRecordOnDay(int day) {
    return _weightRecords.any((record) =>
        record.date.day == day &&
        record.date.month == _selectedMonth &&
        record.date.year == _selectedYear);
  }

  Widget _buildDayCell(
    int day, {
    bool hasRecord = false,
    bool isSelected = false,
    bool isOtherMonth = false,
    bool isSunday = false,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: isOtherMonth
            ? null
            : () => _onDayTap(day),
        child: SizedBox(
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasRecord && !isSelected)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              if (isSelected)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
              Text(
                '$day',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isOtherMonth
                          ? const Color(0xFF97928A)
                          : isSunday
                              ? const Color(0xFFEE3300)
                              : AppColors.nearBlack,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onDayTap(int day) async {
    final selectedDate = DateTime(_selectedYear, _selectedMonth, day);
    final result = await showAddScheduleBottomSheet(
      context: context,
      initialDate: selectedDate,
      petId: _activePetId,
    );
    if (result != null) {
      try {
        // 서버에 저장
        await _scheduleService.createSchedule(result);
        // 목록 새로고침
        await _loadScheduleData();
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          AppSnackBar.error(context, message: l10n.schedule_saveError);
        }
      }
    }
  }

  Widget _buildScheduleList() {
    final l10n = AppLocalizations.of(context);
    // Filter schedules for the selected month
    final monthSchedules = _scheduleRecords.where((record) {
      return record.startTime.year == _selectedYear &&
          record.startTime.month == _selectedMonth;
    }).toList();

    // Sort by start time
    monthSchedules.sort((a, b) => a.startTime.compareTo(b.startTime));

    if (monthSchedules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.event_note_outlined,
                size: 48,
                color: AppColors.mediumGray.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.weightDetail_noSchedule,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.weightDetail_addScheduleHint,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group schedules by date
    final Map<DateTime, List<ScheduleRecord>> groupedSchedules = {};
    for (final schedule in monthSchedules) {
      final dateKey = DateTime(
        schedule.startTime.year,
        schedule.startTime.month,
        schedule.startTime.day,
      );
      groupedSchedules.putIfAbsent(dateKey, () => []);
      groupedSchedules[dateKey]!.add(schedule);
    }

    final sortedDates = groupedSchedules.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weightDetail_monthSchedule,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          ...sortedDates.map((date) => _buildScheduleDateGroup(date, groupedSchedules[date]!)),
        ],
      ),
    );
  }

  Widget _buildScheduleDateGroup(DateTime date, List<ScheduleRecord> schedules) {
    final l10n = AppLocalizations.of(context);
    final weekdays = [l10n.datetime_weekday_mon, l10n.datetime_weekday_tue, l10n.datetime_weekday_wed, l10n.datetime_weekday_thu, l10n.datetime_weekday_fri, l10n.datetime_weekday_sat, l10n.datetime_weekday_sun];
    final weekday = weekdays[(date.weekday - 1) % 7];
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                l10n.schedule_dateDisplay(date.month, date.day, weekday),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isToday ? AppColors.brandPrimary : AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    l10n.weightDetail_today,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ...schedules.map((schedule) => _buildScheduleItem(schedule)),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _deleteSchedule(ScheduleRecord schedule) async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _scheduleRecords.removeWhere((r) => r.id == schedule.id);
    });

    try {
      await _scheduleService.deleteSchedule(schedule.id, petId: schedule.petId);
      if (mounted) {
        AppSnackBar.success(context, message: l10n.schedule_deleted);
      }
    } catch (e) {
      if (mounted) {
        await _loadScheduleData();
        if (mounted) {
          AppSnackBar.error(context, message: l10n.schedule_deleteError);
        }
      }
    }
  }

  Widget _buildScheduleItem(ScheduleRecord schedule) {
    final l10n = AppLocalizations.of(context);
    return Dismissible(
      key: Key(schedule.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteSchedule(schedule),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: schedule.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule.title,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  schedule.formattedTimeRange,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 12,
                    color: AppColors.mediumGray,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          if (schedule.reminderMinutes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    size: 14,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.schedule_reminderMinutes(schedule.reminderMinutes!),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 11,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildPetSelector() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        itemCount: _petList.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final pet = _petList[index];
          final isSelected = pet.id == _activePetId;
          return GestureDetector(
            onTap: () => _switchPet(pet),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brandPrimary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.brandPrimary : const Color(0xFFE0E0E0),
                ),
              ),
              child: Center(
                child: Text(
                  pet.name,
                  style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.mediumGray,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatRecordTime(WeightRecord record) {
    if (!record.hasTime) return '';
    final hour = record.recordedHour!;
    final minute = record.recordedMinute!;
    final l10n = AppLocalizations.of(context);
    final isAM = hour < 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = isAM ? l10n.weight_amPeriod : l10n.weight_pmPeriod;
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWeightRecordsList() {
    final l10n = AppLocalizations.of(context);
    final monthRecords = _weightRecords.where((record) =>
        record.date.year == _selectedYear &&
        record.date.month == _selectedMonth).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (monthRecords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                Icons.monitor_weight_outlined,
                size: 48,
                color: AppColors.mediumGray.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.weightDetail_noWeightRecord,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.35,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 날짜별 그룹화 (내림차순)
    final Map<String, List<WeightRecord>> groupedByDate = {};
    for (final record in monthRecords) {
      final key = '${record.date.year}-${record.date.month}-${record.date.day}';
      groupedByDate.putIfAbsent(key, () => []);
      groupedByDate[key]!.add(record);
    }
    // 날짜 내 기록은 시간 기준 오름차순 정렬
    for (final records in groupedByDate.values) {
      records.sort((a, b) {
        final aMinutes = (a.recordedHour ?? 0) * 60 + (a.recordedMinute ?? 0);
        final bMinutes = (b.recordedHour ?? 0) * 60 + (b.recordedMinute ?? 0);
        return aMinutes.compareTo(bMinutes);
      });
    }
    final sortedDateKeys = groupedByDate.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 최신 날짜 먼저

    // 펼치기 기준: 그룹(날짜) 수 기준 10개
    final visibleKeys = _isRecordsExpanded
        ? sortedDateKeys
        : sortedDateKeys.take(10).toList();

    final weekdays = [
      l10n.datetime_weekday_mon,
      l10n.datetime_weekday_tue,
      l10n.datetime_weekday_wed,
      l10n.datetime_weekday_thu,
      l10n.datetime_weekday_fri,
      l10n.datetime_weekday_sat,
      l10n.datetime_weekday_sun,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.weightDetail_monthWeightRecord(_selectedMonth),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          ...visibleKeys.map((dateKey) {
            final records = groupedByDate[dateKey]!;
            final date = records.first.date;
            final weekday = weekdays[(date.weekday - 1) % 7];
            final isSingle = records.length == 1;

            if (isSingle) {
              // 단일 기록: 기존 스타일 + 시간 표시
              final record = records.first;
              final timeText = record.hasTime
                  ? _formatRecordTime(record)
                  : l10n.weight_timeNotRecorded;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.month}/${date.day} ($weekday)',
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.nearBlack,
                              letterSpacing: -0.35,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            timeText,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.mediumGray,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${record.weight.toStringAsFixed(1)} g',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandPrimary,
                        letterSpacing: -0.35,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              // 다중 기록: 헤더(평균) + 하위 항목
              final avgWeight = records.map((r) => r.weight).reduce((a, b) => a + b) / records.length;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 헤더: 날짜 + 평균 + 횟수
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${date.month}/${date.day} ($weekday)',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.nearBlack,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  l10n.weight_multipleRecords(records.length),
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.mediumGray,
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
                                '${avgWeight.toStringAsFixed(1)} g',
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brandPrimary,
                                  letterSpacing: -0.35,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.weight_dailyAverage,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.mediumGray,
                                  letterSpacing: -0.28,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // 구분선
                    Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      color: const Color(0xFFF0F0F0),
                    ),
                    // 하위 항목들
                    ...records.map((record) {
                      final timeText = record.hasTime
                          ? _formatRecordTime(record)
                          : l10n.weight_timeNotRecorded;
                      final isLast = record == records.last;
                      return Padding(
                        padding: EdgeInsets.fromLTRB(32, 10, 16, isLast ? 12 : 6),
                        child: Row(
                          children: [
                            Text(
                              timeText,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: record.hasTime
                                    ? AppColors.nearBlack
                                    : AppColors.mediumGray,
                                letterSpacing: -0.32,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${record.weight.toStringAsFixed(1)} g',
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.nearBlack,
                                letterSpacing: -0.32,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }
          }),
          if (sortedDateKeys.length > 10)
            GestureDetector(
              onTap: () {
                setState(() {
                  _isRecordsExpanded = !_isRecordsExpanded;
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isRecordsExpanded
                          ? l10n.common_collapse
                          : l10n.common_showAll(sortedDateKeys.length),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _isRecordsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppColors.mediumGray,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddRecordButton() {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      key: _addBtnKey,
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
        child: GestureDetector(
          onTap: () async {
            final result = await showAddScheduleBottomSheet(
              context: context,
              initialDate: DateTime.now(),
              petId: _activePetId,
            );
            if (result != null) {
              try {
                await _scheduleService.createSchedule(result);
                await _loadScheduleData();
              } catch (e) {
                if (mounted) {
                  AppSnackBar.error(context, message: l10n.schedule_saveError);
                }
              }
            }
          },
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment(-0.95, 0),
                end: Alignment(0.95, 0),
                colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.25),
                  ),
                  child: const Center(
                    child: Icon(Icons.add, size: 12, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.btn_addRecord,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

