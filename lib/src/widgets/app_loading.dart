import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 표준 로딩 인디케이터
class AppLoading {
  AppLoading._();

  /// 풀페이지 로딩 (브랜드 컬러)
  static Widget fullPage() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.brandPrimary),
    );
  }

  /// 버튼 내 로딩 스피너 (흰색, 24x24)
  static Widget button() {
    return const SizedBox(
      width: 24,
      height: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    );
  }
}
