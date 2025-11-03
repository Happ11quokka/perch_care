import 'package:flutter/material.dart';

/// 앱의 타이포그래피 스타일 정의
class AppTypography {
  AppTypography._();

  // Font Family
  // 제목: 32 혹은 24
  // 설명글, 버튼 속 내용: 16
  static const String fontFamily = 'Roboto';

  // Headline Styles (제목)
  static const TextStyle h1 = TextStyle(
    fontSize: 32, // 큰 제목
    fontWeight: FontWeight.bold,
    height: 1.25,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24, // 작은 제목
    fontWeight: FontWeight.bold,
    height: 1.35,
    letterSpacing: 0,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle h4 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.25,
  );

  static const TextStyle h5 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle h6 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.15,
  );

  // Body Styles (설명글, 본문)
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16, // 설명글, 버튼 속 내용
    fontWeight: FontWeight.normal,
    height: 1.5,
    letterSpacing: 0.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: 0.25,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13, // 회원가입 등 중요성이 낮거나, 날짜처럼 반복적인 내용, 혹은 모든 사람들을 위한 정보가 아니라면
    fontWeight: FontWeight.normal,
    height: 1.35,
    letterSpacing: 0.4,
  );

  // Label Styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.5,
  );

  // Button Style
  static const TextStyle button = TextStyle(
    fontSize: 16, // 버튼 속 내용
    fontWeight: FontWeight.w600,
    height: 1.15,
    letterSpacing: 0.5,
  );

  // Caption Style
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.35,
    letterSpacing: 0.4,
  );

  // Overline Style
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.normal,
    height: 1.6,
    letterSpacing: 1.5,
  );
}
