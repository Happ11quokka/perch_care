import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../router/route_names.dart';

/// 하단 네비게이션 바 위젯
class BottomNavBar extends StatelessWidget {
  final int currentIndex;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            offset: Offset(0, -10),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _buildNavItem(
                context: context,
                index: 0,
                iconPath: 'assets/images/home.svg',
                onTap: () => context.goNamed(RouteNames.home),
              ),
              _buildNavItem(
                context: context,
                index: 1,
                iconPath: 'assets/images/calender.svg',
                onTap: () {
                  // TODO: 캘린더 화면으로 이동
                },
              ),
              _buildNavItem(
                context: context,
                index: 2,
                iconPath: 'assets/images/chat.svg',
                onTap: () => context.goNamed(RouteNames.profile),
              ),
            ],
          ),
          // Home indicator
          Container(
            height: 34,
            alignment: Alignment.center,
            child: Container(
              width: 134,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFF626877),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    final isSelected = currentIndex == index;
    final isFirst = index == 0;
    final isLast = index == 2;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: isFirst ? const Radius.circular(32) : Radius.zero,
              topRight: isLast ? const Radius.circular(32) : Radius.zero,
            ),
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
