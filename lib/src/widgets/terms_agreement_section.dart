import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/terms_content.dart';
import '../theme/colors.dart';
import '../../l10n/app_localizations.dart';

/// 회원가입 화면의 약관 동의 섹션 위젯
class TermsAgreementSection extends StatefulWidget {
  /// 필수 약관 동의 상태 및 마케팅 동의 상태 변경 콜백
  final void Function(bool allRequiredAgreed, bool marketingAgreed) onChanged;

  /// 약관 상세 화면 라우트 이름 (Shell 내/외부에 따라 다름)
  final String termsRouteName;

  const TermsAgreementSection({
    super.key,
    required this.onChanged,
    required this.termsRouteName,
  });

  @override
  State<TermsAgreementSection> createState() => _TermsAgreementSectionState();
}

class _TermsAgreementSectionState extends State<TermsAgreementSection> {
  bool _agreeAll = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

  void _onAgreeAllChanged(bool value) {
    setState(() {
      _agreeAll = value;
      _agreeTerms = value;
      _agreePrivacy = value;
      _agreeMarketing = value;
    });
    _notifyParent();
  }

  void _onItemChanged({
    bool? terms,
    bool? privacy,
    bool? marketing,
  }) {
    setState(() {
      if (terms != null) _agreeTerms = terms;
      if (privacy != null) _agreePrivacy = privacy;
      if (marketing != null) _agreeMarketing = marketing;
      _agreeAll = _agreeTerms && _agreePrivacy && _agreeMarketing;
    });
    _notifyParent();
  }

  void _notifyParent() {
    widget.onChanged(
      _agreeTerms && _agreePrivacy,
      _agreeMarketing,
    );
  }

  void _openTerms(TermsType type) {
    FocusScope.of(context).unfocus();
    context.pushNamed(widget.termsRouteName, extra: type);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 전체 동의
        _buildSelectAllRow(l10n),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Divider(height: 1, color: Color(0xFFF0F0F0)),
        ),
        // [필수] 이용약관
        _buildItemRow(
          label: l10n.terms_requiredTerms,
          checked: _agreeTerms,
          onChanged: (v) => _onItemChanged(terms: v),
          termsType: TermsType.termsOfService,
          l10n: l10n,
        ),
        const SizedBox(height: 8),
        // [필수] 개인정보처리방침
        _buildItemRow(
          label: l10n.terms_requiredPrivacy,
          checked: _agreePrivacy,
          onChanged: (v) => _onItemChanged(privacy: v),
          termsType: TermsType.privacyPolicy,
          l10n: l10n,
        ),
        const SizedBox(height: 8),
        // [선택] 마케팅
        _buildItemRow(
          label: l10n.terms_optionalMarketing,
          checked: _agreeMarketing,
          onChanged: (v) => _onItemChanged(marketing: v),
          l10n: l10n,
        ),
      ],
    );
  }

  Widget _buildSelectAllRow(AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => _onAgreeAllChanged(!_agreeAll),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          _buildCheckbox(_agreeAll),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.terms_agreeAll,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow({
    required String label,
    required bool checked,
    required ValueChanged<bool> onChanged,
    required AppLocalizations l10n,
    TermsType? termsType,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!checked),
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          _buildCheckbox(checked),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
              ),
            ),
          ),
          if (termsType != null)
            GestureDetector(
              onTap: () => _openTerms(termsType),
              child: Text(
                l10n.common_view,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF97928A),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(bool checked) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? AppColors.brandPrimary : Colors.transparent,
        border: Border.all(
          color: checked ? AppColors.brandPrimary : const Color(0xFFE7E5E1),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: checked
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }
}
