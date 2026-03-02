import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';

/// AI 건강체크 모드 선택 화면
class HealthCheckMainScreen extends StatelessWidget {
  const HealthCheckMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
        title: Text(
          l10n.hc_title,
          style: const TextStyle(
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
              Text(
                l10n.hc_selectTarget,
                style: const TextStyle(
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
                l10n: l10n,
                mode: VisionMode.fullBody,
                icon: Icons.pets,
                description: l10n.hc_modeFullBodyDesc,
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                context,
                l10n: l10n,
                mode: VisionMode.partSpecific,
                icon: Icons.search,
                description: l10n.hc_modePartSpecificDesc,
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                context,
                l10n: l10n,
                mode: VisionMode.droppings,
                icon: Icons.science_outlined,
                description: l10n.hc_modeDroppingsDesc,
              ),
              const SizedBox(height: 12),
              _buildModeCard(
                context,
                l10n: l10n,
                mode: VisionMode.food,
                icon: Icons.restaurant,
                description: l10n.hc_modeFoodDesc,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getModeLabel(AppLocalizations l10n, VisionMode mode) {
    switch (mode) {
      case VisionMode.fullBody:
        return l10n.hc_modeFullBody;
      case VisionMode.partSpecific:
        return l10n.hc_modePartSpecific;
      case VisionMode.droppings:
        return l10n.hc_modeDroppings;
      case VisionMode.food:
        return l10n.hc_modeFood;
    }
  }

  Widget _buildModeCard(
    BuildContext context, {
    required AppLocalizations l10n,
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
                    _getModeLabel(l10n, mode),
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
