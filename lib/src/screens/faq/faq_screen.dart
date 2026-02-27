import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../theme/colors.dart';
import '../../router/route_names.dart';
import '../../../l10n/app_localizations.dart';

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}

class _FaqCategory {
  final String title;
  final List<_FaqItem> items;
  const _FaqCategory({required this.title, required this.items});
}

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  List<_FaqCategory> _buildCategories(AppLocalizations l10n) {
    return [
      _FaqCategory(
        title: l10n.faq_categoryGeneral,
        items: [
          _FaqItem(question: l10n.faq_q1, answer: l10n.faq_a1),
          _FaqItem(question: l10n.faq_q2, answer: l10n.faq_a2),
          _FaqItem(question: l10n.faq_q3, answer: l10n.faq_a3),
        ],
      ),
      _FaqCategory(
        title: l10n.faq_categoryUsage,
        items: [
          _FaqItem(question: l10n.faq_q4, answer: l10n.faq_a4),
          _FaqItem(question: l10n.faq_q5, answer: l10n.faq_a5),
          _FaqItem(question: l10n.faq_q6, answer: l10n.faq_a6),
          _FaqItem(question: l10n.faq_q7, answer: l10n.faq_a7),
        ],
      ),
      _FaqCategory(
        title: l10n.faq_categoryAccount,
        items: [
          _FaqItem(question: l10n.faq_q8, answer: l10n.faq_a8),
          _FaqItem(question: l10n.faq_q9, answer: l10n.faq_a9),
          _FaqItem(question: l10n.faq_q10, answer: l10n.faq_a10),
        ],
      ),
      _FaqCategory(
        title: l10n.faq_categoryPet,
        items: [
          _FaqItem(question: l10n.faq_q11, answer: l10n.faq_a11),
          _FaqItem(question: l10n.faq_q12, answer: l10n.faq_a12),
          _FaqItem(question: l10n.faq_q13, answer: l10n.faq_a13),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final categories = _buildCategories(l10n);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            SizedBox(
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
                          } else {
                            context.goNamed(RouteNames.home);
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
                      l10n.faq_title,
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
            ),

            // FAQ content
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                itemCount: categories.length,
                itemBuilder: (context, categoryIndex) {
                  final category = categories[categoryIndex];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (categoryIndex > 0) const SizedBox(height: 16),
                      // Category header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          category.title,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: 0.08,
                          ),
                        ),
                      ),
                      // FAQ items
                      ...category.items.map((item) => _buildFaqTile(item)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile(_FaqItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE7E5E1)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          iconColor: AppColors.brandPrimary,
          collapsedIconColor: const Color(0xFF97928A),
          title: Text(
            item.question,
            style: const TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A),
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.answer,
                style: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF6B6B6B),
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
