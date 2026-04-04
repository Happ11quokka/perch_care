import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_snack_bar.dart';
import '../../l10n/app_localizations.dart';

/// SNS 연락처 항목 정의
class _SnsContact {
  final IconData icon;
  final String label;
  final String value;
  final String? url; // null이면 클립보드 복사
  final bool emphasized;

  const _SnsContact({
    required this.icon,
    required this.label,
    required this.value,
    this.url,
    this.emphasized = false,
  });
}

/// SNS 이벤트 프로모션 카드 — 프리미엄/프로필 화면에서 공유 사용
class SnsEventCard extends StatelessWidget {
  const SnsEventCard({super.key});

  /// 언어별 SNS 연락처 목록 (강조 항목이 상단에 배치)
  static List<_SnsContact> _getContacts(String languageCode) {
    final instagram = _SnsContact(
      icon: Icons.camera_alt_outlined,
      label: 'Instagram',
      value: 'perchcare',
      url: 'https://www.instagram.com/perchcare',
      emphasized: languageCode != 'zh',
    );
    final email = _SnsContact(
      icon: Icons.email_outlined,
      label: 'Email',
      value: 'limdongxian1207@gmail.com',
      url: 'mailto:limdongxian1207@gmail.com',
      emphasized: languageCode != 'zh',
    );
    final xiaohongshu = _SnsContact(
      icon: Icons.bookmark_outlined,
      label: '小红书',
      value: 'perch_care',
      url: 'https://www.xiaohongshu.com/user/profile/65346bb9000000000301e0da',
      emphasized: languageCode == 'zh',
    );
    final wechat = _SnsContact(
      icon: Icons.chat_outlined,
      label: '微信 WeChat',
      value: 'dxxxxxxxxx1207',
      emphasized: languageCode == 'zh',
    );

    final contacts = [instagram, email, xiaohongshu, wechat];
    // 강조 항목을 상단으로 정렬
    contacts.sort((a, b) {
      if (a.emphasized == b.emphasized) return 0;
      return a.emphasized ? -1 : 1;
    });
    return contacts;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final contacts = _getContacts(languageCode);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.brandPrimary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.brandPrimary.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.celebration_outlined,
                size: 20,
                color: AppColors.brandPrimary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.paywall_snsEventTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.nearBlack,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.paywall_snsEventDescription,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ...contacts.map((c) => _buildContactRow(context, c, l10n)),
        ],
      ),
    );
  }

  Widget _buildContactRow(
    BuildContext context,
    _SnsContact contact,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Semantics(
        button: true,
        label: '${contact.label}: ${contact.value}',
        child: GestureDetector(
          onTap: () => _handleTap(context, contact, l10n),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: contact.emphasized
                  ? AppColors.brandPrimary.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: contact.emphasized
                    ? AppColors.brandPrimary.withValues(alpha: 0.2)
                    : AppColors.beige,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  contact.icon,
                  size: 18,
                  color: contact.emphasized
                      ? AppColors.brandPrimary
                      : AppColors.mediumGray,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  contact.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: contact.emphasized
                        ? AppColors.nearBlack
                        : AppColors.mediumGray,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    contact.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: contact.emphasized
                          ? AppColors.brandPrimary
                          : AppColors.nearBlack,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  contact.url != null ? Icons.open_in_new : Icons.content_copy,
                  size: 14,
                  color: AppColors.lightGray,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    _SnsContact contact,
    AppLocalizations l10n,
  ) async {
    if (contact.url != null) {
      final uri = Uri.parse(contact.url!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    // URL 없거나 열기 실패 시 클립보드 복사
    await Clipboard.setData(ClipboardData(text: contact.value));
    if (context.mounted) {
      AppSnackBar.success(context, message: l10n.sns_copied(contact.label));
    }
  }
}
