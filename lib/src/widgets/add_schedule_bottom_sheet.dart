import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../models/schedule_record.dart';
import 'analog_time_picker.dart';

class AddScheduleBottomSheet extends StatefulWidget {
  final DateTime initialDate;
  final Function(ScheduleRecord) onSave;

  const AddScheduleBottomSheet({
    super.key,
    required this.initialDate,
    required this.onSave,
  });

  @override
  State<AddScheduleBottomSheet> createState() => _AddScheduleBottomSheetState();
}

class _AddScheduleBottomSheetState extends State<AddScheduleBottomSheet> {
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  String _title = '';
  Color _selectedColor = ScheduleRecord.colorPalette[0];
  final int _reminderMinutes = 10;

  bool _showStartCalendar = false;
  bool _showEndCalendar = false;
  bool _showColorPalette = false;

  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
    _startTime = const TimeOfDay(hour: 7, minute: 0);
    _endDate = widget.initialDate;
    _endTime = const TimeOfDay(hour: 8, minute: 0);

    _titleFocusNode.addListener(() {
      if (!_titleFocusNode.hasFocus) {
        setState(() => _showColorPalette = false);
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.month}월 ${date.day}일 ($weekday)';
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$period ${displayHour.toString().padLeft(2, '0')}:$minute';
  }

  void _selectStartTime() async {
    final time = await showAnalogTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time != null) {
      setState(() => _startTime = time);
    }
  }

  void _selectEndTime() async {
    final time = await showAnalogTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (time != null) {
      setState(() => _endTime = time);
    }
  }

  void _save() {
    if (_title.isEmpty) {
      _title = '제목 없음';
    }

    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );

    final endDateTime = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    final record = ScheduleRecord(
      petId: 'dummy_pet',
      startTime: startDateTime,
      endTime: endDateTime,
      title: _title,
      color: _selectedColor,
      reminderMinutes: _reminderMinutes,
    );

    widget.onSave(record);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
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
          const SizedBox(height: 24),
          // 날짜/시간 선택 영역
          _buildDateTimeSelector(),
          const SizedBox(height: 24),
          // 제목 입력
          _buildTitleInput(),
          // 색상 팔레트 (제목 입력 중일 때만)
          if (_showColorPalette) _buildColorPalette(),
          const SizedBox(height: 16),
          // 알림 설정
          _buildReminderSelector(),
          // 캘린더 (시작 날짜)
          if (_showStartCalendar) _buildCalendar(isStart: true),
          // 캘린더 (종료 날짜)
          if (_showEndCalendar) _buildCalendar(isStart: false),
          const SizedBox(height: 24),
          // 버튼
          _buildButtons(),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildDateTimeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          // 시작 날짜/시간
          Expanded(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showStartCalendar = !_showStartCalendar;
                      _showEndCalendar = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _showStartCalendar ? AppColors.brandPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDate(_startDate),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _showStartCalendar ? Colors.white : AppColors.nearBlack,
                        letterSpacing: -0.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _selectStartTime,
                  child: Text(
                    _formatTime(_startTime),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.nearBlack,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 화살표
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward, color: AppColors.mediumGray, size: 20),
          ),
          // 종료 날짜/시간
          Expanded(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEndCalendar = !_showEndCalendar;
                      _showStartCalendar = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _showEndCalendar ? AppColors.brandPrimary : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatDate(_endDate),
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _showEndCalendar ? Colors.white : AppColors.nearBlack,
                        letterSpacing: -0.35,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _selectEndTime,
                  child: Text(
                    _formatTime(_endTime),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.nearBlack,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              onChanged: (value) => setState(() => _title = value),
              onTap: () => setState(() => _showColorPalette = true),
              decoration: InputDecoration(
                hintText: '제목',
                hintStyle: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mediumGray,
                ),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: _selectedColor),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _selectedColor),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: _selectedColor, width: 2),
                ),
              ),
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.nearBlack,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showColorPalette = !_showColorPalette),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _selectedColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPalette() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: ScheduleRecord.colorPalette.map((color) {
          final isSelected = color == _selectedColor;
          return GestureDetector(
            onTap: () => setState(() {
              _selectedColor = color;
              _showColorPalette = false;
            }),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: AppColors.nearBlack, width: 2)
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReminderSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.notifications_outlined, size: 18, color: AppColors.mediumGray),
          const SizedBox(width: 4),
          Text(
            '$_reminderMinutes분 전',
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              letterSpacing: -0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar({required bool isStart}) {
    final currentDate = isStart ? _startDate : _endDate;
    final year = currentDate.year;
    final month = currentDate.month;

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
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    final newDate = DateTime(year, month - 1);
                    if (isStart) {
                      _startDate = DateTime(newDate.year, newDate.month, _startDate.day.clamp(1, DateTime(newDate.year, newDate.month + 1, 0).day));
                    } else {
                      _endDate = DateTime(newDate.year, newDate.month, _endDate.day.clamp(1, DateTime(newDate.year, newDate.month + 1, 0).day));
                    }
                  });
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
                  setState(() {
                    final newDate = DateTime(year, month + 1);
                    if (isStart) {
                      _startDate = DateTime(newDate.year, newDate.month, _startDate.day.clamp(1, DateTime(newDate.year, newDate.month + 1, 0).day));
                    } else {
                      _endDate = DateTime(newDate.year, newDate.month, _endDate.day.clamp(1, DateTime(newDate.year, newDate.month + 1, 0).day));
                    }
                  });
                },
                child: const Icon(Icons.chevron_right, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 요일 헤더
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
          // 날짜 그리드
          _buildCalendarGrid(year, month, isStart),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(int year, int month, bool isStart) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;
    final selectedDay = isStart ? _startDate.day : _endDate.day;
    final selectedMonth = isStart ? _startDate.month : _endDate.month;
    final selectedYear = isStart ? _startDate.year : _endDate.year;

    final List<Widget> rows = [];
    List<Widget> currentRow = [];

    // 이전 달 빈 칸
    for (int i = 0; i < startWeekday; i++) {
      currentRow.add(const Expanded(child: SizedBox(height: 36)));
    }

    // 날짜
    for (int day = 1; day <= daysInMonth; day++) {
      final isSelected = day == selectedDay && month == selectedMonth && year == selectedYear;
      final isSunday = (startWeekday + day - 1) % 7 == 0;

      currentRow.add(
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                if (isStart) {
                  _startDate = DateTime(year, month, day);
                } else {
                  _endDate = DateTime(year, month, day);
                }
              });
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

    // 다음 달 빈 칸
    if (currentRow.isNotEmpty) {
      while (currentRow.length < 7) {
        currentRow.add(const Expanded(child: SizedBox(height: 36)));
      }
      rows.add(Row(children: currentRow));
    }

    return Column(children: rows);
  }

  Widget _buildButtons() {
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
                child: const Center(
                  child: Text(
                    '취소',
                    style: TextStyle(
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
                child: const Center(
                  child: Text(
                    '저장',
                    style: TextStyle(
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
}

// 바텀시트 표시 함수
Future<ScheduleRecord?> showAddScheduleBottomSheet({
  required BuildContext context,
  required DateTime initialDate,
}) async {
  ScheduleRecord? result;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddScheduleBottomSheet(
          initialDate: initialDate,
          onSave: (record) {
            result = record;
          },
        ),
      );
    },
  );
  return result;
}
