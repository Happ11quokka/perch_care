import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../theme/colors.dart';

/// 비밀번호 강도 레벨
enum PasswordStrength { none, weak, medium, strong }

/// 비밀번호 강도를 실시간으로 표시하는 위젯
///
/// 3-segment 바 + 텍스트 라벨로 구성.
/// 8자 미만이면 표시하지 않음.
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  static const _strongGreen = Color(0xFF4CAF50);
  static const _mediumAmber = Color(0xFFFFA726);

  /// 비밀번호 강도 계산
  static PasswordStrength calculateStrength(String password) {
    if (password.length < 8) return PasswordStrength.none;

    int categories = 0;
    if (password.contains(RegExp(r'[a-z]'))) categories++;
    if (password.contains(RegExp(r'[A-Z]'))) categories++;
    if (password.contains(RegExp(r'[0-9]'))) categories++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>\-_+=\[\]\\\/~`]'))) {
      categories++;
    }

    if (password.length >= 10 && categories >= 3) {
      return PasswordStrength.strong;
    }
    if (categories >= 2) return PasswordStrength.medium;
    return PasswordStrength.weak;
  }

  @override
  Widget build(BuildContext context) {
    final strength = calculateStrength(password);
    if (strength == PasswordStrength.none) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final (color, label, filledCount) = switch (strength) {
      PasswordStrength.weak => (AppColors.error, l10n.password_strength_weak, 1),
      PasswordStrength.medium => (_mediumAmber, l10n.password_strength_medium, 2),
      PasswordStrength.strong => (_strongGreen, l10n.password_strength_strong, 3),
      PasswordStrength.none => (AppColors.gray200, '', 0),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          // 3-segment 바
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: i < filledCount ? color : AppColors.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          // 텍스트 라벨
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
