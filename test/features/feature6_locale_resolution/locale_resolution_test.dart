import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';

/// main.dart의 localeResolutionCallback 로직을 순수 함수로 추출하여 테스트
/// 원본: lib/main.dart lines 81-93
Locale resolveLocale(
  Locale? userPreference,
  Locale? deviceLocale,
  List<Locale> supportedLocales,
) {
  // 1. 사용자가 직접 언어를 선택한 경우 → 해당 언어 사용
  if (userPreference != null) {
    return userPreference;
  }
  // 2. 기기 언어의 languageCode만으로 매칭
  if (deviceLocale != null) {
    for (final supported in supportedLocales) {
      if (supported.languageCode == deviceLocale.languageCode) {
        return supported;
      }
    }
  }
  // 3. 매칭 실패 시 한국어 폴백
  return const Locale('ko');
}

void main() {
  final supportedLocales = const [
    Locale('ko'),
    Locale('en'),
    Locale('zh'),
  ];

  group('Feature 6: 로캘 해석 콜백 (localeResolutionCallback)', () {
    group('사용자 설정 우선', () {
      test('6.1 사용자가 영어 선택 → 기기 로캘 무관하게 영어 반환', () {
        final result = resolveLocale(
          const Locale('en'),
          const Locale('zh', 'CN'),
          supportedLocales,
        );
        expect(result, const Locale('en'));
      });

      test('6.1b 사용자가 중국어 선택 → 기기 로캘 무관하게 중국어 반환', () {
        final result = resolveLocale(
          const Locale('zh'),
          const Locale('ko'),
          supportedLocales,
        );
        expect(result, const Locale('zh'));
      });
    });

    group('중국어 변형 매칭 (핵심 버그 수정)', () {
      test('6.2 zh_Hans → zh 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('zh', 'Hans'),
          supportedLocales,
        );
        expect(result, const Locale('zh'));
      });

      test('6.3 zh_CN → zh 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('zh', 'CN'),
          supportedLocales,
        );
        expect(result, const Locale('zh'));
      });

      test('6.3b zh_Hant → zh 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('zh', 'Hant'),
          supportedLocales,
        );
        expect(result, const Locale('zh'));
      });

      test('6.3c zh_TW → zh 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('zh', 'TW'),
          supportedLocales,
        );
        expect(result, const Locale('zh'));
      });
    });

    group('영어 변형 매칭', () {
      test('6.4 en_US → en 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('en', 'US'),
          supportedLocales,
        );
        expect(result, const Locale('en'));
      });

      test('6.4b en_GB → en 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('en', 'GB'),
          supportedLocales,
        );
        expect(result, const Locale('en'));
      });
    });

    group('폴백 동작', () {
      test('6.5 미지원 로캘(일본어) → 한국어 폴백', () {
        final result = resolveLocale(
          null,
          const Locale('ja'),
          supportedLocales,
        );
        expect(result, const Locale('ko'));
      });

      test('6.5b 미지원 로캘(프랑스어) → 한국어 폴백', () {
        final result = resolveLocale(
          null,
          const Locale('fr', 'FR'),
          supportedLocales,
        );
        expect(result, const Locale('ko'));
      });

      test('6.6 null 디바이스 로캘 → 한국어 폴백', () {
        final result = resolveLocale(
          null,
          null,
          supportedLocales,
        );
        expect(result, const Locale('ko'));
      });

      test('6.7 ko 로캘 정상 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('ko'),
          supportedLocales,
        );
        expect(result, const Locale('ko'));
      });

      test('6.7b ko_KR → ko 매칭', () {
        final result = resolveLocale(
          null,
          const Locale('ko', 'KR'),
          supportedLocales,
        );
        expect(result, const Locale('ko'));
      });
    });
  });
}
