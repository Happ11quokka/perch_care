import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/pet/pet_service.dart';
import '../../services/food/food_record_service.dart';
import '../../theme/colors.dart';
import '../../widgets/dashed_border.dart';
import '../../router/route_names.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

class FoodRecordScreen extends StatefulWidget {
  const FoodRecordScreen({super.key});

  @override
  State<FoodRecordScreen> createState() => _FoodRecordScreenState();
}

class _FoodRecordScreenState extends State<FoodRecordScreen> {
  final _petService = PetService.instance;
  final _foodService = FoodRecordService();
  DateTime _selectedDate = DateTime.now();
  String? _activePetId;
  bool _isLoading = true;
  List<_FoodEntry> _entries = [];

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
      await _loadEntries();
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
    return 'food_${_activePetId ?? 'default'}_$date';
  }

  Future<void> _loadEntries() async {
    // Try to load from backend first
    if (_activePetId != null) {
      try {
        final record = await _foodService.getByDate(_activePetId!, _selectedDate);
        if (record != null && record.entriesJson != null) {
          final list = jsonDecode(record.entriesJson!) as List<dynamic>;
          final entries = list
              .map((item) => _FoodEntry.fromJson(item as Map<String, dynamic>))
              .toList();
          if (!mounted) return;
          setState(() {
            _entries = entries;
          });
          return;
        }
      } catch (e) {
        // Fall back to SharedPreferences if backend call fails
        print('Failed to load from backend, falling back to local storage: $e');
      }
    }

    // Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey());
    if (raw == null) {
      if (!mounted) return;
      setState(() {
        _entries = [];
      });
      return;
    }
    final list = jsonDecode(raw) as List<dynamic>;
    final entries = list
        .map((item) => _FoodEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    if (!mounted) return;
    setState(() {
      _entries = entries;
    });
  }

  Future<void> _saveEntries() async {
    // Save to SharedPreferences (for offline access)
    final prefs = await SharedPreferences.getInstance();
    final data = _entries.map((entry) => entry.toJson()).toList();
    await prefs.setString(_storageKey(), jsonEncode(data));

    // Also save to backend
    if (_activePetId != null && _entries.isNotEmpty) {
      try {
        await _foodService.upsert(
          petId: _activePetId!,
          recordedDate: _selectedDate,
          totalGrams: _totalGrams,
          targetGrams: _targetGrams,
          count: _entries.length,
          entriesJson: jsonEncode(data),
        );
      } catch (e) {
        // Don't break if backend save fails (offline mode)
        print('Failed to save to backend, data saved locally: $e');
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
    await _loadEntries();
  }

  double get _totalGrams {
    return _entries.fold(0, (sum, entry) => sum + entry.totalGrams);
  }

  double get _targetGrams {
    return _entries.fold(0, (sum, entry) => sum + entry.targetGrams);
  }

  double get _progress {
    if (_targetGrams == 0) return 0;
    return (_totalGrams / _targetGrams).clamp(0.0, 1.0);
  }

  Future<void> _openEntryEditor({int? index}) async {
    final l10n = AppLocalizations.of(context);
    final existing = index != null ? _entries[index] : null;
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final totalController = TextEditingController(
      text: existing != null ? existing.totalGrams.toStringAsFixed(0) : '',
    );
    final targetController = TextEditingController(
      text: existing != null ? existing.targetGrams.toStringAsFixed(0) : '',
    );
    final countController = TextEditingController(
      text: existing != null ? existing.count.toString() : '',
    );

    final result = await showModalBottomSheet<_FoodEntry>(
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
                existing == null ? l10n.food_addTitle : l10n.food_editTitle,
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
                controller: nameController,
                decoration: InputDecoration(
                  labelText: l10n.food_nameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: totalController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.food_totalIntake,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: l10n.food_targetAmount,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.food_intakeCount,
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
                        final name = nameController.text.trim();
                        final total = double.tryParse(totalController.text.trim());
                        final target = double.tryParse(targetController.text.trim());
                        final count = int.tryParse(countController.text.trim());
                        if (name.isEmpty || total == null || target == null || count == null) {
                          return;
                        }
                        Navigator.pop(
                          context,
                          _FoodEntry(
                            name: name,
                            totalGrams: total,
                            targetGrams: target,
                            count: count,
                          ),
                        );
                      },
                      child: Text(l10n.common_save),
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
      if (index == null) {
        _entries = [..._entries, result];
      } else {
        final updated = [..._entries];
        updated[index] = result;
        _entries = updated;
      }
    });
    await _saveEntries();
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
    final hasData = _entries.isNotEmpty;
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
          l10n.food_title,
          style: const TextStyle(
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
                          _formatDate(_selectedDate, l10n),
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
                        l10n.food_routine,
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
                      l10n.food_title,
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gray500,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SvgPicture.asset(
                      'assets/images/home_vector/eat.svg',
                      width: 80,
                      height: 80,
                      colorFilter: ColorFilter.mode(
                        hasData ? AppColors.brandPrimary : AppColors.gray300,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_totalGrams.toStringAsFixed(0)}g',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: hasData ? AppColors.nearBlack : AppColors.gray400,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (hasData) ...[
                      ..._entries.asMap().entries.map((entry) {
                        return _buildFoodCard(entry.key, entry.value, l10n);
                      }),
                      const SizedBox(height: 12),
                    ],
                    DashedBorder(
                      radius: 16,
                      color: const Color(0xFFBDBDBD),
                      strokeWidth: 1,
                      dashWidth: 6,
                      dashGap: 4,
                      child: InkWell(
                        onTap: () => _openEntryEditor(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          color: Colors.white,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEDEDED),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Color(0xFF97928A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                l10n.food_addFood,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF97928A),
                                  letterSpacing: -0.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GestureDetector(
                      onTap: () async {
                        await _saveEntries();
                        if (!mounted) return;
                        AppSnackBar.success(context, message: l10n.snackbar_saved);
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
                        child: Center(
                          child: Text(
                            l10n.common_save,
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

  Widget _buildFoodCard(int index, _FoodEntry entry, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _openEntryEditor(index: index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            Container(
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              alignment: Alignment.center,
              child: Text(
                entry.name,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.food_dailyTarget,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.nearBlack,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.food_recommendedRange(entry.recommendedMin.toInt(), entry.recommendedMax.toInt()),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.brandPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.food_dailyCount,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.nearBlack,
                            letterSpacing: -0.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.food_perMeal(entry.perMeal.toInt()),
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
                        '${entry.targetGrams.toStringAsFixed(0)}g',
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
                        l10n.food_timesCount(entry.count),
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
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations l10n) {
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

  String _formatDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }
}

class _FoodEntry {
  final String name;
  final double totalGrams;
  final double targetGrams;
  final int count;
  final double recommendedMin;
  final double recommendedMax;

  const _FoodEntry({
    required this.name,
    required this.totalGrams,
    required this.targetGrams,
    required this.count,
    this.recommendedMin = 40,
    this.recommendedMax = 60,
  });

  double get perMeal => count == 0 ? 0 : totalGrams / count;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'totalGrams': totalGrams,
      'targetGrams': targetGrams,
      'count': count,
      'recommendedMin': recommendedMin,
      'recommendedMax': recommendedMax,
    };
  }

  factory _FoodEntry.fromJson(Map<String, dynamic> json) {
    return _FoodEntry(
      name: json['name'] as String? ?? '',
      totalGrams: (json['totalGrams'] as num?)?.toDouble() ?? 0,
      targetGrams: (json['targetGrams'] as num?)?.toDouble() ?? 0,
      count: json['count'] as int? ?? 0,
      recommendedMin: (json['recommendedMin'] as num?)?.toDouble() ?? 40,
      recommendedMax: (json['recommendedMax'] as num?)?.toDouble() ?? 60,
    );
  }
}
