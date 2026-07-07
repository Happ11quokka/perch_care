import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../l10n/app_localizations.dart';
import '../theme/colors.dart';
import '../theme/durations.dart';

/// 하단 네비게이션 바 위젯
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int>? onTap;

  /// 코치마크에서 참조할 수 있는 정적 GlobalKey
  static final homeTabKey = GlobalKey(debugLabel: 'bottomNav_home');
  static final recordsTabKey = GlobalKey(debugLabel: 'bottomNav_records');
  static final chatbotTabKey = GlobalKey(debugLabel: 'bottomNav_chatbot');

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(0, -10),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _buildNavItem(
              context: context,
              index: 0,
              itemKey: homeTabKey,
              iconPath: 'assets/images/home.svg',
              onTap: () => onTap?.call(0),
            ),
            _buildNavItem(
              context: context,
              index: 1,
              itemKey: recordsTabKey,
              iconPath: 'assets/images/calender.svg',
              onTap: () => onTap?.call(1),
            ),
            _buildNavItem(
              context: context,
              index: 2,
              itemKey: chatbotTabKey,
              iconPath: 'assets/images/chat.svg',
              onTap: () => onTap?.call(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required GlobalKey itemKey,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    // currentIndex가 -1이면 선택된 탭 없음 (프로필 페이지 등)
    final isSelected = currentIndex >= 0 && currentIndex == index;
    final l10n = AppLocalizations.of(context);
    final tabLabels = [
      l10n.bottomNav_home,
      l10n.bottomNav_records,
      l10n.bottomNav_chat,
    ];
    final label = index < tabLabels.length ? tabLabels[index] : 'Tab $index';

    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        selected: isSelected,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            containedInkWell: false,
            radius: 40,
            child: SizedBox(
              key: itemKey,
              height: 92,
              child: Center(
                // 선택 시 아이콘을 살짝 키워 강조
                child: AnimatedScale(
                  scale: isSelected ? 1.08 : 1.0,
                  duration: AppDurations.of(context, AppDurations.feedback),
                  curve: AppCurves.enter,
                  // 선택/해제 시 아이콘 색을 하드 스왑하지 않고 보간
                  child: TweenAnimationBuilder<Color?>(
                    // begin을 현재 선택 상태의 목표색으로 두어 첫 마운트 시
                    // 선택된 탭이 회색→주황으로 플래시하지 않게 한다. 탭 전환 시에는
                    // TweenAnimationBuilder가 현재값에서 새 목표로 이어서 보간한다.
                    tween: ColorTween(
                      begin: isSelected
                          ? AppColors.brandPrimary
                          : AppColors.warmGray,
                      end: isSelected
                          ? AppColors.brandPrimary
                          : AppColors.warmGray,
                    ),
                    duration: AppDurations.of(context, AppDurations.quick),
                    curve: AppCurves.enter,
                    builder: (context, color, _) => SvgPicture.asset(
                      iconPath,
                      width: 30,
                      height: 30,
                      colorFilter: ColorFilter.mode(
                        color ?? AppColors.warmGray,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
