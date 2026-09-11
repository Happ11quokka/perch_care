import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:perch_care/src/theme/colors.dart';

/// 텍스트 토큰의 WCAG 2.1 대비를 고정한다 — 감사 F11.
///
/// 브랜드 색(`brandPrimary`)은 유지하되, **텍스트**에는 대비를 만족하는 전용
/// 토큰을 쓴다. 이 테스트는 토큰 값을 무심코 밝게 바꾸는 회귀를 막는다.
double _relativeLuminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// 본문 텍스트가 실제로 놓이는 밝은 배경들.
const _lightSurfaces = <String, Color>{
  'white': AppColors.white,
  'gray50': AppColors.gray50,
  'gray100': AppColors.gray100,
  'gray200': AppColors.gray200,
  'brandLight': AppColors.brandLight,
};

void main() {
  group('본문 텍스트 토큰은 모든 밝은 배경에서 AA(4.5:1)를 만족한다', () {
    for (final entry in {
      'textSecondary': AppColors.textSecondary,
      'brandTextOnLight': AppColors.brandTextOnLight,
      'mediumGray': AppColors.mediumGray,
      'nearBlack': AppColors.nearBlack,
    }.entries) {
      for (final bg in _lightSurfaces.entries) {
        test('${entry.key} on ${bg.key}', () {
          final ratio = contrastRatio(entry.value, bg.value);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key}(${entry.value}) on ${bg.key} = '
                '${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    }
  });

  group('비텍스트 토큰은 UI 컴포넌트 기준(3:1)을 만족한다', () {
    test('warmGray 테두리/아이콘 on white', () {
      // 텍스트에는 쓰지 않는다. textSecondary가 그 역할을 맡는다.
      expect(
        contrastRatio(AppColors.warmGray, AppColors.white),
        greaterThanOrEqualTo(3.0),
      );
    });
  });

  test('brandPrimary는 브랜드 채움 색으로 유지된다', () {
    // 정책 고정: 버튼 배경은 브랜드 주황을 그대로 쓴다. 흰 글씨 대비는 2.11:1로
    // AA에 미달하므로, 브랜드 색을 바꾸지 않는 한 버튼 라벨 색 또는 채움 명도를
    // 조정해야 한다(미결 사항). 값이 바뀌면 이 테스트가 알려준다.
    expect(AppColors.brandPrimary, const Color(0xFFFF9A42));
    final onWhite = contrastRatio(AppColors.brandPrimary, AppColors.white);
    expect(onWhite, lessThan(3.0));
  });
}
