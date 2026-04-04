import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../services/iap/iap_service.dart';
import '../../providers/premium_provider.dart';
import '../../services/analytics/analytics_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/sns_event_card.dart';
import '../../../l10n/app_localizations.dart';
import 'promo_code_bottom_sheet.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';

/// Paywall 화면 — 구독 구매, 복원, 프로모 코드 입력
class PremiumScreen extends ConsumerStatefulWidget {
  final String? source;
  final String? feature;

  const PremiumScreen({super.key, this.source, this.feature});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  final _iapService = IapService.instance;
  final _analytics = AnalyticsService.instance;

  bool _isLoading = false;
  bool _isRestoring = false;
  bool _isPremium = false;
  String _selectedPlan = IapService.yearlyId; // 연간 기본 추천

  // Coach mark keys
  final GlobalKey _planSelectorKey = GlobalKey();
  final GlobalKey _promoCodeButtonKey = GlobalKey();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
    _iapService.onEvent = _handleIapEvent;

    // Analytics
    _analytics.logPaywallView(
      source: widget.source ?? 'direct',
      feature: widget.feature,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _iapService.onEvent = null;
    super.dispose();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final status = await ref.read(premiumStatusProvider.future);
      if (mounted) {
        setState(() => _isPremium = status.isPremium);
      }
    } catch (_) {}

