import 'dart:math' as math;

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
  int selectedWeekday = 1;
  List<WeightRecord> weightRecords = [];
  final _weightService = WeightService();
  final _petService = PetService();
  double _sheetHeight = 0;
  final double _peekHeight = 200.0;
  double _expandedHeight = 0;
  String _petName = '우리 새';
  String? _activePetId;
  bool _isLoadingPet = true;


  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    selectedPeriod = '월'; // 주, 월, 년
    selectedYear = now.year;
    selectedMonth = now.month;

    // 현재 월의 몇 주차인지 계산
    final weekOfMonth = ((now.day - 1) / 7).floor() + 1;
    final maxWeeks = _getWeeksInMonth(now.year, now.month);
    selectedWeek = weekOfMonth.clamp(1, maxWeeks);

    // Load active pet THEN load weight data
    Future.microtask(() async {
      await _loadActivePet();
      if (_activePetId != null) {
        await _loadWeightData();
      }
    });
  }

  /// 활성 펫 로드
  Future<void> _loadActivePet() async {
    try {
      final activePet = await _petService.getActivePet();
      if (activePet != null && mounted) {
        setState(() {
          _activePetId = activePet.id;
          _petName = activePet.name;
          _isLoadingPet = false;
        });
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPet = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPet = false;
        });
      }
    }
  }

  /// 체중 데이터 로드
  Future<void> _loadWeightData() async {
    if (_activePetId == null) return;

    final records = await _weightService.fetchAllRecords(petId: _activePetId);
    if (mounted) {
      setState(() {
        weightRecords = records;
      });
    }
  }

  /// 데이터 새로고침
  void _refreshData() {
    _loadWeightData();
  }

  // weightRecords에서 월별 평균 계산 (연도+월 기준)
  Map<DateTime, double> _calculateMonthlyAverages() {
    final Map<DateTime, List<double>> monthlyData = {};

    // 연도와 월 단위로 데이터 그룹화
    for (final record in weightRecords) {
      final monthKey = DateTime(record.date.year, record.date.month);
      monthlyData.putIfAbsent(monthKey, () => []);
      monthlyData[monthKey]!.add(record.weight);
    }

    // 월별 평균 계산
    final Map<DateTime, double> averages = {};
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
  Map<int, double> _calculateYearlyAverages() {
    final Map<int, List<double>> yearlyData = {};

    for (final record in weightRecords) {
      final year = record.date.year;
      yearlyData.putIfAbsent(year, () => []);
      yearlyData[year]!.add(record.weight);
    }

    final Map<int, double> averages = {};
    yearlyData.forEach((year, weights) {
      averages[year] = weights.reduce((a, b) => a + b) / weights.length;
    });

    return averages;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;

    // Show loading state while fetching active pet
    if (_isLoadingPet) {
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show empty state if no active pet
    if (_activePetId == null) {
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
        body: const Center(
          child: Text('활성화된 펫이 없습니다. 펫을 먼저 추가해주세요.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final calculatedExpanded = constraints.maxHeight * 0.6;
            final maxHeightLimit = constraints.maxHeight - AppSpacing.md;
            final safeUpperBound =
                maxHeightLimit < _peekHeight ? _peekHeight : maxHeightLimit;
            _expandedHeight = calculatedExpanded.clamp(
              _peekHeight,
              safeUpperBound,
            );
            if (_sheetHeight == 0) {
              _sheetHeight = _expandedHeight;
            } else {
              _sheetHeight =
                  _sheetHeight.clamp(_peekHeight, _expandedHeight);
            }

            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: _expandedHeight + AppSpacing.xl,
                    ),
                    child: _buildTopSection(size),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildBottomSheet(size, padding),
                ),
              ],
            );
          },
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
            '$_petName 체중 변화를 한 눈에!',
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
    final baseWidth = size.width - (AppSpacing.md * 2);
    final chartHeight = 200.0;
    final weekdays = ['일', '월', '화', '수', '목', '금', '토'];
    final weeklyData = _calculateWeeklyData(selectedYear, selectedMonth, selectedWeek);
    final filteredWeeklyData = {
      for (int day = 1; day <= 7; day++) day: weeklyData[day] ?? 0,
    };
    final chartWidth = _calculateScrollableWidth(
      baseWidth: baseWidth,
      totalPoints: 7,
    );
    final chartMinX = 0.5;
    final chartMaxX = 7.5;
    final highlightedDay = _determineHighlightedWeekday();
    final selectedValue = filteredWeeklyData[highlightedDay] ?? 0;
    final highlightLabel = '${weekdays[highlightedDay - 1]}요일';
    final minY = _getMinY(filteredWeeklyData);
    final maxY = _getMaxY(filteredWeeklyData);
    final chartPadding = EdgeInsets.only(
      top: AppSpacing.md,
      bottom: AppSpacing.lg,
      left: AppSpacing.sm,
      right: AppSpacing.sm,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: chartHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: CustomPaint(
                  painter: _MonthlyGuideLinePainter(
                    itemCount: 7,
                    minX: chartMinX,
                    maxX: chartMaxX,
                    selectedPosition: highlightedDay.toDouble(),
                    selectedValue: selectedValue,
                    selectedLabel: highlightLabel,
                    drawBackground: true,
                    drawLabel: false,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: LineChart(
                  LineChartData(
                    minX: chartMinX,
                    maxX: chartMaxX,
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _convertMapToFlSpots(filteredWeeklyData),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppColors.mediumGray,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dashArray: const [8, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            final isHighlighted = spot.x.toInt() == highlightedDay;
                            if (isHighlighted) {
                              return FlDotCirclePainter(
                                radius: 10,
                                color: Colors.white,
                                strokeWidth: 4,
                                strokeColor: AppColors.brandPrimary,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: 6,
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
                            if ((value - value.round()).abs() > 0.01) {
                              return const SizedBox();
                            }
                            final day = value.toInt();
                            if (day < 1 || day > 7) return const SizedBox();
                            final isHighlighted = day == highlightedDay;
                            return Text(
                              weekdays[day - 1],
                              style: AppTypography.bodySmall.copyWith(
                                color: isHighlighted
                                    ? AppColors.brandPrimary
                                    : AppColors.mediumGray,
                                fontWeight:
                                    isHighlighted ? FontWeight.w600 : FontWeight.w400,
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
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MonthlyGuideLinePainter(
                      itemCount: 7,
                      minX: chartMinX,
                      maxX: chartMaxX,
                      selectedPosition: highlightedDay.toDouble(),
                      selectedValue: selectedValue,
                      selectedLabel: highlightLabel,
                      drawBackground: false,
                      drawLabel: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 월간 차트 (최근 6개월)
  Widget _buildMonthlyChart(Size size) {
    final baseWidth = size.width - (AppSpacing.md * 2);
    final chartHeight = 200.0;

    // 실제 저장된 데이터에서 월별 평균 계산
    final monthlyAverages = _calculateMonthlyAverages();
    final displayedMonths = _generateDisplayMonths(
      centerYear: selectedYear,
      centerMonth: selectedMonth,
    );
    final totalMonths = displayedMonths.length;
    final selectedIndex = totalMonths >= 4 ? 3 : math.max(0, totalMonths - 1);
    final filteredMonthlyAverages = {
      for (int i = 0; i < displayedMonths.length; i++)
        i + 1: monthlyAverages[displayedMonths[i]] ?? 0,
    };
    final hasMonths = totalMonths > 0;
    final chartMinX = hasMonths ? 0.5 : 0.0;
    final chartMaxX = hasMonths ? totalMonths + 0.5 : 0.0;
    final selectedKey = selectedIndex + 1;
    final selectedValue = filteredMonthlyAverages[selectedKey] ?? 0;
    final selectedMonthLabel = totalMonths > selectedIndex
        ? _formatYearMonth(displayedMonths[selectedIndex])
        : '';
    final chartWidth = _calculateScrollableWidth(
      baseWidth: baseWidth,
      totalPoints: totalMonths,
    );
    final minY = _getMinY(filteredMonthlyAverages);
    final maxY = _getMaxY(filteredMonthlyAverages);
    final chartPadding = EdgeInsets.only(
      top: AppSpacing.md,
      bottom: AppSpacing.lg,
      left: AppSpacing.sm,
      right: AppSpacing.sm,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: chartHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: CustomPaint(
                  painter: _MonthlyGuideLinePainter(
                    itemCount: totalMonths,
                    minX: chartMinX,
                    maxX: chartMaxX,
                    selectedPosition: selectedKey.toDouble(),
                    selectedValue: selectedValue,
                    selectedLabel: selectedMonthLabel,
                    drawBackground: true,
                    drawLabel: false,
                    ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: LineChart(
                  LineChartData(
                    minX: chartMinX,
                    maxX: chartMaxX,
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _convertMapToFlSpots(filteredMonthlyAverages),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppColors.mediumGray,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dashArray: const [8, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            final isHighlighted = spot.x.toInt() == selectedKey;

                            if (isHighlighted) {
                              return FlDotCirclePainter(
                                radius: 10,
                                color: Colors.white,
                                strokeWidth: 4,
                                strokeColor: AppColors.brandPrimary,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: 6,
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
                            if ((value - value.round()).abs() > 0.01) {
                              return const SizedBox();
                            }
                            final index = value.toInt() - 1;
                            if (index < 0 || index >= displayedMonths.length) {
                              return const SizedBox();
                            }

                            final isHighlighted = (index + 1) == selectedKey;
                            final month = displayedMonths[index];

                            return Text(
                              _formatYearMonth(month),
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
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MonthlyGuideLinePainter(
                      itemCount: totalMonths,
                      minX: chartMinX,
                      maxX: chartMaxX,
                      selectedPosition: selectedKey.toDouble(),
                      selectedValue: selectedValue,
                      selectedLabel: selectedMonthLabel,
                      drawBackground: false,
                      drawLabel: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 연간 차트 (1~12월)
  Widget _buildYearlyChart(Size size) {
    final baseWidth = size.width - (AppSpacing.md * 2);
    final chartHeight = 200.0;
    final yearlyAverages = _calculateYearlyAverages();
    final displayedYears = _generateDisplayYears(selectedYear);
    final totalYears = displayedYears.length;
    final selectedIndex = displayedYears.indexOf(selectedYear).clamp(0, totalYears - 1);
    final filteredYearlyData = {
      for (int i = 0; i < displayedYears.length; i++)
        i + 1: yearlyAverages[displayedYears[i]] ?? 0,
    };
    final chartWidth = _calculateScrollableWidth(
      baseWidth: baseWidth,
      totalPoints: totalYears,
    );
    final chartMinX = totalYears > 0 ? 0.5 : 0.0;
    final chartMaxX = totalYears > 0 ? totalYears + 0.5 : 0.0;
    final selectedKey = selectedIndex + 1;
    final selectedValue = filteredYearlyData[selectedKey] ?? 0;
    final selectedYearLabel =
        totalYears > selectedIndex ? '${displayedYears[selectedIndex]}년' : '';
    final minY = _getMinY(filteredYearlyData);
    final maxY = _getMaxY(filteredYearlyData);
    final chartPadding = EdgeInsets.only(
      top: AppSpacing.md,
      bottom: AppSpacing.lg,
      left: AppSpacing.sm,
      right: AppSpacing.sm,
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: chartWidth,
        height: chartHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: CustomPaint(
                  painter: _MonthlyGuideLinePainter(
                    itemCount: totalYears,
                    minX: chartMinX,
                    maxX: chartMaxX,
                    selectedPosition: selectedKey.toDouble(),
                    selectedValue: selectedValue,
                    selectedLabel: selectedYearLabel,
                    drawBackground: true,
                    drawLabel: false,
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: LineChart(
                  LineChartData(
                    minX: chartMinX,
                    maxX: chartMaxX,
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: [
                      LineChartBarData(
                        spots: _convertMapToFlSpots(filteredYearlyData),
                        isCurved: true,
                        curveSmoothness: 0.35,
                        color: AppColors.mediumGray,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dashArray: const [8, 4],
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            final isHighlighted = spot.x.toInt() == selectedKey;
                            if (isHighlighted) {
                              return FlDotCirclePainter(
                                radius: 10,
                                color: Colors.white,
                                strokeWidth: 4,
                                strokeColor: AppColors.brandPrimary,
                              );
                            }
                            return FlDotCirclePainter(
                              radius: 6,
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
                            if ((value - value.round()).abs() > 0.01) {
                              return const SizedBox();
                            }
                            final index = value.toInt() - 1;
                            if (index < 0 || index >= displayedYears.length) {
                              return const SizedBox();
                            }
                            final year = displayedYears[index];
                            final isHighlighted = (index + 1) == selectedKey;
                            return Text(
                              '$year년',
                              style: AppTypography.bodySmall.copyWith(
                                color: isHighlighted
                                    ? AppColors.brandPrimary
                                    : AppColors.mediumGray,
                                fontWeight:
                                    isHighlighted ? FontWeight.w600 : FontWeight.w400,
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
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: chartPadding,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _MonthlyGuideLinePainter(
                      itemCount: totalYears,
                      minX: chartMinX,
                      maxX: chartMaxX,
                      selectedPosition: selectedKey.toDouble(),
                      selectedValue: selectedValue,
                      selectedLabel: selectedYearLabel,
                      drawBackground: false,
                      drawLabel: true,
                    ),
                  ),
                ),
              ),
            ),
          ],
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

  // 차트가 6개의 데이터만 한 화면에 표시하고 나머지는 스크롤되도록 너비 계산
  double _calculateScrollableWidth({
    required double baseWidth,
    required int totalPoints,
    int visiblePoints = 6,
  }) {
    if (totalPoints <= visiblePoints || totalPoints == 0) {
      return baseWidth;
    }
    return baseWidth * (totalPoints / visiblePoints);
  }

  int _determineHighlightedWeekday() {
    final now = DateTime.now();
    final currentWeekOfMonth = ((now.day - 1) / 7).floor() + 1;
    final isCurrentWeek = now.year == selectedYear &&
        now.month == selectedMonth &&
        currentWeekOfMonth == selectedWeek;
    if (isCurrentWeek) {
      final weekday = now.weekday % 7;
      return weekday + 1;
    }
    return 4;
  }

  List<DateTime> _generateDisplayMonths({
    required int centerYear,
    required int centerMonth,
    int visibleCount = 6,
    int anchorIndex = 3,
  }) {
    if (visibleCount <= 0) return [];
    return List<DateTime>.generate(visibleCount, (index) {
      final offset = index - anchorIndex;
      return DateTime(centerYear, centerMonth + offset, 1);
    });
  }

  String _formatYearMonth(DateTime date) {
    return '${date.year}년 ${date.month}월';
  }

  List<int> _generateDisplayYears(int centerYear,
      {int visibleCount = 6, int anchorIndex = 3}) {
    if (visibleCount <= 0) return [];
    final List<int> years = [];
    for (int index = 0; index < visibleCount; index++) {
      final offset = index - anchorIndex;
      years.add(centerYear + offset);
    }
    return years;
  }

  int _getWeeksInMonth(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final totalDays = DateTime(year, month + 1, 0).day;
    final firstWeekday = firstDay.weekday; // 1=Mon, 7=Sun
    final leadingDays = (firstWeekday % 7);
    return ((leadingDays + totalDays) / 7).ceil();
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
          if (selectedWeek > 1) {
            selectedWeek--;
          } else {
            if (selectedMonth == 1) {
              selectedYear--;
              selectedMonth = 12;
            } else {
              selectedMonth--;
            }
            selectedWeek = _getWeeksInMonth(selectedYear, selectedMonth);
          }
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
          final maxWeeks = _getWeeksInMonth(selectedYear, selectedMonth);
          if (selectedWeek < maxWeeks) {
            selectedWeek++;
          } else {
            if (selectedMonth == 12) {
              selectedYear++;
              selectedMonth = 1;
            } else {
              selectedMonth++;
            }
            selectedWeek = 1;
          }
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

  // 선택된 요일 업데이트 (현재 주인 경우 오늘 요일, 아니면 기존 유지)
  void _updateSelectedWeekday(DateTime now) {
    final currentWeekOfMonth = ((now.day - 1) / 7).floor() + 1;
    final isCurrentWeek = now.year == selectedYear &&
        now.month == selectedMonth &&
        currentWeekOfMonth == selectedWeek;

    if (isCurrentWeek) {
      selectedWeekday = (now.weekday % 7) + 1;
    }
    // 현재 주가 아니면 기존 selectedWeekday 유지
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
          _sheetHeight =
              _sheetHeight > midPoint ? _expandedHeight : _peekHeight;
        });
      },
      onTap: () {
        setState(() {
          _sheetHeight =
              _sheetHeight == _peekHeight ? _expandedHeight : _peekHeight;
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
                    '$_petName의 몸무게 총 ${weightRecords.length}일 기록 중',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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

class _MonthlyGuideLinePainter extends CustomPainter {
  _MonthlyGuideLinePainter({
    required this.itemCount,
    required this.minX,
    required this.maxX,
    required this.selectedPosition,
    required this.selectedValue,
    required this.selectedLabel,
    this.lineHeightFactor = 0.7,
    this.drawBackground = true,
    this.drawLabel = false,
  });

  final int itemCount;
  final double minX;
  final double maxX;
  final double selectedPosition;
  final double selectedValue;
  final String selectedLabel;
  final double lineHeightFactor;
  final bool drawBackground;
  final bool drawLabel;

  @override
  void paint(Canvas canvas, Size size) {
    if (itemCount <= 0) return;
    final availableWidth = size.width;
    final bottomY = size.height;
    final lineHeight = size.height * lineHeightFactor;
    final Paint divisionPaint = Paint()
      ..color = AppColors.lightGray
      ..strokeWidth = 0.7;

    double _dxForValue(double value) {
      if ((maxX - minX).abs() < 0.0001) {
        return availableWidth / 2;
      }
      final ratio = (value - minX) / (maxX - minX);
      return ratio.clamp(0.0, 1.0) * availableWidth;
    }

    if (drawBackground) {
      for (int i = 0; i <= itemCount; i++) {
        final boundaryValue = (i - 0.5).toDouble();
        final dx = _dxForValue(boundaryValue);
        canvas.drawLine(
          Offset(dx, bottomY),
          Offset(dx, bottomY - lineHeight),
          divisionPaint,
        );
      }
    }

    if (itemCount <= 0) return;

    final highlightWidth = math.min(48.0, availableWidth * 0.45);
    final highlightHeight = math.min(size.height, lineHeight + 35);
    if (selectedPosition < minX || selectedPosition > maxX) return;
    final dx = _dxForValue(selectedPosition);
    final Rect highlightRect = Rect.fromCenter(
      center: Offset(dx, bottomY - highlightHeight / 2),
      width: highlightWidth,
      height: highlightHeight,
    );

    if (drawBackground) {
      final RRect rrect = RRect.fromRectAndRadius(
        highlightRect,
        const Radius.circular(18),
      );
      final Paint highlightPaint = Paint()..color = AppColors.brandPrimary;
      canvas.drawRRect(rrect, highlightPaint);
    }

    if (drawLabel) {
      final valueText = selectedValue > 0
          ? '${selectedValue.toStringAsFixed(1)} g'
          : '-- g';
      final valuePainter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textAlign: TextAlign.center,
      )..layout(maxWidth: highlightWidth - 12);

      final monthPainter = TextPainter(
        text: TextSpan(
          text: selectedLabel,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textAlign: TextAlign.center,
      )..layout(maxWidth: highlightWidth - 12);

      final double upperOffset = math.max(
        highlightRect.top + AppSpacing.xs,
        0,
      ).toDouble();
      final double lowerOffset = math.min(
        highlightRect.bottom - monthPainter.height - AppSpacing.xs,
        size.height,
      ).toDouble();

      valuePainter.paint(
        canvas,
        Offset(
          dx - (valuePainter.width / 2),
          upperOffset,
        ),
      );
      monthPainter.paint(
        canvas,
        Offset(
          dx - (monthPainter.width / 2),
          lowerOffset,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyGuideLinePainter oldDelegate) {
    return itemCount != oldDelegate.itemCount ||
        minX != oldDelegate.minX ||
        maxX != oldDelegate.maxX ||
        selectedPosition != oldDelegate.selectedPosition ||
        selectedValue != oldDelegate.selectedValue ||
        selectedLabel != oldDelegate.selectedLabel ||
        drawBackground != oldDelegate.drawBackground ||
        drawLabel != oldDelegate.drawLabel;
  }
}
