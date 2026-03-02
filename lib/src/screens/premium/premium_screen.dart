import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../services/premium/premium_service.dart';
import '../../services/api/api_client.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 프리미엄 코드 입력 전용 화면
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  final _premiumService = PremiumService.instance;
  final _codeController = TextEditingController();
  bool _isActivating = false;
  String? _validationError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  bool _isValidCode(String code) {
    final regex = RegExp(r'^PERCH-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return regex.hasMatch(code.trim().toUpperCase());
  }

  Future<void> _activateCode() async {
    final l10n = AppLocalizations.of(context);
    final code = _codeController.text.trim().toUpperCase();

    if (!_isValidCode(code)) {
      setState(() {
        _validationError = l10n.premium_invalidCodeFormat;
      });
      return;
    }

    setState(() {
      _isActivating = true;
      _validationError = null;
    });

    try {
      final result = await _premiumService.activateCode(code);
      if (!mounted) return;

      if (result.success) {
        _showSuccessDialog(l10n, result.expiresAt);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 429) {
        AppSnackBar.error(context, message: l10n.premium_rateLimitExceeded);
      } else {
        AppSnackBar.error(context, message: e.message);
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.error(context, message: l10n.premium_activationError);
    } finally {
      if (mounted) setState(() => _isActivating = false);
    }
  }

  void _showSuccessDialog(AppLocalizations l10n, DateTime? expiresAt) {
    final dateStr = expiresAt != null
        ? '${expiresAt.year}.${expiresAt.month.toString().padLeft(2, '0')}.${expiresAt.day.toString().padLeft(2, '0')}'
        : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          l10n.premium_activationSuccessTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
        content: Text(
          dateStr != null
              ? l10n.premium_activationSuccessContent(dateStr)
              : l10n.premium_activationSuccessContentNoDate,
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(l10n),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildBenefitsSection(l10n),
                      const SizedBox(height: 32),
                      _buildCodeInputSection(l10n),
                      const SizedBox(height: 24),
                      _buildActivateButton(l10n),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  }
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
              l10n.premium_title,
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

  Widget _buildBenefitsSection(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 22,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.premium_benefitsTitle,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brandPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildBenefitRow(l10n.premium_benefit1),
          const SizedBox(height: 10),
          _buildBenefitRow(l10n.premium_benefit2),
          const SizedBox(height: 10),
          _buildBenefitRow(l10n.premium_benefit3),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_rounded,
          size: 18,
          color: AppColors.brandPrimary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInputSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.premium_codeInputTitle,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
            height: 22 / 16,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
            color: Color(0xFF1A1A1A),
          ),
          decoration: InputDecoration(
            hintText: l10n.premium_codeInputHint,
            hintStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 16,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.5,
              color: Color(0xFFB5B0A8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE7E5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE7E5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.brandPrimary),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE53935)),
            ),
            errorText: _validationError,
            errorStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFFE53935),
            ),
          ),
          onChanged: (_) {
            if (_validationError != null) {
              setState(() => _validationError = null);
            }
          },
        ),
      ],
    );
  }

  Widget _buildActivateButton(AppLocalizations l10n) {
    final isEnabled = !_isActivating;

    return GestureDetector(
      onTap: isEnabled ? _activateCode : null,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: isEnabled
              ? const LinearGradient(
                  colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                )
              : null,
          color: isEnabled ? null : const Color(0xFFE7E5E1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: _isActivating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                l10n.premium_activateButton,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? Colors.white : const Color(0xFF97928A),
                  letterSpacing: -0.3,
                ),
              ),
      ),
    );
  }
}
