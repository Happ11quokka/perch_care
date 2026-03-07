import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../models/ai_health_check.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/premium/premium_service.dart';

/// AI 건강체크 모드 선택 화면
class HealthCheckMainScreen extends StatefulWidget {
  const HealthCheckMainScreen({super.key});

  @override
  State<HealthCheckMainScreen> createState() => _HealthCheckMainScreenState();
}

class _HealthCheckMainScreenState extends State<HealthCheckMainScreen>
    with WidgetsBindingObserver {
  bool _isLocked = true; // 기본값: 잠금 (로딩 중 오탭 방지)
  bool _isLoading = true;

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
      final status = await PremiumService.instance.getTier(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _isLocked = status.isFree;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocked = true;
          _isLoading = false;
        });
      }
    }
  }

  void _showPremiumDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.workspace_premium,
                color: AppColors.brandPrimary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.premium_featureLockedTitle,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          l10n.premium_featureLockedMessage,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF6B6B6B),
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
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.pushNamed(RouteNames.premium);
            },
            child: Text(
              l10n.premium_activateNow,
              style: const TextStyle(
                fontFamily: 'Pretendard',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFF1A1A1A)),
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
    final locked = _isLocked && !_isLoading;

    return GestureDetector(
      onTap: () {
        if (locked) {
          _showPremiumDialog();
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
                      ? const Color(0xFFE8E8E8)
                      : const Color(0xFFFFF5ED),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: mode == VisionMode.fullBody
                    ? SvgPicture.asset(
                        'assets/images/brand.svg',
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(
                          locked
                              ? const Color(0xFF9E9E9E)
                              : AppColors.brandPrimary,
                          BlendMode.srcIn,
                        ),
                      )
                    : Icon(
                        icon,
                        color: locked
                            ? const Color(0xFF9E9E9E)
                            : AppColors.brandPrimary,
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
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: const Color(0xFF97928A),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
