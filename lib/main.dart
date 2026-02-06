import 'package:flutter/material.dart';
import 'src/router/app_router.dart';
import 'src/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS에서 앱 재시작 시 secure storage 초기화 문제 방지
  await Future.delayed(const Duration(milliseconds: 50));

  // 모든 I/O 작업은 SplashScreen에서 수행 (UI 블로킹 최소화)
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Perch Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
    );
  }
}
