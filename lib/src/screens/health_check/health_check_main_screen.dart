import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/analytics/analytics_service.dart';
import '../../providers/premium_provider.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../widgets/quota_badge.dart';
import '../../services/premium/premium_service.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';
import '../premium/promo_code_bottom_sheet.dart';

/// AI 건강체크 모드 선택 화면
class HealthCheckMainScreen extends ConsumerStatefulWidget {
  const HealthCheckMainScreen({super.key});

  @override
  ConsumerState<HealthCheckMainScreen> createState() =>
      _HealthCheckMainScreenState();
}

class _HealthCheckMainScreenState extends ConsumerState<HealthCheckMainScreen>
    with WidgetsBindingObserver {
  bool _isLocked = true; // 기본값: 잠금 (로딩 중 오탭 방지)
  bool _hasVisionTrial = false; // Phase 2: 무료 체험 가능 여부
  int _visionRemaining = 0; // 남은 비전 체험 횟수
  bool _isLoading = true;

  // Coach mark target keys
  final _historyButtonKey = GlobalKey();
  final _modeCardsKey = GlobalKey();
  final _trialBadgeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPremiumStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPremiumStatus(forceRefresh: true);
    }
  }

  Future<void> _loadPremiumStatus({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        await ref.read(premiumStatusProvider.notifier).refresh();
      }
      final status = await ref.read(premiumStatusProvider.future);
      if (mounted) {
        setState(() {
          if (status.isPremium) {
            // 프리미엄: 무제한 사용
            _isLocked = false;
            _hasVisionTrial = false;
            _visionRemaining = -1;
          } else {
            // Phase 2: Free 사용자 3단 상태
            final remaining = status.quota?.vision.remaining ?? 0;
            _visionRemaining = remaining;
            _isLocked = remaining <= 0; // 체험 소진 → 잠금
            _hasVisionTrial = remaining > 0; // 체험 가능 → 열림 + 배지
          }
          _isLoading = false;
        });
        _maybeShowCoachMarks();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocked = true;
          _hasVisionTrial = false;
          _isLoading = false;
        });
        // 네트워크 에러 시 사용자에게 안내 (프리미엄 상태 확인 불가)
        if (e is SocketException || e is TimeoutException) {
          final l10n = AppLocalizations.of(context);
          AppSnackBar.error(context, message: l10n.error_network);
        }
      }
    }
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
      if (!_isLocked && _hasVisionTrial)
        CoachMarkStep(
          targetKey: _trialBadgeKey,
          title: l10n.coach_hcTrial_title,
          body: l10n.coach_hcTrial_body,
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

  // ignore: unused_element — App Store 3.1.1 대응으로 호출부 제거됨, IAP 복원 시 재사용
  Future<void> _openPremiumPaywall({
    required String source,
    required String feature,
  }) async {
    await context.push('/home/premium?source=$source&feature=$feature');
    if (!mounted) return;
    await _loadPremiumStatus(forceRefresh: true);
  }

  void _showPremiumDialog({bool isTrialExhausted = false}) {
    final l10n = AppLocalizations.of(context);
    final title = isTrialExhausted
        ? l10n.healthCheck_trialExhaustedTitle
        : l10n.premium_featureLockedTitle;
    // 사전 사업자등록: 프로모션 코드/SNS 안내 메시지 사용
    final message = isTrialExhausted
        ? l10n.healthCheck_trialExhaustedMessage_v2
        : l10n.healthCheck_trialExhaustedMessage_v2;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.card_giftcard,
              color: AppColors.brandPrimary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.nearBlack,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mediumGray,
            height: 1.5,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.premium_maybeLater,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.mediumGray,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              AnalyticsService.instance.logPremiumFeatureBlocked(
                feature: 'vision',
                sourceScreen: 'health_check_main',
              );
              final activated = await PromoCodeBottomSheet.show(context);
              if (activated == true && mounted) {
                await _loadPremiumStatus(forceRefresh: true);
              }
            },
            child: Text(
              l10n.healthCheck_trialExhaustedAction_promo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.brandPrimary,
              ),
            ),
          ),
        ],
      ),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.hc_selectTarget,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.mediumGray,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  // 비전 쿼터 배지 — 카드 목록 상단에 한 번만 표시
                  if (_hasVisionTrial)
                    VisionQuotaBadge(
                      key: _trialBadgeKey,
                      quota: VisionQuota(
                        monthlyLimit: 30,
                        monthlyUsed: 30 - _visionRemaining,
                        remaining: _visionRemaining,
                      ),
                      normalText: l10n.visionQuotaBadge_normal(_visionRemaining),
                      exhaustedText: l10n.visionQuotaBadge_exhausted,
                    ),
                ],
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
    final locked = _isLocked && !_isLoading;

    return Semantics(
      button: true,
      label: _getModeLabel(l10n, mode),
      child: GestureDetector(
      onTap: () {
        if (locked) {
          _showPremiumDialog(isTrialExhausted: true);
        } else if (!_isLoading) {
          context.pushNamed(
            RouteNames.healthCheckCapture,
            extra: {'mode': mode},
          );
        }
      },
      child: Opacity(
        opacity: locked ? 0.45 : 1.0,
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
                  color: locked
                      ? AppColors.gray250
                      : AppColors.brandLight,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: mode == VisionMode.fullBody
                    ? SvgPicture.asset(
                        'assets/images/brand.svg',
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          locked
                              ? AppColors.gray500
                              : AppColors.brandPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon,
                        color: locked
                            ? AppColors.gray500
                            : AppColors.brandPrimary,
                        size: 24,
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                      ],
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
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: AppColors.warmGray,
                size: 24,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
