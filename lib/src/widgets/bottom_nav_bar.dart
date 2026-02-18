import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
            color: Color(0x0A000000),
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

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          key: itemKey,
          height: 92,
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Center(
            child: SvgPicture.asset(
              iconPath,
              width: 30,
              height: 30,
              colorFilter: ColorFilter.mode(
                isSelected ? const Color(0xFFFF9A42) : const Color(0xFF97928A),
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
