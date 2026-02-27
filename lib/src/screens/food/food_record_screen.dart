import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/diet_entry.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/pet/pet_service.dart';
import '../../services/food/food_record_service.dart';
import '../../theme/colors.dart';
import '../../widgets/dashed_border.dart';
import '../../widgets/analog_time_picker.dart';
import '../../widgets/app_snack_bar.dart';
import '../../router/route_names.dart';
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
  bool _showServing = true; // true=배식 탭, false=취식 탭
  List<DietEntry> _entries = [];
  List<String> _pastFoodNames = [];

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
      await _loadFoodNameSuggestions();
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
          final entries = list.map((item) {
            final map = item as Map<String, dynamic>;
            if (map.containsKey('type')) {
              return DietEntry.fromJson(map);
            } else {
              return DietEntry.fromLegacyJson(map);
            }
          }).toList();
          if (!mounted) return;
          setState(() {
            _entries = entries;
          });
          await _updateFoodNameSuggestions();
          return;
        }
      } catch (e) {
        debugPrint('Failed to load from backend, falling back to local storage: $e');
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
    final entries = list.map((item) {
      final map = item as Map<String, dynamic>;
      if (map.containsKey('type')) {
        return DietEntry.fromJson(map);
      } else {
        return DietEntry.fromLegacyJson(map);
      }
    }).toList();
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
    if (_activePetId != null) {
      try {
        await _foodService.upsert(
          petId: _activePetId!,
          recordedDate: _selectedDate,
          totalGrams: _totalEaten,     // 취식 총량을 기존 totalGrams로 전송 (하위 호환)
          targetGrams: _totalServed,   // 배식 총량을 기존 targetGrams로 전송
          count: _entries.length,
          entriesJson: jsonEncode(data),
        );
      } catch (e) {
        debugPrint('Failed to save to backend, data saved locally: $e');
      }
    }
    AnalyticsService.instance.logFoodRecorded(_activePetId ?? '', _entries.length);
    await _updateFoodNameSuggestions();
  }

  String _foodNamesSuggestionKey() =>
      'food_names_${_activePetId ?? 'default'}';

  Future<void> _loadFoodNameSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_foodNamesSuggestionKey());
    if (existing != null) {
      if (!mounted) return;
      setState(() => _pastFoodNames = existing);
      return;
    }
    // Migration: scan existing food_* keys for this pet
    final prefix = 'food_${_activePetId ?? 'default'}_';
    final allKeys = prefs.getKeys().where(
      (k) => k.startsWith(prefix) && !k.startsWith('food_names_'),
    );
    final names = <String>{};
    for (final key in allKeys) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        for (final item in list) {
          final map = item as Map<String, dynamic>;
          final name = (map['foodName'] ?? map['name'] ?? '') as String;
          if (name.isNotEmpty) names.add(name);
        }
      } catch (_) {}
    }
    final namesList = names.toList();
    await prefs.setStringList(_foodNamesSuggestionKey(), namesList);
    if (!mounted) return;
    setState(() => _pastFoodNames = namesList);
  }

  Future<void> _updateFoodNameSuggestions() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_foodNamesSuggestionKey()) ?? [];
    final currentSet = current.toSet();
    final newNames = <String>[];
    for (final entry in _entries) {
      if (entry.foodName.isNotEmpty && !currentSet.contains(entry.foodName)) {
        currentSet.add(entry.foodName);
        newNames.add(entry.foodName);
      }
    }
    if (newNames.isNotEmpty) {
      final updated = [...current, ...newNames];
      await prefs.setStringList(_foodNamesSuggestionKey(), updated);
      if (!mounted) return;
      setState(() => _pastFoodNames = updated);
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

  // ── 계산 프로퍼티 ──────────────────────────────────────────────────────────

  List<DietEntry> get _servingEntries =>
      _entries.where((e) => e.type == DietType.serving).toList();

  List<DietEntry> get _eatingEntries =>
      _entries.where((e) => e.type == DietType.eating).toList();

  double get _totalServed =>
      _servingEntries.fold(0.0, (sum, e) => sum + e.grams);

  double get _totalEaten =>
      _eatingEntries.fold(0.0, (sum, e) => sum + e.grams);

  int get _eatingRatePercent => _totalServed > 0
      ? ((_totalEaten / _totalServed) * 100).round().clamp(0, 999)
      : 0;

  // ── 기록 삭제 ──────────────────────────────────────────────────────────────

  void _deleteEntry(DietEntry entry) {
    setState(() {
      _entries = _entries.where((e) => !identical(e, entry)).toList();
    });
    _saveEntries();
  }

  // ── 기록 추가/수정 모달 ──────────────────────────────────────────────────────

  Future<void> _openEntryModal({DietEntry? existing}) async {
    final l10n = AppLocalizations.of(context);
    final isEditing = existing != null;

    // 수정 시 기존 값, 추가 시 현재 탭 기본값
    DietType selectedType = existing?.type ?? (_showServing ? DietType.serving : DietType.eating);
    final nameController = TextEditingController(text: existing?.foodName ?? '');
    final gramsController = TextEditingController(
      text: existing != null ? existing.grams.toStringAsFixed(1) : '',
    );
    final memoController = TextEditingController(text: existing?.memo ?? '');
    TimeOfDay? selectedTime = existing?.hasTime == true
        ? TimeOfDay(hour: existing!.recordedHour!, minute: existing.recordedMinute!)
        : null;

    final result = await showModalBottomSheet<DietEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 타이틀
                    Text(
                      isEditing ? l10n.diet_editRecord : l10n.diet_addRecord,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 배식/취식 라디오
                    Text(
                      l10n.diet_selectType,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildRadioOption(
                          label: l10n.diet_serving,
                          value: DietType.serving,
                          groupValue: selectedType,
                          onChanged: (v) => setModalState(() => selectedType = v!),
                        ),
                        const SizedBox(width: 24),
                        _buildRadioOption(
                          label: l10n.diet_eating,
                          value: DietType.eating,
                          groupValue: selectedType,
                          onChanged: (v) => setModalState(() => selectedType = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 음식 이름
                    TextField(
                      controller: nameController,
                      onTapOutside: (event) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        labelText: l10n.diet_foodName,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                      ),
                    ),
                    if (_pastFoodNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          l10n.diet_recentFoods,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mediumGray,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _pastFoodNames.reversed.take(10).map((name) {
                          return GestureDetector(
                            onTap: () {
                              nameController.text = name;
                              nameController.selection = TextSelection.fromPosition(
                                TextPosition(offset: name.length),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gray100,
                                borderRadius: BorderRadius.circular(9999),
                                border: Border.all(color: AppColors.gray300, width: 0.5),
                              ),
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.nearBlack,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // 양(g)
                    TextField(
                      controller: gramsController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onTapOutside: (event) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        labelText: l10n.diet_amount,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 시간 선택
                    GestureDetector(
                      onTap: () async {
                        final time = await showAnalogTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (time != null) {
                          setModalState(() => selectedTime = time);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFBDBDBD)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 18,
                              color: AppColors.mediumGray,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              selectedTime != null
                                  ? _formatTimeOfDay(selectedTime!)
                                  : l10n.diet_selectTime,
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 14,
                                color: selectedTime != null
                                    ? AppColors.nearBlack
                                    : AppColors.mediumGray,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 메모 (선택)
                    TextField(
                      controller: memoController,
                      onTapOutside: (event) => FocusScope.of(context).unfocus(),
                      decoration: InputDecoration(
                        labelText: l10n.diet_memo,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 취소/저장 버튼
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              l10n.common_cancel,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppColors.mediumGray,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              final name = nameController.text.trim();
                              final grams = double.tryParse(gramsController.text.trim());
                              if (name.isEmpty || grams == null || grams <= 0) return;
                              Navigator.pop(
                                context,
                                DietEntry(
                                  foodName: name,
                                  type: selectedType,
                                  grams: grams,
                                  recordedHour: selectedTime?.hour,
                                  recordedMinute: selectedTime?.minute,
                                  memo: memoController.text.trim().isEmpty
                                      ? null
                                      : memoController.text.trim(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      if (existing != null) {
        // 수정: 기존 엔트리를 교체
        final index = _entries.indexOf(existing);
        if (index != -1) {
          _entries = [..._entries]..[index] = result;
        }
      } else {
        // 추가: 새 엔트리 추가
        _entries = [..._entries, result];
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

  // ── 헬퍼 ──────────────────────────────────────────────────────────────────

  String _formatTimeOfDay(TimeOfDay time) {
    final isAM = time.hour < 12;
    final hour = time.hour == 0
        ? 12
        : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = isAM ? '오전' : '오후';
    return '$period $hour:$minute';
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

  // ── 빌드 ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasAnyData = _entries.isNotEmpty;
    final currentEntries = _showServing ? _servingEntries : _eatingEntries;

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
                    // ── 날짜 선택 pill ────────────────────────────────────
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

                    // ── 요약 영역 ─────────────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.food_routine,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SvgPicture.asset(
                      'assets/images/home_vector/eat.svg',
                      width: 72,
                      height: 72,
                      colorFilter: ColorFilter.mode(
                        hasAnyData ? AppColors.brandPrimary : AppColors.gray300,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow(l10n),
                    const SizedBox(height: 24),

                    // ── 배식/취식 토글 ────────────────────────────────────
                    _buildTypeToggle(l10n),
                    const SizedBox(height: 16),

                    // ── 기록 리스트 ───────────────────────────────────────
                    if (currentEntries.isNotEmpty) ...[
                      ...currentEntries.map(
                        (entry) => _buildEntryCard(entry),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── 기록 추가 버튼 ────────────────────────────────────
                    DashedBorder(
                      radius: 16,
                      color: const Color(0xFFBDBDBD),
                      strokeWidth: 1,
                      dashWidth: 6,
                      dashGap: 4,
                      child: InkWell(
                        onTap: _openEntryModal,
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
                                _showServing
                                    ? l10n.diet_addServing
                                    : l10n.diet_addEating,
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

                    // ── 저장 버튼 ─────────────────────────────────────────
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

  // ── 요약 행 (배식량 | 취식량 | 취식률) ────────────────────────────────────

  Widget _buildSummaryRow(AppLocalizations l10n) {
    final hasData = _entries.isNotEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSummaryItem(
          label: l10n.diet_totalServed,
          value: '${_totalServed.toStringAsFixed(0)}g',
          hasData: _servingEntries.isNotEmpty,
        ),
        _buildSummaryDivider(),
        _buildSummaryItem(
          label: l10n.diet_totalEaten,
          value: '${_totalEaten.toStringAsFixed(0)}g',
          hasData: _eatingEntries.isNotEmpty,
        ),
        _buildSummaryDivider(),
        _buildSummaryItem(
          label: l10n.diet_eatingRate,
          value: l10n.diet_eatingRateValue(_eatingRatePercent),
          hasData: hasData,
          isHighlight: _eatingRatePercent >= 80,
        ),
      ],
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required bool hasData,
    bool isHighlight = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.mediumGray,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: hasData
                ? (isHighlight ? AppColors.brandPrimary : AppColors.nearBlack)
                : AppColors.gray400,
            letterSpacing: -0.45,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      height: 32,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: const Color(0xFFE0E0E0),
    );
  }

  // ── 배식/취식 토글 ─────────────────────────────────────────────────────────

  Widget _buildTypeToggle(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToggleButton(
            text: l10n.diet_serving,
            isActive: _showServing,
            onTap: () => setState(() => _showServing = true),
          ),
          _buildToggleButton(
            text: l10n.diet_eating,
            isActive: !_showServing,
            onTap: () => setState(() => _showServing = false),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.brandPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.mediumGray,
          ),
        ),
      ),
    );
  }

  // ── 기록 카드 ──────────────────────────────────────────────────────────────

  Widget _buildEntryCard(DietEntry entry) {
    return GestureDetector(
      onTap: () => _openEntryModal(existing: entry),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          // 시간 표시
          if (entry.hasTime) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.timeDisplayString,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          // 음식 이름
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.foodName,
                  style: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.nearBlack,
                    letterSpacing: -0.35,
                  ),
                ),
                if (entry.memo != null && entry.memo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.memo!,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.mediumGray,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 양
          Text(
            '${entry.grams.toStringAsFixed(1)}g',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
              letterSpacing: -0.35,
            ),
          ),
          // 삭제 버튼
          GestureDetector(
            onTap: () => _deleteEntry(entry),
            child: Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.all(4),
              child: const Icon(
                Icons.close,
                size: 16,
                color: AppColors.mediumGray,
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── 라디오 옵션 ────────────────────────────────────────────────────────────

  Widget _buildRadioOption({
    required String label,
    required DietType value,
    required DietType groupValue,
    required ValueChanged<DietType?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppColors.brandPrimary : AppColors.lightGray,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandPrimary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.nearBlack : AppColors.mediumGray,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
