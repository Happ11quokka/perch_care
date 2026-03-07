import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../services/iap/iap_service.dart';
import '../../services/premium/premium_service.dart';
import '../../services/analytics/analytics_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';
import 'promo_code_bottom_sheet.dart';

/// Paywall 화면 — 구독 구매, 복원, 프로모 코드 입력
class PremiumScreen extends StatefulWidget {
  final String? source;
  final String? feature;

  const PremiumScreen({super.key, this.source, this.feature});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _iapService = IapService.instance;
  final _premiumService = PremiumService.instance;
  final _analytics = AnalyticsService.instance;

  bool _isLoading = false;
  bool _isRestoring = false;
  bool _isPremium = false;
  String _selectedPlan = IapService.yearlyId; // 연간 기본 추천

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
    _iapService.onEvent = null;
    super.dispose();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final status = await _premiumService.getTier();
      if (mounted) {
        setState(() => _isPremium = status.isPremium);
      }
    } catch (_) {}
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
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          l10n.paywall_purchaseSuccessContent,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B6B6B),
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
                fontFamily: 'Pretendard',
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
                            _buildPlanSelector(l10n),
                            const SizedBox(height: 24),
                            _buildCtaButton(l10n),
                            const SizedBox(height: 16),
                            _buildSecondaryActions(l10n),
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
              child: GestureDetector(
                onTap: () {
                  if (context.canPop()) context.pop();
                },
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: SvgPicture.asset(
                    'assets/images/profile/back_arrow.svg',
                  ),
                ),
              ),
            ),
            Text(
              l10n.paywall_title,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
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
              colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
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
            fontFamily: 'Pretendard',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
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
        color: const Color(0xFFFFF5ED),
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
                      fontFamily: 'Pretendard',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.brandPrimary : const Color(0xFFE7E5E1),
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
                  color: isSelected ? AppColors.brandPrimary : const Color(0xFFB5B0A8),
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
                          fontFamily: 'Pretendard',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
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
                              fontFamily: 'Pretendard',
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
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.brandPrimary : const Color(0xFF6B6B6B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCtaButton(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _isLoading ? null : _startPurchase,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF9A42).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          l10n.paywall_ctaButton,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
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
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF97928A),
            ),
          ),
        ),
        Container(
          width: 1,
          height: 14,
          color: const Color(0xFFE7E5E1),
        ),
        TextButton(
          onPressed: _openPromoCode,
          child: Text(
            l10n.paywall_promoCode,
            style: TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF97928A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlreadyPremium(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5ED),
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
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
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
                color: Color(0xFFFF9A42),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.paywall_loading,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B6B6B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