    _maybeShowCoachMarks();
  }

  Future<void> _maybeShowCoachMarks() async {
    if (_isPremium) return; // 프리미엄이면 플랜/프로모 위젯이 없음
    final service = CoachMarkService.instance;
    final hasSeen = await service.hasSeen(CoachMarkService.screenPremium);
    if (hasSeen || !mounted) return;

    await Future.delayed(AppDurations.coachMarkDelay);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final steps = <CoachMarkStep>[
      // 사전 사업자등록: 플랜 선택 코치마크 제거, 프로모션 코드만 안내
      CoachMarkStep(
        targetKey: _promoCodeButtonKey,
        title: l10n.coach_premiumPromo_title,
        body: l10n.coach_premiumPromo_body,
        isScrollable: false,
      ),
    ];

    if (mounted) {
      CoachMarkOverlay.show(
        context,
        scrollController: _scrollController,
        steps: steps,
        nextLabel: l10n.coach_next,
        gotItLabel: l10n.coach_gotIt,
        skipLabel: l10n.coach_skip,
        onComplete: () => service.markSeen(CoachMarkService.screenPremium),
      );
    }
  }

  void _handleIapEvent(IapEvent event) {
    if (!mounted) return;

    switch (event) {
      case IapEvent.purchaseSuccess:
        setState(() => _isLoading = false);
        _showSuccessDialog();
      case IapEvent.purchaseRestored:
        setState(() => _isRestoring = false);
        final l10n = AppLocalizations.of(context);
        AppSnackBar.success(context, message: l10n.paywall_restoreSuccess);
        _checkCurrentStatus();
      case IapEvent.purchaseFailed:
        setState(() {
          _isLoading = false;
          _isRestoring = false;
        });
        final l10n = AppLocalizations.of(context);
        AppSnackBar.error(context, message: _iapService.lastError ?? l10n.paywall_purchaseFailed);
      case IapEvent.purchasePending:
        // 대기 상태 유지
        break;
      case IapEvent.purchaseCanceled:
        setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.paywall_purchaseSuccessTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
          ),
        ),
        content: Text(
          l10n.paywall_purchaseSuccessContent,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mediumGray,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pop();
            },
            child: Text(
              l10n.common_confirm,
              style: TextStyle(
                color: AppColors.brandPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startPurchase() async {
    final l10n = AppLocalizations.of(context);

    if (!_iapService.isAvailable) {
      AppSnackBar.error(context, message: l10n.paywall_storeUnavailable);
      return;
    }

    final product = _selectedPlan == IapService.yearlyId
        ? _iapService.yearlyProduct
        : _iapService.monthlyProduct;

    if (product == null) {
      AppSnackBar.error(context, message: l10n.paywall_productsNotFound);
      return;
    }

    _analytics.logCheckoutStarted(
      store: Theme.of(context).platform == TargetPlatform.iOS ? 'apple' : 'google',
      productId: product.id,
      source: widget.source ?? 'direct',
    );

    setState(() => _isLoading = true);
    await _iapService.buySubscription(product);
  }

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    await _iapService.restorePurchases();

    // 타임아웃: 15초 후 복원 상태 해제 (스트림 응답이 없을 경우)
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isRestoring) {
        setState(() => _isRestoring = false);
        final l10n = AppLocalizations.of(context);
        AppSnackBar.error(context, message: l10n.paywall_restoreNoSubscription);
      }
    });
  }

  Future<void> _openPromoCode() async {
    _analytics.logPromoCodeEntryOpened(source: widget.source ?? 'direct');
    final activated = await PromoCodeBottomSheet.show(context);
    if (activated == true && mounted) {
      _showSuccessDialog();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(l10n),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildHeroSection(l10n),
                          const SizedBox(height: 28),
                          _buildBenefitsSection(l10n),
                          const SizedBox(height: 28),
                          if (!_isPremium) ...[
                            // 사전 사업자등록: IAP 비활성화, 무료 체험 배너 + 프로모션 + SNS
                            _buildFreeTrialBanner(l10n),
                            const SizedBox(height: 24),
                            _buildPromoCodeCta(l10n),
                            const SizedBox(height: 24),
                            const SnsEventCard(),
                            const SizedBox(height: 16),
                            _buildRestoreOnly(l10n),
                            // TODO(post-registration): IAP 재활성화 시 아래 코드 복원
                            // _buildPlanSelector(l10n),
                            // const SizedBox(height: 24),
                            // _buildCtaButton(l10n),
                            // const SizedBox(height: 16),
                            // _buildSecondaryActions(l10n),
                          ] else
                            _buildAlreadyPremium(l10n),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isLoading || _isRestoring) _buildLoadingOverlay(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: Semantics(
                button: true,
                label: 'Go back',
                child: GestureDetector(
                onTap: () {
                  if (context.canPop()) context.pop();
                },
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(Icons.arrow_back, color: AppColors.nearBlack),
                ),
                ),
              ),
            ),
            Text(
              l10n.paywall_title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: AppColors.nearBlack,
                height: 34 / 20,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(AppLocalizations l10n) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandPrimary, AppColors.brandDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.workspace_premium,
            size: 36,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.paywall_headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.nearBlack,
            height: 1.4,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsSection(AppLocalizations l10n) {
    final benefits = [
      (Icons.camera_alt_rounded, l10n.paywall_benefit1),
      (Icons.auto_awesome, l10n.paywall_benefit2),
      (Icons.health_and_safety, l10n.paywall_benefit3),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: benefits.map((b) {
          final (icon, text) = b;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.brandPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.nearBlack,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlanSelector(AppLocalizations l10n) {
    final yearly = _iapService.yearlyProduct;
    final monthly = _iapService.monthlyProduct;

    return Column(
      key: _planSelectorKey,
      children: [
        // 연간 플랜 (추천)
        _buildPlanCard(
          id: IapService.yearlyId,
          label: l10n.paywall_planYearly,
          price: yearly?.price ?? '₩49,000',
          badge: l10n.paywall_yearlyDiscount,
          isSelected: _selectedPlan == IapService.yearlyId,
          onTap: () {
            setState(() => _selectedPlan = IapService.yearlyId);
            _analytics.logPlanSelected(plan: 'yearly', source: widget.source ?? 'direct');
          },
        ),
        const SizedBox(height: 12),
        // 월간 플랜
        _buildPlanCard(
          id: IapService.monthlyId,
          label: l10n.paywall_planMonthly,
          price: monthly?.price ?? '₩5,900',
          isSelected: _selectedPlan == IapService.monthlyId,
          onTap: () {
            setState(() => _selectedPlan = IapService.monthlyId);
            _analytics.logPlanSelected(plan: 'monthly', source: widget.source ?? 'direct');
          },
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String label,
    required String price,
    String? badge,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: '$label $price',
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : AppColors.beige,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? AppColors.brandPrimary.withValues(alpha: 0.05) : Colors.white,
        ),
        child: Row(
          children: [
            // 라디오 인디케이터
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brandPrimary : AppColors.lightGray,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brandPrimary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // 레이블
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? AppColors.nearBlack : AppColors.mediumGray,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandPrimary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // 가격
            Text(
              price,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.brandPrimary : AppColors.mediumGray,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildCtaButton(AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.paywall_ctaButton,
      child: GestureDetector(
      onTap: _isLoading ? null : _startPurchase,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.brandPrimary, AppColors.brandDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandPrimary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          l10n.paywall_ctaButton,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildSecondaryActions(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _isRestoring ? null : _restorePurchases,
          child: Text(
            l10n.paywall_restore,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.warmGray,
            ),
          ),
        ),
        Container(
          width: 1,
          height: 14,
          color: AppColors.beige,
        ),
        TextButton(
          key: _promoCodeButtonKey,
          onPressed: _openPromoCode,
          child: Text(
            l10n.paywall_promoCode,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.warmGray,
            ),
          ),
        ),
      ],
    );
  }

  /// 사전 사업자등록: 무료 체험 중 배너
  Widget _buildFreeTrialBanner(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.card_giftcard, size: 48, color: AppColors.success),
          const SizedBox(height: 12),
          Text(
            l10n.paywall_freeTrialBanner,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.paywall_freeTrialSubtext,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 사전 사업자등록: 프로모션 코드 입력 CTA (메인 버튼)
  Widget _buildPromoCodeCta(AppLocalizations l10n) {
    return Semantics(
      button: true,
      label: l10n.paywall_promoCode,
      child: GestureDetector(
        onTap: _openPromoCode,
        child: Container(
          key: _promoCodeButtonKey,
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.brandPrimary, AppColors.brandDark],
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.redeem, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                l10n.paywall_promoCode,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 사전 사업자등록: 구매 복원 버튼만 단독 표시
  Widget _buildRestoreOnly(AppLocalizations l10n) {
    return Center(
      child: TextButton(
        onPressed: _isRestoring ? null : _restorePurchases,
        child: Text(
          l10n.paywall_restore,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.warmGray,
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyPremium(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, size: 48, color: AppColors.brandPrimary),
          const SizedBox(height: 12),
          Text(
            l10n.paywall_alreadyPremium,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.nearBlack,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay(AppLocalizations l10n) {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.brandPrimary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.paywall_loading,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.mediumGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
