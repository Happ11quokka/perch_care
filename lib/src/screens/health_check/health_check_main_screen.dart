import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';

/// AI 건강체크 모드 선택 화면
class HealthCheckMainScreen extends StatelessWidget {
  const HealthCheckMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
        title: const Text(
          'AI 건강체크',
          style: TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '분석 대상을 선택해주세요',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B6B6B),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 20),
              _buildModeCard(
                context,
                mode: VisionMode.fullBody,
                icon: Icons.pets,
                description: '전체 모습을 촬영하여 외형을 분석합니다',
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                context,
                mode: VisionMode.partSpecific,
                icon: Icons.search,
                description: '눈, 부리, 깃털, 발 등 특정 부위를 분석합니다',
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                context,
                mode: VisionMode.droppings,
                icon: Icons.science_outlined,
                description: '배변 사진으로 건강 상태를 확인합니다',
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                context,
                mode: VisionMode.food,
                icon: Icons.restaurant,
                description: '먹이 사진으로 급여 가능 여부를 확인합니다',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required VisionMode mode,
    required IconData icon,
    required String description,
  }) {
    return GestureDetector(
      onTap: () {
        context.pushNamed(
          RouteNames.healthCheckCapture,
          extra: {'mode': mode},
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5ED),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: AppColors.brandPrimary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF6B6B6B),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF97928A),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
