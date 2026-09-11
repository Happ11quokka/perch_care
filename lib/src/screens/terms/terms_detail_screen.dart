import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/terms_content.dart';
import '../../router/navigation_extensions.dart';
import '../../router/route_paths.dart';
import '../../theme/colors.dart';
import '../../../l10n/app_localizations.dart';

/// 약관 상세 화면
class TermsDetailScreen extends ConsumerWidget {
  final TermsType termsType;

  const TermsDetailScreen({super.key, required this.termsType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final title = switch (termsType) {
      TermsType.termsOfService => l10n.terms_termsOfService,
      TermsType.privacyPolicy => l10n.terms_privacyPolicy,
      TermsType.marketing => l10n.terms_marketing,
    };
    final content = TermsContent.getContent(termsType, locale: locale);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.nearBlack),
          onPressed: () {
            // 공개 라우트(/terms/detail)와 홈 하위 라우트(/home/terms/detail)를
            // 공유하므로 직접 진입 시 폴백은 현재 위치로 판단한다.
            final location = GoRouterState.of(context).matchedLocation;
            context.popOrGo(
              location.startsWith(RoutePaths.home)
                  ? RoutePaths.home
                  : RoutePaths.login,
            );
          },
        ),
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: AppColors.nearBlack,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.mediumGray,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
