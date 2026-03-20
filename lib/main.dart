import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'src/router/app_router.dart';
import 'src/theme/app_theme.dart';
import 'src/providers/locale_provider.dart';
import 'src/services/push/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS에서 앱 재시작 시 secure storage 초기화 문제 방지
  await Future.delayed(const Duration(milliseconds: 50));

  // Firebase + LocaleProvider 병렬 초기화 (독립적)
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    LocaleProvider.instance.initialize(),
  ]);

  // FCM 백그라운드 메시지 핸들러 등록 (Firebase 의존)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 모든 I/O 작업은 SplashScreen에서 수행 (UI 블로킹 최소화)
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);

    return MaterialApp.router(
      title: 'Perch Care',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      routerConfig: AppRouter.router,
      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        CountryLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko'), // 한국어 (기본)
        Locale('en'), // 영어
        Locale('zh'), // 중국어
      ],
      // null이면 기기 설정 따름, 아니면 사용자 선택 적용
      locale: locale,
      // zh_Hans, zh_CN 등 변형 로캘을 zh에 매칭 (중국어 사용자 첫 실행 시 한국어 표시 방지)
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (locale != null) return locale;
        if (deviceLocale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == deviceLocale.languageCode) {
              return supported;
            }
          }
        }
        return const Locale('ko');
      },
    );
  }
}
