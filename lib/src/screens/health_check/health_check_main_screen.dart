import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';

/// AI 건강체크 모드 선택 화면
class HealthCheckMainScreen extends ConsumerStatefulWidget {
  const HealthCheckMainScreen({super.key});

  @override
  ConsumerState<HealthCheckMainScreen> createState() =>
      _HealthCheckMainScreenState();
}

class _HealthCheckMainScreenState extends ConsumerState<HealthCheckMainScreen> {
  // Coach mark target keys
  final _historyButtonKey = GlobalKey();
  final _modeCardsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _maybeShowCoachMarks();
  }

  Future<void> _maybeShowCoachMarks() async {
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenHealthCheckMain)) return;
    if (!mounted) return;
    await Future.delayed(AppDurations.coachMarkDelay);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final steps = [
      CoachMarkStep(
        targetKey: _historyButtonKey,
        title: l10n.coach_hcHistory_title,
        body: l10n.coach_hcHistory_body,
        isScrollable: false,
      ),
      CoachMarkStep(
        targetKey: _modeCardsKey,
        title: l10n.coach_hcModes_title,
        body: l10n.coach_hcModes_body,
      ),
    ];

    CoachMarkOverlay.show(
      context,
      steps: steps,
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () {
        service.markSeen(CoachMarkService.screenHealthCheckMain);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppColors.gray100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
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
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            key: _historyButtonKey,
            icon: const Icon(Icons.history, color: AppColors.nearBlack),
            onPressed: () {
              context.pushNamed(RouteNames.healthCheckHistory);
            },
          ),
        ],
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
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                key: _modeCardsKey,
                child: _buildModeCard(
                  context,
                  l10n: l10n,
                  mode: VisionMode.fullBody,
                  icon: Icons.pets,
                  description: l10n.hc_modeFullBodyDesc,
                ),
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
    return Semantics(
      button: true,
      label: _getModeLabel(l10n, mode),
      child: GestureDetector(
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
                  color: AppColors.brandLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: mode == VisionMode.fullBody
                    ? SvgPicture.asset(
                        'assets/images/brand.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          AppColors.brandPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon,
                        color: AppColors.brandPrimary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getModeLabel(l10n, mode),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.nearBlack,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                color: AppColors.warmGray,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
