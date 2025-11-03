import 'package:flutter/material.dart';

/// 앱의 모서리 둥근 정도(border radius) 규칙 정의
class AppRadius {
  AppRadius._();

  // Radius values
  static const double none = 0;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 9999; // 완전히 둥근 모서리

  // BorderRadius objects
  static const BorderRadius radiusNone = BorderRadius.zero;
  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusXxl = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(full));

  // Component specific radius
  static const BorderRadius button = radiusMd;
  static const BorderRadius card = radiusLg;
  static const BorderRadius dialog = radiusLg;
  static const BorderRadius bottomSheet = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
  );
  static const BorderRadius chip = radiusFull;
  static const BorderRadius textField = radiusSm;
}
