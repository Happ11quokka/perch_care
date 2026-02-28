import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'radius.dart';

/// 앱의 전체 테마 설정
///
/// MaterialApp의 theme 속성에 사용
class AppTheme {
  AppTheme._();

  /// 라이트 테마 (정적 상수 - 매번 재생성 방지)
  static final ThemeData light = ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,

        // Color Scheme
        colorScheme: const ColorScheme.light(
          primary: AppColors.brandPrimary,
          onPrimary: AppColors.onBrandPrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          error: AppColors.error,
          onError: AppColors.onError,
          surface: AppColors.surface,
          onSurface: AppColors.nearBlack,
        ),

        // Typography
        textTheme: const TextTheme(
          displayLarge: AppTypography.h1,
          displayMedium: AppTypography.h2,
          displaySmall: AppTypography.h3,
          headlineMedium: AppTypography.h4,
          headlineSmall: AppTypography.h5,
          titleLarge: AppTypography.h6,
          bodyLarge: AppTypography.bodyLarge,
          bodyMedium: AppTypography.bodyMedium,
          bodySmall: AppTypography.bodySmall,
          labelLarge: AppTypography.labelLarge,
          labelMedium: AppTypography.labelMedium,
          labelSmall: AppTypography.labelSmall,
        ),

        // AppBar Theme
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.nearBlack,
        ),

        // Card Theme
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.card,
          ),
        ),

        // Button Themes
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.button,
            ),
            textStyle: AppTypography.button,
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.button,
            ),
            textStyle: AppTypography.button,
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.button,
            ),
            textStyle: AppTypography.button,
          ),
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.gray100,
          border: OutlineInputBorder(
            borderRadius: AppRadius.textField,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.textField,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.textField,
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.textField,
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.textField,
            borderSide: const BorderSide(
              color: AppColors.error,
              width: 2,
            ),
          ),
        ),

        // Chip Theme
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.chip,
          ),
        ),

        // Dialog Theme
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.dialog,
          ),
        ),

        // Bottom Sheet Theme
        bottomSheetTheme: const BottomSheetThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.bottomSheet,
          ),
        ),
      );

  /// 다크 테마 (정적 상수 - 매번 재생성 방지)
  static final ThemeData dark = ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        // Color Scheme
        colorScheme: const ColorScheme.dark(
          primary: AppColors.brandPrimary,
          onPrimary: AppColors.onBrandPrimary,
          secondary: AppColors.secondary,
          onSecondary: AppColors.onSecondary,
          error: AppColors.error,
          onError: AppColors.onError,
          surface: AppColors.nearBlack,
          onSurface: AppColors.white,
        ),

        // Typography (동일한 타이포그래피 사용)
        textTheme: const TextTheme(
          displayLarge: AppTypography.h1,
          displayMedium: AppTypography.h2,
          displaySmall: AppTypography.h3,
          headlineMedium: AppTypography.h4,
          headlineSmall: AppTypography.h5,
          titleLarge: AppTypography.h6,
          bodyLarge: AppTypography.bodyLarge,
          bodyMedium: AppTypography.bodyMedium,
          bodySmall: AppTypography.bodySmall,
          labelLarge: AppTypography.labelLarge,
          labelMedium: AppTypography.labelMedium,
          labelSmall: AppTypography.labelSmall,
        ),
      );
}
