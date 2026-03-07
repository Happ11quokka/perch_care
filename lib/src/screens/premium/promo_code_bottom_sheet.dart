import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../services/premium/premium_service.dart';
import '../../services/api/api_client.dart';
import '../../widgets/app_snack_bar.dart';
import '../../../l10n/app_localizations.dart';

/// 프로모션 코드 입력 바텀시트
class PromoCodeBottomSheet extends StatefulWidget {
  const PromoCodeBottomSheet({super.key});

  /// 바텀시트 표시 헬퍼
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const PromoCodeBottomSheet(),
    );
  }

  @override
  State<PromoCodeBottomSheet> createState() => _PromoCodeBottomSheetState();
}

class _PromoCodeBottomSheetState extends State<PromoCodeBottomSheet> {
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
        Navigator.pop(context, true); // true = 활성화 성공
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: 20 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 핸들바
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE7E5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 제목
          Text(
            l10n.premium_codeInputTitle,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),

          // 코드 입력
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
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          const SizedBox(height: 20),

          // 활성화 버튼
          GestureDetector(
            onTap: _isActivating ? null : _activateCode,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: !_isActivating
                    ? const LinearGradient(
                        colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                      )
                    : null,
                color: _isActivating ? const Color(0xFFE7E5E1) : null,
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
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
