import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/weight_record.dart';
import '../../services/pet/pet_local_cache_service.dart';
import '../../services/pet/pet_service.dart';
import '../../services/weight/weight_service.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../../l10n/app_localizations.dart';

class WeightRecordScreen extends StatefulWidget {
  const WeightRecordScreen({super.key});

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> {
  final _weightService = WeightService();
  final _petCache = PetLocalCacheService.instance;
  final _petService = PetService.instance;

  DateTime _selectedDate = DateTime.now();
  String? _activePetId;
  bool _isLoading = true;
  List<WeightRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadActivePet();
  }

  Future<void> _loadActivePet() async {
    try {
      // API 우선 조회
      final apiPet = await _petService.getActivePet();
      if (!mounted) return;
      if (apiPet != null) {
        setState(() {
          _activePetId = apiPet.id;
        });
      } else {
        // 로컬 캐시 폴백
        final cachedPet = await _petCache.getActivePet();
        if (!mounted) return;
        setState(() {
          _activePetId = cachedPet?.id;
        });
      }
      if (_activePetId != null) {
        await _loadRecords();
      }
    } catch (_) {
      // API 실패 시 로컬 캐시 폴백
      try {
        final cachedPet = await _petCache.getActivePet();
        if (!mounted) return;
        setState(() {
          _activePetId = cachedPet?.id;
        });
        if (_activePetId != null) {
          await _loadRecords();
        }
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadRecords() async {
    if (_activePetId == null) return;
    final records = await _weightService.fetchLocalRecords(petId: _activePetId);
    if (!mounted) return;
    setState(() {
      _records = records;
    });
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
  }

  WeightRecord? _recordForDate(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    for (final record in _records) {
      final recordDate = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (recordDate == normalized) {
        return record;
      }
    }
    return null;
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
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

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

  Future<void> _openWeightEditor() async {
    if (_activePetId == null) return;
    final l10n = AppLocalizations.of(context);
    final current = _recordForDate(_selectedDate);
    final controller = TextEditingController(
      text: current != null ? current.weight.toStringAsFixed(1) : '',
    );
    final weight = await showModalBottomSheet<double>(
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
              Text(
                l10n.weight_inputWeight,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: l10n.weight_inputHint,
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
                        final value = double.tryParse(controller.text.trim());
                        if (value == null) return;
                        Navigator.pop(context, value);
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

    if (weight == null) return;
    final record = WeightRecord(
      petId: _activePetId!,
      date: _selectedDate,
      weight: weight,
    );
    // 로컬 캐시에 먼저 저장
    await _weightService.saveLocalWeightRecord(record);
    // 백엔드 API에도 저장
    try {
      await _weightService.saveWeightRecord(record);
    } catch (e) {
      debugPrint('[WeightRecord] 백엔드 저장 실패: $e');
    }
    await _loadRecords();
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
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.45,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF97928A),
                            letterSpacing: -0.35,
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
                          fontFamily: 'Pretendard',
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
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _openWeightEditor,
                      child: Column(
                        children: [
                          SizedBox(
                            width: 240,
                            height: 130,
                            child: CustomPaint(
                              painter: _WciGaugePainter(
                                progress: progress,
                                activeColor: AppColors.brandPrimary,
                                trackColor: const Color(0xFFEDEDED),
                                hasData: hasData,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '${(current?.weight ?? 0).toStringAsFixed(2)}g',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color:
                                  hasData ? AppColors.nearBlack : AppColors.gray400,
                              decoration: hasData
                                  ? TextDecoration.none
                                  : TextDecoration.underline,
                              decorationColor: AppColors.gray300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasData ? level.title : 'Level 0',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: hasData ? AppColors.nearBlack : AppColors.mediumGray,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      level.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mediumGray,
                        height: 1.6,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.weight_formula,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
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
                              fontFamily: 'Pretendard',
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
                              fontFamily: 'Pretendard',
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
                              fontFamily: 'Pretendard',
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
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: _openWeightEditor,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            l10n.btn_save,
                            style: const TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.4,
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
