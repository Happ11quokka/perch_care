import 'package:flutter/material.dart';

/// 앱의 색상 팔레트 정의
class AppColors {
  AppColors._();

  // Brand Colors (메인 브랜드 컬러)
  static const Color brandPrimary = Color(0xFFFF9A42); // #FF9A42
  static const Color onBrandPrimary = Color(0xFFFFFFFF);

  // Gradient Colors (그라데이션 3단계)
  static const Color gradientTop = Color(0xFFFDCD66); // #FDCD66
  static const Color gradientMiddle = Color(0xFFFF9A42); // #FF9A42
  static const Color gradientBottom = Color(0xFFFF572D); // #FF572D

  // Primary Colors
  static const Color primary = brandPrimary;
  static const Color primaryVariant = gradientBottom;
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary Colors (주황색 버튼, 그래픽, 포인트 컬러)
  static const Color secondary = brandPrimary;
  static const Color secondaryVariant = gradientBottom;
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Background Colors
  static const Color background = Color(0xFFFFFFFF);
  static const Color onBackground = Color(0xFF1A1A1A); // Near Black

  // Surface Colors
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1A1A1A); // Near Black

  // Error Colors
  static const Color error = Color(0xFFFF572D);
  static const Color onError = Color(0xFFFFFFFF);

  // Grayscale (제목, 타이틀: 거의 검은색 / 읽을 필요가 있는 글들: 중간 회색 / 비활성화, 혹은 중요도가 가장 낮은 문구: 밝은 회색)
  static const Color nearBlack = Color(0xFF1A1A1A); // 거의 검은색 (Near Black)
  static const Color mediumGray = Color(0xFF6B6B6B); // 중간 회색 (Medium Gray)
  static const Color lightGray = Color(0xFFBDBDBD); // 밝은 회색 (Light Gray)

  // Standard Colors
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Additional Grayscale
  static const Color gray50 = Color(0xFFFAFAFA);
  static const Color gray100 = Color(0xFFF5F5F5);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray400 = lightGray; // #BDBDBD
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = mediumGray; // #6B6B6B
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = nearBlack; // #1A1A1A
}
