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

class WeightDetailScreen extends StatefulWidget {
  const WeightDetailScreen({super.key});

  @override
  State<WeightDetailScreen> createState() => _WeightDetailScreenState();
}

class _WeightDetailScreenState extends State<WeightDetailScreen> {
  final _weightService = WeightService();
  final _scheduleService = ScheduleService();
  final _petCache = PetLocalCacheService();
  final _petService = PetService();

  bool _isWeeklyView = true; // true: 주, false: 월
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  final int _selectedDay = DateTime.now().day;
  List<WeightRecord> _weightRecords = [];
  List<ScheduleRecord> _scheduleRecords = [];
  String _petName = '사랑이';
  String? _activePetId;
  bool _isLoading = true;
  List<Pet> _petList = [];

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
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: const Center(
          child: Text('활성화된 펫이 없습니다. 펫을 먼저 추가해주세요.'),
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
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.nearBlack),
        onPressed: _handleBack,
      ),
      centerTitle: true,
      title: const Text(
        '기록',
        style: TextStyle(
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Text(
            ' 꾸준히 기록을 남기며',
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
            '$_petName 체중 변화를 한 눈에!',
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
          const Text(
            '지금 바로 기록하고 우리 아이 건강 상태를',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              height: 1.5,
            ),
          ),
          const Text(
            '편하게 관리해 보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
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
    return Padding(
      padding: const EdgeInsets.only(right: 32),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
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
                      '주',
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
                      '월',
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
      height: 260,
      child: _isWeeklyView
          ? _buildMonthlyOverviewChart()
          : _buildWeeklyDaysChart(),
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
      return const Center(
        child: Text(
          '데이터가 없습니다',
          style: TextStyle(
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
                                fontWeight: FontWeight.w400,
                                color: isSelected
                                    ? Colors.white
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

    final labels = months.map((m) => '${m.month}월').toList();

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
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.nearBlack,
            letterSpacing: -0.4,
          ),
          children: [
            TextSpan(text: '$_petName의 몸무게 총 '),
            TextSpan(
              text: '$_totalRecordDays일',
              style: const TextStyle(color: AppColors.brandPrimary),
            ),
            const TextSpan(text: ' 기록 중'),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
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
            '$_selectedYear년 $_selectedMonth월',
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
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('일정 저장 중 오류가 발생했습니다.')),
          );
        }
      }
    }
  }

  Widget _buildScheduleList() {
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
              const Text(
                '등록된 일정이 없습니다',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '아래 버튼을 눌러 일정을 추가해보세요',
                style: TextStyle(
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
          const Text(
            '이번 달 일정',
            style: TextStyle(
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
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
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
                '${date.month}월 ${date.day}일 ($weekday)',
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
                  child: const Text(
                    '오늘',
                    style: TextStyle(
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

  Widget _buildScheduleItem(ScheduleRecord schedule) {
    return Container(
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
                    '${schedule.reminderMinutes}분 전',
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

  Widget _buildWeightRecordsList() {
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
              const Text(
                '이번 달 체중 기록이 없습니다',
                style: TextStyle(
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_selectedMonth월 체중 기록',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          ...monthRecords.map((record) {
            final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
            final weekday = weekdays[(record.date.weekday - 1) % 7];
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
                  Text(
                    '${record.date.month}/${record.date.day} ($weekday)',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.nearBlack,
                      letterSpacing: -0.35,
                    ),
                  ),
                  const Spacer(),
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
          }),
        ],
      ),
    );
  }

  Widget _buildAddRecordButton() {
    return SafeArea(
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('일정 저장 중 오류가 발생했습니다.')),
                  );
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
                const Text(
                  '기록 추가',
                  style: TextStyle(
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

