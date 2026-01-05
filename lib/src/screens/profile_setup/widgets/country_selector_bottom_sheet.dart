import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 국가 모델
enum Country {
  korea(name: '대한민국', flagAsset: 'assets/images/korea_flag.svg', code: '+82'),
  usa(name: '미국', flagAsset: 'assets/images/usa_flag.svg', code: '+1'),
  india(name: '인도', flagAsset: 'assets/images/india_flag.svg', code: '+91'),
  argentina(name: '아르헨티나', flagAsset: 'assets/images/argentina_flag.svg', code: '+54'),
  italy(name: '이탈리아', flagAsset: 'assets/images/italy_flag.svg', code: '+39'),
  canada(name: '캐나다', flagAsset: 'assets/images/canada_flag.svg', code: '+1');

  const Country({
    required this.name,
    required this.flagAsset,
    required this.code,
  });

  final String name;
  final String flagAsset;
  final String code;

  /// Figma 디자인 순서에 맞게 국가 목록 반환 (대한민국 제외)
  static List<Country> get orderedCountries => [
    Country.usa,
    Country.india,
    Country.argentina,
    Country.italy,
    Country.canada,
  ];
}

/// 국가 선택 바텀시트
class CountrySelectorBottomSheet extends StatelessWidget {
  final Country selectedCountry;
  final void Function(Country) onCountrySelected;

  const CountrySelectorBottomSheet({
    super.key,
    required this.selectedCountry,
    required this.onCountrySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 16),
              child: const Text(
                '국가를 선택하세요',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.35,
                  height: 1.71,
                ),
              ),
            ),
            // 국가 목록 (Figma 디자인 순서)
            ...Country.orderedCountries.map((country) => _buildCountryItem(context, country)),
            // 하단 버튼 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 16, 32, 16),
              child: Row(
                children: [
                  // 다음에 버튼
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF97928A),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            '다음에',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF97928A),
                              letterSpacing: -0.45,
                              height: 1.44,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 입력완료 버튼
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFFF9A42), Color(0xFFFF7C2A)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            '입력완료',
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.45,
                              height: 1.44,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryItem(BuildContext context, Country country) {
    return InkWell(
      onTap: () {
        onCountrySelected(country);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
        child: Row(
          children: [
            // 국기
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SvgPicture.asset(
                country.flagAsset,
                width: 32,
                height: 24,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            // 국가명
            Text(
              country.name,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.35,
                height: 1.71,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
