import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../theme/typography.dart';
import '../../theme/spacing.dart';
import '../../theme/radius.dart';
import '../../models/weight_record.dart';
import '../../services/weight/weight_service.dart';
import '../../services/pet/pet_service.dart';
import '../../router/route_paths.dart';

class WeightDetailScreen extends StatefulWidget {
  const WeightDetailScreen({super.key});

  @override
  State<WeightDetailScreen> createState() => _WeightDetailScreenState();
}

class _WeightDetailScreenState extends State<WeightDetailScreen> {
  late String selectedPeriod;
  late int selectedWeek;
  late int selectedMonth;
  late int selectedYear;
  List<WeightRecord> weightRecords = [];
  final _weightService = WeightService();
  final _petService = PetService();
  String? _activePetId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    selectedPeriod = '월'; // 주, 월, 년
    selectedYear = now.year;
    selectedMonth = now.month;

    // 현재 월의 몇 주차인지 계산
    final weekOfMonth = ((now.day - 1) / 7).floor() + 1;
    selectedWeek = weekOfMonth.clamp(1, 4);

    // 현재 월 데이터 가져오기 (WeightService에서 가져옴)
    _loadActivePet();
  }

  /// 활성 펫 로드
  Future<void> _loadActivePet() async {
    try {
      final pet = await _petService.getActivePet();
      if (pet != null && mounted) {
        setState(() {
          _activePetId = pet.id;
        });
        await _loadWeightData();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 체중 데이터 로드
  Future<void> _loadWeightData() async {
    if (_activePetId == null) return;

    try {
      final records = await _weightService.getWeightRecords(_activePetId!);
      if (mounted) {
        setState(() {
          weightRecords = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 데이터 새로고침
  Future<void> _refreshData() async {
    await _loadWeightData();
  }

  // weightRecords에서 월별 평균 계산
  Map<int, double> _calculateMonthlyAverages() {
    final Map<int, List<double>> monthlyData = {};

    // 월별로 데이터 그룹화
    for (final record in weightRecords) {
      final month = record.date.month;
      if (!monthlyData.containsKey(month)) {
        monthlyData[month] = [];
      }
      monthlyData[month]!.add(record.weight);
    }

    // 월별 평균 계산
    final Map<int, double> averages = {};
    monthlyData.forEach((month, weights) {
      averages[month] = weights.reduce((a, b) => a + b) / weights.length;
    });

    return averages;
  }

  // weightRecords에서 특정 주차의 요일별 평균 계산
  Map<int, double> _calculateWeeklyData(int year, int month, int weekNumber) {
    final Map<int, List<double>> weeklyData = {};

    // 해당 주차의 시작일과 종료일 계산
    final startDay = (weekNumber - 1) * 7 + 1;
    final endDay = (startDay + 6).clamp(1, DateTime(year, month + 1, 0).day);

    // 해당 주차의 데이터만 필터링
    for (final record in weightRecords) {
      if (record.date.year == year &&
          record.date.month == month &&
          record.date.day >= startDay &&
          record.date.day <= endDay) {
        final weekday = record.date.weekday % 7; // 0=일, 1=월, ..., 6=토
        final displayDay = weekday + 1; // 1=일, 2=월, ..., 7=토
        if (!weeklyData.containsKey(displayDay)) {
          weeklyData[displayDay] = [];
        }
        weeklyData[displayDay]!.add(record.weight);
      }
    }

    // 요일별 평균 계산
    final Map<int, double> averages = {};
    weeklyData.forEach((weekday, weights) {
      averages[weekday] = weights.reduce((a, b) => a + b) / weights.length;
    });

    return averages;
  }

  // weightRecords에서 연간 월별 평균 계산
  Map<int, double> _calculateYearlyAverages(int year) {
    final Map<int, List<double>> yearlyData = {};

    // 해당 년도의 데이터만 필터링 및 그룹화
    for (final record in weightRecords) {
      if (record.date.year == year) {
        final month = record.date.month;
        if (!yearlyData.containsKey(month)) {
          yearlyData[month] = [];
        }
        yearlyData[month]!.add(record.weight);
      }
    }

    // 월별 평균 계산
    final Map<int, double> averages = {};
    yearlyData.forEach((month, weights) {
      averages[month] = weights.reduce((a, b) => a + b) / weights.length;
    });

    return averages;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section - Fixed
            _buildTopSection(size),

            // Bottom Sheet - Scrollable Calendar
            Expanded(
              child: _buildBottomSheet(size, padding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(Size size) {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Header with back button
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Text(
                  '체중',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: 48), // Balance for back button
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Title
          Text(
            ' 꾸준히 기록을 남기며',
            textAlign: TextAlign.center,
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),
          Text(
            '사랑이 체중 변화를 한 눈에!',
            textAlign: TextAlign.center,
            style: AppTypography.h4.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),

          const SizedBox(height: AppSpacing.sm),

          // Subtitle
          Text(
            '지금 바로 기록하고 우리 아이 건강 상태를',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mediumGray,
            ),
          ),
          Text(
            '편하게 관리해 보세요.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.mediumGray,
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Period Selector
          _buildPeriodSelector(),

          const SizedBox(height: AppSpacing.xl),

          // Chart
          _buildChart(size),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.brandPrimary, width: 1),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodButton('주'),
          _buildPeriodButton('월'),
          _buildPeriodButton('년'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = selectedPeriod == period;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPeriod = period;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(
          period,
          style: AppTypography.bodySmall.copyWith(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            color: isSelected ? Colors.white : AppColors.mediumGray,
          ),
        ),
      ),
    );
  }

  Widget _buildChart(Size size) {
    switch (selectedPeriod) {
      case '주':
        return _buildWeeklyChart(size);
      case '월':
        return _buildMonthlyChart(size);
      case '년':
        return _buildYearlyChart(size);
      default:
        return _buildMonthlyChart(size);
    }
  }

  // 주간 차트 (월~일, 7일)
  Widget _buildWeeklyChart(Size size) {
    final chartWidth = size.width - (AppSpacing.md * 2);
    final chartHeight = 200.0;
    final weeklyData = _calculateWeeklyData(selectedYear, selectedMonth, selectedWeek);

    return Container(
      width: chartWidth,
      height: chartHeight,
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.lg,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
      ),
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: 7,
          minY: _getMinY(weeklyData),
          maxY: _getMaxY(weeklyData),
          lineBarsData: [
            LineChartBarData(
              spots: _convertMapToFlSpots(weeklyData),
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.brandPrimary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: AppColors.brandPrimary,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final day = value.toInt();
                  if (day < 1 || day > 7) return const SizedBox();

                  const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
                  return Text(
                    weekdays[day - 1],
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.mediumGray,
                      fontWeight: FontWeight.w400,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} g',
                    AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  // 월간 차트 (최근 6개월)
  Widget _buildMonthlyChart(Size size) {
    final chartWidth = size.width - (AppSpacing.md * 2);
    final chartHeight = 200.0;

    // 최근 6개월 범위 계산
    final now = DateTime.now();
    final minMonth = (now.month - 5).clamp(1, 12);
    final maxMonth = now.month;

    // 실제 저장된 데이터에서 월별 평균 계산
    final monthlyAverages = _calculateMonthlyAverages();

    return Container(
      width: chartWidth,
      height: chartHeight,
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.lg,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
      ),
      child: LineChart(
        LineChartData(
          minX: minMonth.toDouble(),
          maxX: maxMonth.toDouble(),
          minY: _getMinY(monthlyAverages),
          maxY: _getMaxY(monthlyAverages),
          lineBarsData: [
            LineChartBarData(
              spots: _convertMapToFlSpots(monthlyAverages),
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.brandPrimary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final month = spot.x.toInt();
                  final isHighlighted = month == selectedMonth;

                  if (isHighlighted) {
                    return FlDotCirclePainter(
                      radius: 8,
                      color: AppColors.brandPrimary,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.lightGray,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final month = value.toInt();
                  if (month < minMonth || month > maxMonth) return const SizedBox();

                  final isHighlighted = month == selectedMonth;

                  return Text(
                    '$month월',
                    style: AppTypography.bodySmall.copyWith(
                      color: isHighlighted
                          ? AppColors.brandPrimary
                          : AppColors.mediumGray,
                      fontWeight: isHighlighted
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} g',
                    AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              if (monthlyAverages[selectedMonth] != null &&
                  monthlyAverages[selectedMonth]! > 0)
                VerticalLine(
                  x: selectedMonth.toDouble(),
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  strokeWidth: 53,
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 10),
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    labelResolver: (line) {
                      final value = monthlyAverages[selectedMonth] ?? 0;
                      return '${value.toStringAsFixed(1)} g';
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 연간 차트 (1~12월)
  Widget _buildYearlyChart(Size size) {
    final chartWidth = size.width - (AppSpacing.md * 2);
    final chartHeight = 200.0;
    final yearlyData = _calculateYearlyAverages(selectedYear);

    return Container(
      width: chartWidth,
      height: chartHeight,
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.lg,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
      ),
      child: LineChart(
        LineChartData(
          minX: 1,
          maxX: 12,
          minY: _getMinY(yearlyData),
          maxY: _getMaxY(yearlyData),
          lineBarsData: [
            LineChartBarData(
              spots: _convertMapToFlSpots(yearlyData),
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.brandPrimary,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final month = spot.x.toInt();
                  final isHighlighted = month == selectedMonth;

                  if (isHighlighted) {
                    return FlDotCirclePainter(
                      radius: 8,
                      color: AppColors.brandPrimary,
                      strokeWidth: 3,
                      strokeColor: Colors.white,
                    );
                  }
                  return FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.lightGray,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final month = value.toInt();
                  if (month < 1 || month > 12) return const SizedBox();

                  final isHighlighted = month == selectedMonth;

                  return Text(
                    '$month월',
                    style: AppTypography.bodySmall.copyWith(
                      color: isHighlighted
                          ? AppColors.brandPrimary
                          : AppColors.mediumGray,
                      fontWeight: isHighlighted
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.y.toStringAsFixed(1)} g',
                    AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }).toList();
              },
            ),
          ),
          extraLinesData: ExtraLinesData(
            verticalLines: [
              if (yearlyData[selectedMonth] != null &&
                  yearlyData[selectedMonth]! > 0)
                VerticalLine(
                  x: selectedMonth.toDouble(),
                  color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  strokeWidth: 53,
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 10),
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    labelResolver: (line) {
                      final value = yearlyData[selectedMonth] ?? 0;
                      return '${value.toStringAsFixed(1)} g';
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Map 데이터를 FlSpot으로 변환 (공통 헬퍼)
  List<FlSpot> _convertMapToFlSpots(Map<int, double> data) {
    final spots = data.entries
        .where((entry) => entry.value > 0)
        .map((entry) => FlSpot(
              entry.key.toDouble(),
              entry.value,
            ))
        .toList();

    // X축 기준으로 정렬하여 자연스러운 연결 보장
    spots.sort((a, b) => a.x.compareTo(b.x));
    return spots;
  }

  // Y축 최소값 계산 (공통 헬퍼)
  double _getMinY(Map<int, double> data) {
    final values = data.values.where((v) => v > 0);
    if (values.isEmpty) return 0;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    return minValue - 5; // 여유 공간
  }

  // Y축 최대값 계산 (공통 헬퍼)
  double _getMaxY(Map<int, double> data) {
    final values = data.values.where((v) => v > 0);
    if (values.isEmpty) return 100;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    return maxValue + 5; // 여유 공간
  }

  // Period 라벨 가져오기
  String _getPeriodLabel() {
    switch (selectedPeriod) {
      case '주':
        return '$selectedMonth월 $selectedWeek주차';
      case '월':
        return '$selectedMonth월';
      case '년':
        return '$selectedYear년';
      default:
        return '$selectedMonth월';
    }
  }

  // 이전 Period로 이동
  void _onPreviousPeriod() {
    setState(() {
      final now = DateTime.now();
      switch (selectedPeriod) {
        case '주':
          if (selectedWeek > 1) selectedWeek--;
          break;
        case '월':
          final minMonth = (now.month - 5).clamp(1, 12);
          if (selectedMonth > minMonth) selectedMonth--;
          break;
        case '년':
          if (selectedYear > now.year - 1) selectedYear--;
          break;
      }
    });
  }

  // 다음 Period로 이동
  void _onNextPeriod() {
    setState(() {
      final now = DateTime.now();
      switch (selectedPeriod) {
        case '주':
          if (selectedWeek < 4) selectedWeek++;
          break;
        case '월':
          if (selectedMonth < now.month) selectedMonth++;
          break;
        case '년':
          if (selectedYear < now.year) selectedYear++;
          break;
      }
    });
  }

  Widget _buildBottomSheet(Size size, EdgeInsets padding) {
    return Container(
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
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),

          // Calendar Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '사랑이의 몸무게 총 ${weightRecords.length}일 기록 중',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      onPressed: _onPreviousPeriod,
                      iconSize: 20,
                    ),
                    Text(
                      _getPeriodLabel(),
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _onNextPeriod,
                      iconSize: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Calendar Grid
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Column(
                children: [
                  _buildCalendarHeader(),
                  const SizedBox(height: AppSpacing.sm),
                  _buildCalendarGrid(),
                  const SizedBox(height: AppSpacing.xl),

                  // Add Record Button
                  _buildAddRecordButton(size),

                  SizedBox(height: padding.bottom + AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    const weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.mediumGray,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(selectedYear, selectedMonth, 1);
    final startWeekday = firstDayOfMonth.weekday % 7; // 0 = Sunday
    final daysInMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;

    final List<Widget> dayWidgets = [];

    // Add empty cells for days before the 1st
    for (int i = 0; i < startWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Add day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final hasRecord = weightRecords.any((record) =>
          record.date.day == day &&
          record.date.month == selectedMonth &&
          record.date.year == selectedYear);

      final isFuture = DateTime(selectedYear, selectedMonth, day)
          .isAfter(DateTime(now.year, now.month, now.day));

      dayWidgets.add(_buildDayCell(day, hasRecord, isFuture: isFuture));
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.sm,
      children: dayWidgets,
    );
  }

  Widget _buildDayCell(int day, bool hasRecord, {bool isFuture = false}) {
    final cellDate = DateTime(selectedYear, selectedMonth, day);

    return GestureDetector(
      onTap: isFuture
          ? null
          : () async {
              // 특정 날짜 체중 기록 화면으로 이동
              final dateStr = cellDate.toIso8601String().split('T')[0]; // YYYY-MM-DD
              final result = await context.push(
                RoutePaths.weightAdd.replaceAll(':date', dateStr),
              );

              // 저장 후 돌아온 경우 데이터 새로고침
              if (result == true) {
                _refreshData();
              }
            },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            day.toString(),
            style: AppTypography.bodyMedium.copyWith(
              color: isFuture ? AppColors.lightGray : AppColors.mediumGray,
            ),
          ),
          const SizedBox(height: 4),
          if (hasRecord)
            Container(
              width: 16,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
            )
          else
            const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildAddRecordButton(Size size) {
    return GestureDetector(
      onTap: () async {
        // 오늘 체중 기록 화면으로 이동
        final result = await context.push(RoutePaths.weightAddToday);

        // 저장 후 돌아온 경우 데이터 새로고침
        if (result == true) {
          _refreshData();
        }
      },
      child: Container(
        width: size.width - (AppSpacing.md * 2),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.gradientTop, AppColors.brandPrimary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 20),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '오늘의 몸무게 기록하기',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

