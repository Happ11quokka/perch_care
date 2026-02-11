import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _localeKey = 'app_locale';

  static final LocaleProvider _instance = LocaleProvider._internal();
  static LocaleProvider get instance => _instance;

  LocaleProvider._internal();

  Locale? _locale;
  bool _initialized = false;

  Locale? get locale => _locale;
  bool get initialized => _initialized;

  /// 지원하는 언어 목록
  static const List<Locale> supportedLocales = [
    Locale('ko'), // 한국어
    Locale('en'), // 영어
    Locale('zh'), // 중국어
  ];

  /// 언어 코드에서 표시 이름 반환
  static String getDisplayName(String languageCode) {
    switch (languageCode) {
      case 'ko':
        return '한국어';
      case 'en':
        return 'English';
      case 'zh':
        return '中文';
      default:
        return languageCode;
    }
  }

  /// 초기화 - 저장된 언어 설정 로드
  Future<void> initialize() async {
    if (_initialized) return;

    final prefs = await SharedPreferences.getInstance();
    final savedLocale = prefs.getString(_localeKey);

    if (savedLocale != null) {
      _locale = Locale(savedLocale);
    }
    // savedLocale이 null이면 _locale도 null로 유지 -> 기기 설정 따름

    _initialized = true;
    notifyListeners();
  }

  /// 언어 설정 변경
  Future<void> setLocale(Locale? locale) async {
    if (_locale == locale) return;

    final prefs = await SharedPreferences.getInstance();

    if (locale == null) {
      // 기기 설정 따르기
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, locale.languageCode);
    }

    _locale = locale;
    notifyListeners();
  }

  /// 현재 설정된 언어 코드 (null이면 기기 설정)
  String? get currentLanguageCode => _locale?.languageCode;
}
