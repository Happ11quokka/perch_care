import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

/// 국가 선택 바텀시트
class CountrySelectorBottomSheet extends StatefulWidget {
  final Country selectedCountry;
  final void Function(Country) onCountrySelected;

  const CountrySelectorBottomSheet({
    super.key,
    required this.selectedCountry,
    required this.onCountrySelected,
  });

  @override
  State<CountrySelectorBottomSheet> createState() => _CountrySelectorBottomSheetState();
}

class _CountrySelectorBottomSheetState extends State<CountrySelectorBottomSheet> {
  late Country _selectedCountry;

  // 표시할 국가 목록 (Figma 디자인 순서)
  static final List<String> _displayCountryCodes = [
    'US',  // 미국
    'IN',  // 인도
    'AR',  // 아르헨티나
    'IT',  // 이탈리아
    'CA',  // 캐나다
  ];

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.selectedCountry;
  }

  List<Country> get _displayCountries {
    return _displayCountryCodes
        .map((code) => CountryParser.parseCountryCode(code))
        .toList();
  }

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
              child: Text(
                '국가를 선택하세요',
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1A1A1A),
                  height: 24 / 14,
                  letterSpacing: -0.35,
                ),
              ),
            ),
            // 국가 목록
            ..._displayCountries.map((country) => _buildCountryItem(country)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryItem(Country country) {
    final isSelected = _selectedCountry.countryCode == country.countryCode;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedCountry = country;
        });
        widget.onCountrySelected(country);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        color: isSelected ? const Color(0xFFFFF5ED) : Colors.transparent,
        child: Row(
          children: [
            // 국기 이모지
            Text(
              country.flagEmoji,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 12),
            // 국가명 (한글 직접 매핑)
            Text(
              _getLocalizedCountryName(country),
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A1A1A),
                height: 24 / 14,
                letterSpacing: -0.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 국가명 한글 매핑
  String _getLocalizedCountryName(Country country) {
    const Map<String, String> koreanNames = {
      'US': '미국',
      'IN': '인도',
      'AR': '아르헨티나',
      'IT': '이탈리아',
      'CA': '캐나다',
      'KR': '대한민국',
    };
    return koreanNames[country.countryCode] ?? country.name;
  }
}
