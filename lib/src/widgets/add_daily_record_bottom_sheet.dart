import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/daily_record.dart';
import '../services/daily_record/daily_record_service.dart';
import '../../l10n/app_localizations.dart';

class AddDailyRecordBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final String? petId;
  final Function(DailyRecord) onSave;

  const AddDailyRecordBottomSheet({
    super.key,
    required this.initialDate,
    required this.onSave,
    this.petId,
  });

  @override
  State<AddDailyRecordBottomSheet> createState() =>
      _AddDailyRecordBottomSheetState();
}

class _AddDailyRecordBottomSheetState extends State<AddDailyRecordBottomSheet> {
  late DateTime _selectedDate;
  String? _selectedMood;
  int? _activityLevel;
  bool _showCalendar = false;
  bool _isLoading = false;

  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  final _dailyRecordService = DailyRecordService();

  static const _moodOptions = [
    ('great', '😊'),
    ('good', '🙂'),
    ('normal', '😐'),
    ('bad', '😞'),
    ('sick', '🤒'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _loadExistingRecord();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExistingRecord() async {
    if (widget.petId == null) return;
    setState(() => _isLoading = true);
    try {
      final existing = await _dailyRecordService.getRecordByDate(
        widget.petId!,
        _selectedDate,
      );
      if (existing != null && mounted) {
        setState(() {
          _selectedMood = existing.mood;
          _activityLevel = existing.activityLevel;
          _notesController.text = existing.notes ?? '';
        });
      }
    } catch (_) {
      // 기존 기록 없으면 무시
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    final l10n = AppLocalizations.of(context);
    const weekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];
    const weekdaysEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const weekdaysZh = ['一', '二', '三', '四', '五', '六', '日'];

    final lang = l10n.localeName;
    List<String> weekdays;
    if (lang == 'zh') {
      weekdays = weekdaysZh;
    } else if (lang == 'en') {
      weekdays = weekdaysEn;
    } else {
      weekdays = weekdaysKo;
    }
    final weekday = weekdays[date.weekday - 1];

    if (lang == 'en') {
      return '${date.month}/${date.day} ($weekday)';
    }
    return '${date.month}월 ${date.day}일 ($weekday)';
  }

  String _moodLabel(String mood) {
    final l10n = AppLocalizations.of(context);
    switch (mood) {
      case 'great':
        return l10n.dailyRecord_moodGreat;
      case 'good':
        return l10n.dailyRecord_moodGood;
      case 'normal':
        return l10n.dailyRecord_moodNormal;
      case 'bad':
        return l10n.dailyRecord_moodBad;
      case 'sick':
        return l10n.dailyRecord_moodSick;
      default:
        return mood;
    }
  }

  void _save() {
    if (widget.petId == null || widget.petId!.isEmpty) return;

    final record = DailyRecord(
      petId: widget.petId!,
      recordedDate: _selectedDate,
      mood: _selectedMood,
      activityLevel: _activityLevel,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    widget.onSave(record);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 드래그 핸들
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 제목
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l10n.dailyRecord_title,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.nearBlack,
                          letterSpacing: -0.45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 날짜 선택
                  _buildDateSelector(),
                  if (_showCalendar) _buildCalendar(),
                  const SizedBox(height: 24),
                  // 기분 선택
                  _buildMoodSelector(l10n),
                  const SizedBox(height: 24),
                  // 활동량 선택
                  _buildActivitySelector(l10n),
                  const SizedBox(height: 24),
                  // 메모 입력
                  _buildNotesInput(l10n),
                  const SizedBox(height: 24),
                  // 버튼
                  _buildButtons(l10n),
                  SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: () => setState(() => _showCalendar = !_showCalendar),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _showCalendar
                ? AppColors.brandPrimary
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: _showCalendar ? Colors.white : AppColors.nearBlack,
              ),
              const SizedBox(width: 8),
              Text(
                _formatDate(_selectedDate),
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color:
                      _showCalendar ? Colors.white : AppColors.nearBlack,
                  letterSpacing: -0.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dailyRecord_mood,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _moodOptions.map((option) {
              final isSelected = _selectedMood == option.$1;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedMood =
                      _selectedMood == option.$1 ? null : option.$1;
                }),
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.brandPrimary.withValues(alpha: 0.12)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.brandPrimary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          option.$2,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _moodLabel(option.$1),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? AppColors.brandPrimary
                            : AppColors.mediumGray,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildActivitySelector(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dailyRecord_activity,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(5, (index) {
              final level = index + 1;
              final isActive =
                  _activityLevel != null && level <= _activityLevel!;
              return GestureDetector(
                onTap: () => setState(() {
                  _activityLevel = _activityLevel == level ? null : level;
                }),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    isActive ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: isActive
                        ? AppColors.brandPrimary
                        : const Color(0xFFD0D0D0),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesInput(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dailyRecord_notes,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            focusNode: _notesFocusNode,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.dailyRecord_notesHint,
              hintStyle: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.mediumGray,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.nearBlack,
              letterSpacing: -0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtons(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    l10n.common_cancel,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mediumGray,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: _save,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    l10n.common_save,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;

    return Container(
      margin: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  final newDate = DateTime(year, month - 1);
                  setState(() {
                    _selectedDate = DateTime(
                      newDate.year,
                      newDate.month,
                      _selectedDate.day.clamp(
                        1,
                        DateTime(newDate.year, newDate.month + 1, 0).day,
                      ),
                    );
                  });
                  _loadExistingRecord();
                },
                child: const Icon(Icons.chevron_left, size: 20),
              ),
              const SizedBox(width: 16),
              Text(
                '$year년 $month월',
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () {
                  final newDate = DateTime(year, month + 1);
                  setState(() {
                    _selectedDate = DateTime(
                      newDate.year,
                      newDate.month,
                      _selectedDate.day.clamp(
                        1,
                        DateTime(newDate.year, newDate.month + 1, 0).day,
                      ),
                    );
                  });
                  _loadExistingRecord();
                },
                child: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF97928A),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          _buildCalendarGrid(year, month),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(int year, int month) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> rows = [];
    List<Widget> currentRow = [];

    for (int i = 0; i < startWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox(height: 36)));
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final isSelected = day == _selectedDate.day &&
          month == _selectedDate.month &&
          year == _selectedDate.year;
      final isSunday = (startWeekday + day - 1) % 7 == 0;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = DateTime(year, month, day);
              });
              _loadExistingRecord();
            },
            child: Container(
              height: 36,
              alignment: Alignment.center,
              decoration: isSelected
                  ? BoxDecoration(
                      color: AppColors.brandPrimary,
                      borderRadius: BorderRadius.circular(18),
                    )
                  : null,
              child: Text(
                '$day',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isSunday
                          ? const Color(0xFFEE3300)
                          : AppColors.nearBlack,
                ),
              ),
            ),
          ),
        ),
      );

      if (currentRow.length == 7) {
        rows.add(Row(children: currentRow));
        currentRow = [];
      }
    }

    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add(const Expanded(child: SizedBox(height: 36)));
      }
      rows.add(Row(children: currentRow));
    }

    return Column(children: rows);
  }
}

/// 바텀시트 표시 함수
Future<DailyRecord?> showAddDailyRecordBottomSheet({
  required BuildContext context,
  required DateTime initialDate,
  String? petId,
}) async {
  DailyRecord? result;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddDailyRecordBottomSheet(
          initialDate: initialDate,
          petId: petId,
          onSave: (record) {
            result = record;
          },
        ),
      );
    },
  );
  return result;
}
