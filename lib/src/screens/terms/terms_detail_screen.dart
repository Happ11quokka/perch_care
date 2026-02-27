import 'package:flutter/material.dart';
import '../../data/terms_content.dart';
import '../../../l10n/app_localizations.dart';

/// 약관 상세 화면
class TermsDetailScreen extends StatelessWidget {
  final TermsType termsType;

  const TermsDetailScreen({super.key, required this.termsType});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final title = termsType == TermsType.termsOfService
        ? l10n.terms_termsOfService
        : l10n.terms_privacyPolicy;
    final content = TermsContent.getContent(termsType, locale: locale);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            content,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF6B6B6B),
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
