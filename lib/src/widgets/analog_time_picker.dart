import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../../l10n/app_localizations.dart';

class AnalogTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeSelected;

  const AnalogTimePicker({
    super.key,
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<AnalogTimePicker> createState() => _AnalogTimePickerState();
}

class _AnalogTimePickerState extends State<AnalogTimePicker> {
  late int _selectedHour;
  late int _selectedMinute;
  late bool _isAM;

  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late FocusNode _hourFocusNode;
  late FocusNode _minuteFocusNode;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hourOfPeriod;
    if (_selectedHour == 0) _selectedHour = 12;
    _selectedMinute = widget.initialTime.minute;
    _isAM = widget.initialTime.period == DayPeriod.am;

    _hourController = TextEditingController(
      text: _selectedHour.toString().padLeft(2, '0'),
    );
    _minuteController = TextEditingController(
      text: _selectedMinute.toString().padLeft(2, '0'),
    );
    _hourFocusNode = FocusNode();
    _minuteFocusNode = FocusNode();

    _hourFocusNode.addListener(_onHourFocusChange);
    _minuteFocusNode.addListener(_onMinuteFocusChange);
  }

  @override
  void dispose() {
    _hourFocusNode.removeListener(_onHourFocusChange);
    _minuteFocusNode.removeListener(_onMinuteFocusChange);
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocusNode.dispose();
    _minuteFocusNode.dispose();
    super.dispose();
  }

  void _onHourFocusChange() {
    if (_hourFocusNode.hasFocus) {
      _hourController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _hourController.text.length,
      );
    } else {
      _validateAndSetHour();
    }
  }

  void _onMinuteFocusChange() {
    if (_minuteFocusNode.hasFocus) {
      _minuteController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _minuteController.text.length,
      );
    } else {
      _validateAndSetMinute();
    }
  }

  void _validateAndSetHour() {
    final value = int.tryParse(_hourController.text);
    if (value == null || value < 1 || value > 12) {
      _selectedHour = 12;
    } else {
      _selectedHour = value;
    }
    _hourController.text = _selectedHour.toString().padLeft(2, '0');
    setState(() {});
  }

  void _validateAndSetMinute() {
    final value = int.tryParse(_minuteController.text);
    if (value == null || value < 0 || value > 59) {
      _selectedMinute = 0;
    } else {
      _selectedMinute = value;
    }
    _minuteController.text = _selectedMinute.toString().padLeft(2, '0');
    setState(() {});
  }

  TimeOfDay get _currentTime {
    _validateAndSetHour();
    _validateAndSetMinute();
    int hour = _selectedHour;
    if (_isAM) {
      if (hour == 12) hour = 0;
    } else {
      if (hour != 12) hour += 12;
    }
    return TimeOfDay(hour: hour, minute: _selectedMinute);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 24),
          // 제목
          Text(
            l10n.timePicker_title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.nearBlack,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 32),
          // 시간 입력 필드
          _buildTimeInput(),
          const SizedBox(height: 20),
          // AM/PM 토글
          _buildAmPmToggle(l10n),
          const SizedBox(height: 32),
          // 선택 완료 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                widget.onTimeSelected(_currentTime);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.brandPrimary, AppColors.brandDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        l10n.timePicker_confirm,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
        ],
      ),
    );
  }

  Widget _buildTimeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 시 입력
        _buildTimeTextField(
          controller: _hourController,
          focusNode: _hourFocusNode,
          maxValue: 12,
          onSubmitted: (_) => _minuteFocusNode.requestFocus(),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            ':',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
              letterSpacing: -1.2,
            ),
          ),
        ),
        // 분 입력
        _buildTimeTextField(
          controller: _minuteController,
          focusNode: _minuteFocusNode,
          maxValue: 59,
        ),
      ],
    );
  }

  Widget _buildTimeTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required int maxValue,
    ValueChanged<String>? onSubmitted,
  }) {
    final isFocused = focusNode.hasFocus;
    return GestureDetector(
      onTap: () {
        focusNode.requestFocus();
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      },
      child: Container(
        width: 96,
        height: 72,
        decoration: BoxDecoration(
          color: isFocused
              ? AppColors.brandPrimary.withValues(alpha: 0.12)
              : AppColors.gray100,
          borderRadius: BorderRadius.circular(16),
          border: isFocused
              ? Border.all(color: AppColors.brandPrimary, width: 2)
              : null,
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 2,
          onSubmitted: onSubmitted,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w600,
            color: isFocused ? AppColors.brandPrimary : AppColors.nearBlack,
            letterSpacing: -1.0,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ),
    );
  }

  Widget _buildAmPmToggle(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _isAM = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: _isAM ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                l10n.weight_amPeriod,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isAM ? Colors.white : AppColors.mediumGray,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isAM = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: !_isAM ? AppColors.brandPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                l10n.weight_pmPeriod,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: !_isAM ? Colors.white : AppColors.mediumGray,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 시간 선택 바텀시트 표시 함수
Future<TimeOfDay?> showAnalogTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  TimeOfDay? result;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AnalogTimePicker(
          initialTime: initialTime,
          onTimeSelected: (time) {
            result = time;
          },
        ),
      );
    },
  );
  return result;
}
