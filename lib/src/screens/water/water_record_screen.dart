import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/pet/pet_service.dart';
import '../../services/water/water_record_service.dart';
import '../../theme/colors.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/progress_ring.dart';
import '../../router/route_names.dart';

class WaterRecordScreen extends StatefulWidget {
  const WaterRecordScreen({super.key});

  @override
  State<WaterRecordScreen> createState() => _WaterRecordScreenState();
}

class _WaterRecordScreenState extends State<WaterRecordScreen> {
  final _petService = PetService();
  final _waterService = WaterRecordService();
  DateTime _selectedDate = DateTime.now();
  String? _activePetId;
  bool _isLoading = true;

  double _totalMl = 0;
  int _count = 0;
  final double _goalMl = 270;

  @override
  void initState() {
    super.initState();
    _loadActivePet();
  }

  Future<void> _loadActivePet() async {
    try {
      final pet = await _petService.getActivePet();
      if (!mounted) return;
      setState(() {
        _activePetId = pet?.id;
      });
      await _loadRecord();
    } catch (_) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _storageKey() {
    final date = _formatDateKey(_selectedDate);
    return 'water_${_activePetId ?? 'default'}_$date';
  }

  Future<void> _loadRecord() async {
    // Try loading from backend first
    if (_activePetId != null) {
      try {
        final record = await _waterService.getByDate(
          _activePetId!,
          _selectedDate,
        );
        if (!mounted) return;
        if (record != null) {
          setState(() {
            _totalMl = record.totalMl;
            _count = record.count;
          });
          return;
        }
      } catch (_) {
        // Fall back to SharedPreferences if backend fails
      }
    }

    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey());
    if (raw == null) {
      if (!mounted) return;
      setState(() {
        _totalMl = 0;
        _count = 0;
      });
      return;
    }
    final map = jsonDecode(raw) as Map<String, dynamic>;
    if (!mounted) return;
    setState(() {
      _totalMl = (map['totalMl'] as num?)?.toDouble() ?? 0;
      _count = map['count'] as int? ?? 0;
    });
  }

  Future<void> _saveRecord() async {
    // Save to SharedPreferences first (for offline access)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey(),
      jsonEncode({
        'totalMl': _totalMl,
        'count': _count,
      }),
    );

    // Also save to backend
    if (_activePetId != null) {
      try {
        await _waterService.upsert(
          petId: _activePetId!,
          recordedDate: _selectedDate,
          totalMl: _totalMl,
          targetMl: _goalMl,
          count: _count,
        );
      } catch (_) {
        // Fail silently if offline - data is already saved to SharedPreferences
      }
    }
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

  double get _progress {
    if (_goalMl == 0) return 0;
    return (_totalMl / _goalMl).clamp(0.0, 1.0);
  }

  double get _perDrink => _count == 0 ? 0 : _totalMl / _count;

  Future<void> _openEditor() async {
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
              const Text(
                '음수량 입력',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '총 음수량(ml)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '섭취 횟수(회)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('취소'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final total = double.tryParse(totalController.text.trim());
                        final count = int.tryParse(countController.text.trim());
                        if (total == null || count == null) return;
                        Navigator.pop(
                          context,
                          _WaterEditResult(totalMl: total, count: count),
                        );
                      },
                      child: const Text('저장'),
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
        title: const Text(
          '수분',
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
                        '수분 섭취 루틴',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '물',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openEditor,
                      child: Column(
                        children: [
                          ProgressRing(
                            value: _progress,
                            size: 140,
                            strokeWidth: 10,
                            activeColor: AppColors.brandPrimary,
                            trackColor: const Color(0xFFEDEDED),
                            child: SvgPicture.asset(
                              'assets/images/home_vector/water.svg',
                              width: 32,
                              height: 32,
                              colorFilter: ColorFilter.mode(
                                hasData
                                    ? AppColors.brandPrimary
                                    : AppColors.gray300,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${_totalMl.toStringAsFixed(0)}ml',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color:
                                  hasData ? AppColors.nearBlack : AppColors.gray400,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBDBDBD)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '1일 목표 음수량',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.nearBlack,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '권장 음수량: ${_goalMl.toStringAsFixed(0)}ml/일',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.brandPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  '1일 섭취 횟수',
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.nearBlack,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '1회 당: ${_perDrink.toStringAsFixed(0)}ml씩',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
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
                                  fontFamily: 'Pretendard',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.nearBlack,
                                  letterSpacing: -0.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                '${_count}회',
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
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
                    GestureDetector(
                      onTap: () async {
                        await _saveRecord();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('저장되었습니다.')),
                        );
                      },
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
                        child: const Center(
                          child: Text(
                            '저장',
                            style: TextStyle(
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
      bottomNavigationBar: const BottomNavBar(currentIndex: 1),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.year}년 ${date.month}월 ${date.day}일 ($weekday)';
  }

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

class _WaterEditResult {
  final double totalMl;
  final int count;

  const _WaterEditResult({
    required this.totalMl,
    required this.count,
  });
}
