/// 앱의 여백(spacing) 규칙 정의
class AppSpacing {
  AppSpacing._();

  // Base spacing unit (4px 기준)
  static const double unit = 4.0;

  // Spacing values
  static const double xs = unit;           // 4px
  static const double sm = unit * 2;       // 8px
  static const double md = unit * 3;       // 12px
  static const double lg = unit * 4;       // 16px
  static const double xl = unit * 5;       // 20px
  static const double xxl = unit * 6;      // 24px
  static const double xxxl = unit * 8;     // 32px
  static const double huge = unit * 10;    // 40px
  static const double massive = unit * 12; // 48px

  // Component specific spacing
  static const double buttonPaddingVertical = md;
  static const double buttonPaddingHorizontal = lg;

  static const double cardPadding = lg;
  static const double cardMargin = md;

  static const double listItemPaddingVertical = md;
  static const double listItemPaddingHorizontal = lg;

  static const double sectionSpacing = xxl;
  static const double screenPadding = lg;
}
