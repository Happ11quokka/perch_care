import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../l10n/app_localizations.dart';
import '../../router/route_names.dart';
import '../../theme/colors.dart';
import '../../services/api/api_client.dart';
import '../../services/premium/premium_service.dart';
import '../../providers/pet_providers.dart';

/// 병원 방문 요약 공유 화면
class VetSummaryScreen extends ConsumerStatefulWidget {
  const VetSummaryScreen({super.key});

  @override
  ConsumerState<VetSummaryScreen> createState() => _VetSummaryScreenState();
}

class _VetSummaryScreenState extends ConsumerState<VetSummaryScreen> {
  bool _isSharing = false;

  Future<void> _shareVetSummary() async {
    final l10n = AppLocalizations.of(context);
    final petId = ref.read(activePetProvider).valueOrNull?.id;
    if (petId == null) return;

    final box = context.findRenderObject() as RenderBox?;
    final origin = box != null
        ? box.localToGlobal(Offset.zero) & box.size
        : null;

    setState(() => _isSharing = true);

    try {
      final status = await PremiumService.instance.getTier();
      if (status.isFree) {
        if (mounted) context.pushNamed(RouteNames.premium);
        return;
      }

      final result = await ApiClient.instance.post(
        '/reports/share/vet-summary/$petId',
      );

      final shareUrl = result['share_url'] as String;
      await Share.share(shareUrl, sharePositionOrigin: origin);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403) {
        context.pushNamed(RouteNames.premium);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.report_shareFailed)),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.report_shareFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.report_vetSummary,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.nearBlack,
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              // Illustration
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_hospital_outlined,
                  size: 56,
                  color: AppColors.brandPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.report_vetSummaryTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.nearBlack,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.report_vetSummaryDesc,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mediumGray,
                  height: 1.5,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Feature list
              _buildFeatureItem(
                Icons.monitor_weight_outlined,
                l10n.report_vetFeatureWeight,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                Icons.health_and_safety_outlined,
                l10n.report_vetFeatureChecks,
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                Icons.edit_note,
                l10n.report_vetFeatureNotes,
              ),
              const Spacer(flex: 2),
              // CTA button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSharing ? null : _shareVetSummary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isSharing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.share_outlined, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              l10n.report_vetShareButton,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.brandLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.brandPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.nearBlack,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}
