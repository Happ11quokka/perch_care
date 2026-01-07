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
  late final List<Country> _countries;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.selectedCountry;
    final seen = <String>{};
    _countries = CountryService()
        .getAll()
        .where((country) => seen.add(country.countryCode))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSheetHeight = MediaQuery.of(context).size.height * 0.7;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: bottomSheetHeight,
          child: Column(
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
              Expanded(
                child: ListView.builder(
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    return _buildCountryItem(context, _countries[index]);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryItem(BuildContext context, Country country) {
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
            // 국가명 (로컬라이즈)
            Text(
              _getLocalizedCountryName(context, country),
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

  /// 국가명 로컬라이즈 (기본: 한국어)
  String _getLocalizedCountryName(BuildContext context, Country country) {
    final localizations = CountryLocalizations.of(context) ??
        CountryLocalizations(const Locale('ko'));
    return localizations.countryName(countryCode: country.countryCode) ??
        country.name;
  }
}
