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
  static const Color gray150 = Color(0xFFF0F0F0);
  static const Color gray200 = Color(0xFFEEEEEE);
  static const Color gray250 = Color(0xFFE8E8E8);
  static const Color gray300 = Color(0xFFE0E0E0);
  static const Color gray350 = Color(0xFFD0D0D0);
  static const Color gray400 = lightGray; // #BDBDBD
  static const Color gray450 = Color(0xFFBBBBBB);
  static const Color gray500 = Color(0xFF9E9E9E);
  static const Color gray600 = mediumGray; // #6B6B6B
  static const Color gray700 = Color(0xFF616161);
  static const Color gray800 = Color(0xFF424242);
  static const Color gray900 = nearBlack; // #1A1A1A

  // Warm Tones
  static const Color warmGray = Color(0xFF97928A);
  static const Color beige = Color(0xFFE7E5E1);

  // Brand Variants
  static const Color brandLight = Color(0xFFFFF5ED);
  static const Color brandDark = Color(0xFFFF7C2A);
  static const Color brandSoft = Color(0xFFFFE0C0);

  // Semantic Colors
  static const Color danger = Color(0xFFE53935);
  static const Color dangerLight = Color(0xFFFFEBEE);
  static const Color sundayRed = Color(0xFFEE3300);
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningDark = Color(0xFFF57C00);

  // Brand Extended
  static const Color brandLighter = Color(0xFFFFF3E0);
  static const Color brandPale = Color(0xFFFFF8F3);

  // Overlay / Shadow
  static const Color shadowLight = Color(0x0A000000);
  static const Color overlay50 = Color(0x80000000);
  static const Color overlay30 = Color(0x4D000000);

  // Chart / Accent
  static const Color yellow = Color(0xFFFFE812);
  static const Color yellowLight = Color(0xFFFFF9C4);
  static const Color lime = Color(0xFF8BC34A);

  // Semantic Dark Variants (SnackBar, Text)
  static const Color successDark = Color(0xFF388E3C);
  static const Color successDarker = Color(0xFF1B5E20);
  static const Color dangerDark = Color(0xFFD32F2F);
  static const Color dangerDarker = Color(0xFFB71C1C);
  static const Color dangerDeep = Color(0xFFC62828);
  static const Color warningDeep = Color(0xFFE65100);
  static const Color infoDark = Color(0xFF1976D2);
  static const Color infoDarker = Color(0xFF0D47A1);
  static const Color infoDeep = Color(0xFF1565C0);
  static const Color successMedium = Color(0xFF2E7D32);

  // Health Check Mode Colors
  static const Color partSpecificBlue = Color(0xFF42A5F5);
  static const Color droppingsPurple = Color(0xFF7E57C2);
  static const Color foodGreen = Color(0xFF66BB6A);

  // Gradient Extended
  static const Color brandAccent = Color(0xFFFF7B29);
  static const Color gradientBottomAlt = Color(0xFFFF5C2F);

  // Weight Range
  static const Color weightIdeal = Color(0xFF4CAF50);
  static const Color weightWarning = Color(0xFFEF5350);
  static const Color weightLight = Color(0xFFFFE0B2);

  // Overlay Variants
  static const Color overlayWhite80 = Color(0xCCFFFFFF);
  static const Color overlayWhite90 = Color(0xE6FFFFFF);
  static const Color overlayWhite60 = Color(0x99FFFFFF);
  static const Color shadowMedium = Color(0x3F000000);

  // Gray Extended
  static const Color gray100Alt = Color(0xFFF6F6F6);
}
