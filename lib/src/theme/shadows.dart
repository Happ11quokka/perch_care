import 'package:flutter/material.dart';

/// 앱의 그림자 효과 정의
class AppShadows {
  AppShadows._();

  // Shadow elevation levels
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> xs = [
    BoxShadow(
      color: Color(0x0F000000), // 6% opacity
      offset: Offset(0, 1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(
      color: Color(0x14000000), // 8% opacity
      offset: Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(
      color: Color(0x1F000000), // 12% opacity
      offset: Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(
      color: Color(0x29000000), // 16% opacity
      offset: Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(
      color: Color(0x33000000), // 20% opacity
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> xxl = [
    BoxShadow(
      color: Color(0x3D000000), // 24% opacity
      offset: Offset(0, 16),
      blurRadius: 32,
      spreadRadius: 0,
    ),
  ];

  // Component specific shadows
  static const List<BoxShadow> button = sm;
  static const List<BoxShadow> card = md;
  static const List<BoxShadow> dialog = xl;
  static const List<BoxShadow> bottomSheet = lg;
  static const List<BoxShadow> appBar = xs;
}
